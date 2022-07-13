<#
Copyright 2022 James O'Neill

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>
#the normal version class won't work and the PowerShell 7 semantic version class fails with PowerShell 5, so we load the packagemanagement module which has a class we can use
function Update-WingetCache    {
    Get-Item -Path   "$env:temp\Winget.db" -ErrorAction SilentlyContinue | Remove-Item -ErrorAction Stop
    Invoke-WebRequest -Uri "https://winget.azureedge.net/cache/source.msix" -OutFile "$env:temp\Winget.zip"
    Expand-Archive  "$env:temp\Winget.zip" -DestinationPath "$env:temp\Winget-Files" -Force
    if (Test-path   "$env:temp\Winget-Files\Public\index.db") {
        Copy-Item   "$env:temp\Winget-Files\Public\index.db" "$env:temp\Winget.db" -Force
        Remove-item "$env:temp\Winget-Files" -Recurse -Force
        Remove-item "$env:temp\Winget.Zip" -Force
}
}

#region preload the data
if (-not (Test-Path "$env:temp\Winget.db") -or [datetime]::Now.Subtract( (Get-Item -Path    "$env:temp\Winget.db" ).CreationTime).TotalDays -gt 7 ) {
    Write-Progress -Activity "Initializing" -Status "Downloading winget database"
    if (  Test-Path "$env:temp\Winget.db") {Move-Item -Path "$env:temp\Winget.db" "$env:temp\Winget.old"  -force}
    Update-WingetCache
}

$manifestQuery = @"
    SELECT manifest.rowid , names.name, norm_names.norm_name, ids.id, versions.version, manifest.pathpart
    FROM   manifest
    JOIN   ids            ON        ids.rowid = manifest.id
    JOIN   names          ON      names.rowid = manifest.name
    JOIN   versions       ON   versions.rowid = manifest.version
    JOIN   norm_names_map ON   manifest.rowid = norm_names_map.manifest
    JOIN   norm_names     ON norm_names.rowid = norm_names_map.norm_name
"@  # The SQLLite DB breaks the path to the manifest into parts which we will reasssemble
# first store the parts of paths used in the main manifest, and their relationships to each other in two hash tables.
$pathparts     = @{}
$parents       = @{}

Write-Progress -Activity "Initializing" -Status "Loading Manifest information from Database"

Get-SQL -Lite -Connection "$env:temp\Winget.db" -Table "pathparts" -Quiet | ForEach-Object {
    $pathparts[$_.rowID] = $_.pathpart;
    if ($_.parent) {$parents[$_.rowId] = $_.parent}
}

# Now run the main query and use select-object to reassemble the the manifest path
# Add a script method to get the manifest  -- can add more script methods to call winget to install / update / uninstall.
# And then flag the latest version of each, and keep  Normalized names--> Manifest record, and ID --> versions hash tables.

$WingetData   =  Get-SQL -Lite -Connection  "$env:temp\Winget.db" -SQL $manifestQuery -Quiet |
    Select-object -property @( 'rowid', 'id', 'name',
        @{n='normalizedName';e='norm_name'},
        @{n='versionString'; e='version'},
        @{n='version';       e={$_.version  -as [Microsoft.PackageManagement.Provider.Utility.SemanticVersion] }},
        @{n='latestVersion'; e={$false} },
        @{n="manifestURL";   e={
                                $path = $pathparts[$_.pathpart];
                                $p    =   $parents[$_.pathpart];
                                while  ($p) {$path = $pathparts[$p] + "/" + $path; $p= $parents[$p]}
                                "https://winget.azureedge.net/cache$path" }
        }) | ForEach-Object {$_.pstypeNames.add('WingetManifestItem') ; $_ }


Write-Verbose "Found $($WingetData.Count) Manifest entries"
Write-Progress -Activity "Initializing" -Status "Caching look-up data"

$newestIDs    = @{}
$nNamesHash   = @{}
$WingetData   | Where-Object {$_.version} |
                Group-Object -Property ID |
                    ForEach-Object  {
                        $ver    = ($_.group | Measure-Object -Property version -Maximum ).Maximum
                        if   ($ver) {
                              $newestItem =  $_.group.where({$_.version -eq $ver}) | Sort-Object -property versionString | Select-object -Last 1
                        }
                        else {$newestItem =  $_.group  | Sort-Object -property versionString | Select-object -Last 1}
                        if   ($newestItem) {
                              $newestItem.latestVersion = $true
                              $nNamesHash[$newestItem.normalizedName] = $newestItem
                              $newestIDs[$newestItem.id]              = $newestItem
                        }
                }

Write-Verbose  "Found valid latest version for $($nNamesHash.Count) packages"

$Global:WingetVersions = @{}
foreach ($w in $WingetData) {$Global:wingetVersions[$w.id]  +=  @($w.versionString) }
Write-Verbose "Processed $($WingetVersions.Count) distinct package IDs"

#$regexGUID = [regex]"^\{?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}?$"
$prodcodes  = @{}
Get-SQL -Lite -Connection  "$env:temp\Winget.db" -SQL @"
    SELECT distinct productcodes.productcode, ids.id
    FROM   productcodes_map
    JOIN   productcodes    on productcodes_map.productcode = productcodes.rowid`
    JOIN   manifest        on manifest.rowid = productcodes_map.manifest
    JOIN   ids             on ids.rowid      = manifest.id
"@ -Quiet |
    ForEach-Object { $prodcodes[$_.productcode] += @($_.id)  }
Write-Verbose "Linked $($prodcodes.Count) product codes IDs"

$Global:WingetCommands = @{}
Get-sql -Lite -Connection  "$env:temp\Winget.db" -SQL @"
    SELECT  distinct commands.command, ids.id
    FROM    commands_map
    JOIN    commands on commands.rowid = commands_map.command
    JOIN    manifest on manifest.rowid = commands_map.manifest
    JOIN    ids      on  manifest.id   = ids.rowID
"@ -Quiet |
    Where-Object {$newestIDs[$_.id] } |
        ForEach-Object { $Global:WingetCommands[$_.command] += @($_.id) }

$Global:WingetTags = @{}
Get-sql -Lite -Connection  "$env:temp\Winget.db" -SQL @"
    SELECT  distinct tags.tag, ids.id
    FROM    tags_map
    JOIN    tags on tags.rowid = tags_map.tag
    JOIN    manifest on manifest.rowid = tags_map.manifest
    JOIN    ids      on  manifest.id   = ids.rowID
"@ -Quiet|
        Where-Object {$newestIDs[$_.id] } |
    ForEach-Object { $Global:WingetTags[$_.tag] += @($_.id)}

Get-Sql -Close
Write-Progress -Activity "Initializing" -Completed
#endregion

function Clear-WingetCache     {
   Get-Item -Path   "$env:temp\Wingt.db" -ErrorAction SilentlyContinue | Remove-Item -ErrorAction Stop
}

function Get-InstalledSoftware {
    <#
      .SYNOPSIS
        Gets a list of installed software and tries to match it with items in the Winget Database
      .DESCRIPTION
        The command gets a list of items from uninstall branches of the registry, and listed as installed by Get-AppxPackage
        It can filter these by name, publisher and/or internal ID.
        Unless -IgnoreWinget is specified it tries to match these against known winget items. Matches aren't guaranteed and it is possible
        for either a short name in the repo to match a longer name of an installed package, and for one installed package to match multiple
        repo packages (outputting multiple rows.)
      .EXAMPLE
        PS> Get-InstalledSoftware *itunes*

        Gets packages with a name containing Itunes, and tries to match them against the winget repo

            Publisher    Name     MatchesPackage   Version Installed    Version Available    WingetID
            ---------    ----     --------------   -----------------    -----------------    --------
            Apple Inc.   iTunes   iTunes           12124.1.57017-0      12.12.4-1            Apple.iTunes

      .EXAMPLE
        PS> Get-InstalledSoftware -Publisher adobe* -IgnoreWinget

        Gets packages where the publisher is some form of Adobe but does not try to match them to winget items.

            publisher                  name                      version
            ---------                  ----                      -------
            Adobe Inc.                 Adobe Creative Cloud      5.7.1-1
            Adobe Inc.                 Adobe Lightroom Classic   11.4.1
            Adobe Inc.                 Adobe Photoshop 2022      23.4.1-547
            Adobe Inc.                 Adobe Premiere Rush       2.3.0
            Adobe Inc.                 UXP WebView Support       1.1.0
            Adobe Systems Incorporated Adobe Notification Client 3.0.1-1

      .EXAMPLE
        PS> Get-InstalledSoftware -Publisher microsoft* -WingetOnly

        Gets packages where the publisher is Microsoft and a match is found with a winget item

      .EXAMPLE
        PS>  Get-InstalledSoftware -Wingetid  Microsoft.PowerShell

       Looks to see if there is an item which can match the winget repo item with the ID "Microsoft.PowerShell"
    #>
    [cmdletBinding(DefaultParameterSetName="Default")]
    param (
        #The package name - wildcars are supported
        [Parameter(Position=0)]
        $Name      = "*",
        #The application publisher, Wildcards are supported (e.g. Adobe use 'Adobe Systems Incorporated' and 'Adobe inc' so Adobe*)
        $Publisher = "*",
        #An internal ID. Store appss use the package family name e.g. "Microsoft.Paint_8wekyb3d8bbwe", others may be a name or a guid - wildcards are supported.
        $ID        = "*",

        #A winget ID e.g. Apple.iTunes, wildcards are supported, e.g '*itunes*'
        [Parameter(ParameterSetName="Winget")]
        [ArgumentCompleter([wingetIDCompleter])]
        $Wingetid  = "*",

        #If specified, does not try to match items against the Winget Repository
        [Parameter(ParameterSetName="NoWinget",Mandatory=$true)]
        [switch]$IgnoreWinget,

        #If specified, only returns items which match against an item in the Winget repository
        [Parameter(ParameterSetName="Winget")]
        [switch]$WingetOnly
    )

    #region Get software that can be found from the uninstall part of the registry, then get software found as APPX packages, filter and sort it.
    $InstalledSoftware =  @('HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') | Where-Object {Test-path $_} |
        Get-ItemProperty |  Where-Object {$_.DisplayName -and -not $_.SystemComponent} | Select-Object -Property @(
                        @{n='name';           e='DisplayName'   },
                        @{n='versionString';  e='DisplayVersion'},
                        @{n='version';        e={ $_.DisplayVersion  -as [Microsoft.PackageManagement.Provider.Utility.SemanticVersion] }},
                            'publisher',
                        @{n='normalizedName'; e={($_.DisplayName -replace '\W','').toLower() }},
                        @{n='ID';             e='PSChildName'   })

    $CpPackages         = $InstalledSoftware.Count
    $InstalledSoftware +=  Get-AppxPackage | Where-Object {-not ($_.IsFramework -or $_.NonRemovable)}  |
        Select-Object Name, version, InstallLocation, publisher, PackageFamilyName, IsBundle -Unique | ForEach-Object {
            $props = ([xml](Get-Content (Join-path $_.InstallLocation "Appxmanifest.xml"))).Package.Properties

            #already have name and publisher properties so name the new one Pub and display name
            if ($Props.DisplayName -notlike 'ms-resource*') {
                   Add-Member -InputObject $_ -NotePropertyName DisplayName -NotePropertyValue  $props.DisplayName
            }
            else { Add-Member -InputObject $_ -NotePropertyName Displayname -NotePropertyValue ($_.name -replace "^.*?\.","")}
            if ($Props.PublisherDisplayname -notlike 'ms-resource*') {
                   Add-Member -InputObject $_ -NotePropertyName pub         -NotePropertyValue  $props.PublisherDisplayname -PassThru
            }
            else { Add-Member -InputObject $_ -NotePropertyName pub         -NotePropertyValue ($_.publisher -replace '^cn=(.*?),.*$','$1') -PassThru}
        } |  select-Object @(   @{n='name';           e='DisplayName'},
                                @{n='versionString';  e='version'},
                                @{n='version';        e={ $_.version  -as [Microsoft.PackageManagement.Provider.Utility.SemanticVersion] }},
                                @{n='publisher';      e='pub'}  ,
                                @{n='normalizedName'; e={($_.DisplayName -replace '\W','').toLower() }},  @{n='ID';e='PackageFamilyName'})

    $InstalledSoftware = $InstalledSoftware  | Where-Object {$_.name -like $name -and $_.ID -like  $ID -and $_.publisher -like $Publisher} |
            Sort-Object publisher, name,version,versionString
    Write-Verbose  "Found $CpPackages 'conventional' Packages and $($InstalledSoftware.Count - $CpPackages) 'Store' packages. "
    #endregion

    if ($wingetid -ne '*' -and -not $WingetOnly) {$WingetOnly = $ture}
    elseif ($IgnoreWinget) {
            $InstalledSoftware | ForEach-Object {$_.pstypeNames.add('InstalledPackage') ; $_}
            return
    }

    #region try to match Installed software against the winget db by ID or normalized name. Filter and return the result
    $packages  =  foreach  ($s  in $InstalledSoftware) {
        if ($prodcodes[$s.id]) {$WingetPkgs = $newestIDs[$prodcodes[$s.id]] } else {$WingetPkgs = $null}
        if (-not $WingetPkgs)  {
                $keys   =  $nNamesHash.keys.where({ $_ -and $s.normalizedName -like "$_*"})
                if ($keys) {$WingetPkgs = $nNamesHash[$keys]}
                else       {$WingetPkgs = $null}
        }
        if (-not $wingetpkgs -and -not $WingetOnly) {$s   |  Select-Object -Property publisher, name,
                                                        @{n='matches';  e={$Null}},
                                                        @{n='installed';e={if ($_.version) {$_.version} else {$_.versionString}} },
                                                        @{n='available';e={$Null}},
                                                        ID,
                                                        @{n='rowID';e={$Null}},
                                                        @{n='wingetID';e={$Null}},
                                                        @{n='manifestURL';e={$Null}} }
        else {
            foreach ($pkg in $WingetPkgs) {
                     $pkg |  Select-Object -Property  @{n='publisher';  e={$s.publisher}},
                                                      @{n='name';       e={$s.name}},
                                                      @{n='matches';    e='Name'},
                                                      @{n='installed';  e={if ($s.version) {$s.version} else {$s.versionString}} },
                                                      @{n='available';  e={if ($_.version) {$_.version} else {$_.versionString}} },
                                                      @{n='ID';         e={$s.ID}},
                                                      @{n='wingetID';   e='id'},
                                                      rowid, manifestURL
            }
        }
    }
    $packages | Where-Object WingetID -Like $Wingetid  | ForEach-Object {$_.pstypeNames.add('WingetInstalledPackage') ; $_}
    #end region
}

function Get-WinGetPackageInfo {
    <#
    .DESCRIPTION
        Shows information on a specific WinGet package
    .PARAMETER ID
        Package ID (multiple values and wildcards allowed)
    .PARAMETER Version
        One or more exact versions of a package in the Winget repo
    .PARAMETER ListVersions
        Show available versions of a package in the Winget repo
    .PARAMETER MSStore
        If specified searches for the Package ID in the Microsoft store; otherwise uses the Winget Repo

    .EXAMPLE
        PS> Get-WinGetPackageInfo Microsoft.PowerShell -ListVersions
        Gets versions of PowerShell available for download from the Winget Repo

    ..EXAMPLE
        PS> Get-WinGetPackageInfo 'Microsoft.PowerShell' -Version '7.1.0.0'
        Gets details of a PowerShell versopm available for download from the Winget Repo,
        if -version is omitted the latest version will be selected. Both the package ID and its
        associated versions will tab-complete

    .EXAMPLE
        PS> Get-WinGetPackageInfo  -MSStore -ID XPFFTQ037JWMHS
        Gets the details of Microsoft Edge from the MSStore
    #>
    [CmdletBinding()]

    param   (
        [Parameter(ParameterSetName='Default',Position=0,ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [Parameter(ParameterSetName='Versions',Position=0,ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [Parameter(ParameterSetName='MSStore',Position=0,ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [Alias('WingetID')]
        [ArgumentCompleter([wingetIDCompleter])]
        $ID,

        [ArgumentCompleter([wingetVerSionCompleter])]
        [Parameter(ParameterSetName='Default',ValueFromPipelineByPropertyName=$true)]
        $Version,

        [Parameter(ParameterSetName='Versions',ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [switch]$ListVersions,

        [Parameter(ParameterSetName='MSStore',ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [switch]$MSStore
    )
    process {
        if (-not $MSStore) {
            foreach ($i in $id) {
                $wd = $WingetData.Where({$_.id -like $i}) | Sort-Object version,versionString -Descending
                foreach ($w in $wd) {
                    if     ($ListVersions)                 {$w.versionString}
                    elseif ((-not $version) -or $w.versionstring -in $version) {$w.GetManifest()}
                    if ((-not $ListVersions) -and (-not $Version)) {break}
                }
            }
        }
        else {
            try {    $url = (Get-WinGetSource msstore).Arg}  catch {}
            if (-not $url) {Write-Warning 'Cannot find Source "msstore".' ; return }
            foreach ($i in $id) {
                $v = (Invoke-RestMethod -Method Get -UseBasicParsing -Uri "$url/packageManifests/$i").data.versions[0]
                if (-not $v.DefaultLocale) {continue}
                if ($v.Installers)     {Add-Member -InputObject $v.DefaultLocale -NotePropertyName Installers   -NotePropertyValue $v.Installers}
                if ($v.Locales)        {Add-Member -InputObject $v.DefaultLocale -NotePropertyName Localization -NotePropertyValue $v.Locales}
                if ($v.PackageVersion) {Add-Member -InputObject $v.DefaultLocale -NotePropertyName PackageVersion -NotePropertyValue $v.PackageVersion}
                $v.DefaultLocale.pstypenames.Add('WingetManifestDetails')
                $v.DefaultLocale
            }
        }
    }
}

function Find-WinGetPackage    {
    <#
    .DESCRIPTION
        Find a list of available WinGet packages
    .PARAMETER ID
        Package ID - this will tab complete for items in the winget repository, and must be a complete ID.
    .PARAMETER Name
        Package Name - this will be a keyword search in the MS Store, and can support Wildcards when working with winget repo
    .PARAMETER Tag
        A Tag - this will be a keyword search in the MS Store, and can support Wildcards when working with winget repo
    .PARAMETER Tag
        A Tag - this will be a keyword search in the MS Store, and can support Wildcards when working with winget repo

    .PARAMETER MSStore
        If specified searches in the Microsoft store instead of the Winget repository

    .EXAMPLE
        PS> find-WinGetPackage  'Notepad++.Notepad++'
        Finds Notepad++ in the winget repository

    .EXAMPLE
        PS> find-WinGetPackage -Name 'Notepad*'
        Finds packages in the winget repository with Notepad in their name

    .EXAMPLE
        PS> find-WinGetPackage  -Tag editor
        Finds packages in the winget repository tagged as editors

    .EXAMPLE
        PS> find-WinGetPackage  -Tag editor -MSStore
        Finds packages agged as editors but this time from the store
    #>
    [CmdletBinding()]
    param   (
        [Parameter(ParameterSetName='StoreID',  Position=0, ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [Parameter(ParameterSetName='WingetID', Position=0, ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [Alias('WingetID')]
        [ArgumentCompleter([wingetIDCompleter])]
        $ID,

        [Parameter(ParameterSetName='StoreName',ValueFromPipelineByPropertyName=$true,mandatory=$true)]
        [Parameter(ParameterSetName='WingetName',ValueFromPipelineByPropertyName=$true,mandatory=$true)]
        $Name,

        [Parameter(ParameterSetName='StoreTag',ValueFromPipelineByPropertyName=$true,mandatory=$true)]
        [Parameter(ParameterSetName='WingetTag',ValueFromPipelineByPropertyName=$true,mandatory=$true)]
        [ArgumentCompleter([wingetTagCompleter])]
        $Tag,

        [Parameter(ParameterSetName='Command',ValueFromPipelineByPropertyName=$true,mandatory=$true)]
        [ArgumentCompleter([wingetCommandCompleter])]
        $Command,

        [ArgumentCompleter([wingetVerSionCompleter])]
        [Parameter(ParameterSetName='WingetID',ValueFromPipelineByPropertyName=$true)]
        $Version,

        [Parameter(ParameterSetName='StoreID',   ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [Parameter(ParameterSetName='StoreName', ValueFromPipelineByPropertyName=$true,mandatory=$true)]
        [Parameter(ParameterSetName='StoreTag',  ValueFromPipelineByPropertyName=$true,mandatory=$true)]
        [switch]$MSStore
    )
    if (-not $MSStore) {
        if ($command  -and $WingetCommands[$command]) {$newestIDs[$WingetCommands[$command]] | Sort-Object Name }
        elseif ($tag  -and $Wingettags[$tag])         {$newestIDs[$Wingettags[$tag]]         | Sort-Object Name }
        elseif ($name -and $name -ne '*')             {$WingetData.Where({$_.name -like $name -and $newestIDs[$_.id].rowid -eq $_.rowid }) | Sort-Object Name }
        elseif ($id   -and $version)                  {$WingetData.Where({$_.id -like $id -and $_.versionString -in $version})   | Sort-Object Version,VesionString -Descending }
        elseif ($id   -and $newestIDs[$id] )          {$newestIDs[$id] }
        elseif ($id  )                                {$WingetData.Where({$_.id -like $id})   | Sort-Object Version,VesionString -Descending }
    }
    else {
        try {    $url = (Get-WinGetSource msstore).Arg}  catch {}
        if (-not $url) {Write-Warning 'Cannot find Source "msstore".' ; return }
        <#  Really should get the market add a filter to get only the market
            gc ([System.Environment]::GetFolderPath('LocalApplicationData') + "\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\localstate\Settings.json") | ConvertFrom-Json | % installBehavior | % preferences |% locale
            \HKEY_CURRENT_USER\Control Panel\International\Geo
            {"PackageMatchField":"Market","RequestMatch":{"KeyWord":"GB","MatchType":"CaseInsensitive"}}]}
            The open API spec for these calls is at https://github.com/microsoft/winget-cli-restsource/blob/main/documentation/WinGet-1.1.0.yaml
            Not all combinations of the fields and match types work. Some of this had to be obtained by using fiddler with winget.exe !
        #>
        if     ($Name) {$jsonText = '{"MaximumResults":100,"Query":{"KeyWord":"' + $name + '","MatchType":"Substring"}}' }
        elseif ($Tag)  {$jsonText = '{"Filters":[{"PackageMatchField":"Tag","RequestMatch":{"KeyWord":"' + $tag + '","MatchType":"Substring"}}]}' }
        elseif ($ID)   {$jsonText = '{"Filters":[{"PackageMatchField":"PackageIdentifier","RequestMatch":{"KeyWord":"' + $ID + '","MatchType":"Exact"}}]}' }
        $ManifestSb  = [scriptblock]::Create("""$url/packageManifests/`$(`$this.PackageIdentifier)""")
        Invoke-RestMethod -Method post -UseBasicParsing -Uri "$url/manifestSearch" -ContentType "application/json" -body $jsonText  |
            ForEach-Object 'Data' | Sort-Object -Property  PackageName |
                Select-Object -Property *,@{n='MSStore';e={$true}},@{n='name';e='PackageName'}, @{n='ID';e='PackageIdentifier'} |
                    Add-Member -PassThru -MemberType ScriptProperty -Name 'manifestURL'  -value $ManifestSb |
                        ForEach-Object {$_.pstypeNames.add('MSStoreManifestItem') ; $_ }
    }
}

$idscriptblock =  {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
    $idc = [wingetIDCompleter]::new()
    $idc.CompleteArgument($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
}
$verscriptblock =  {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
    $idc = [wingetVerSionCompleter]::new()
    $idc.CompleteArgument($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
}
Register-ArgumentCompleter -CommandName Get-WinGetPackage       -ParameterName ID      -ScriptBlock $idscriptblock
Register-ArgumentCompleter -CommandName Update-WinGetPackage    -ParameterName ID      -ScriptBlock $idscriptblock
Register-ArgumentCompleter -CommandName Uninstall-WinGetPackage -ParameterName ID      -ScriptBlock $idscriptblock
Register-ArgumentCompleter -CommandName Install-WinGetPackage   -ParameterName ID      -ScriptBlock $idscriptblock
Register-ArgumentCompleter -CommandName Install-WinGetPackage   -ParameterName Version -ScriptBlock $verscriptblock
