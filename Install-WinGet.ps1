Install-Module NtObjectManager -Force
Import-Module appx -WarningAction SilentlyContinue

$architecture           = 'x64'

# Workaround for no Microsoft Store on Windows Server - I dont know a great way to source this information dynamically
$msStoreDownloadAPIURL  = 'https://store.rg-adguard.net/api/GetFiles'
$msWinGetStoreURL       = 'https://www.microsoft.com/en-us/p/app-installer/9nblggh4nns1'

$msWinGetMSIXBundlePath = ".\Microsoft.DesktopAppInstaller.msixbundle"
$msWinGetLicensePath    = ".\Microsoft.DesktopAppInstaller.license.xml"
$msVCLibDownloadPath    = '.\Microsoft.VCLibs.UWPDesktop.appx'
$msUIXamlDownloadPath   = '.\Microsoft.UI.Xaml.appx'

$msWinGetLatestRelease  = Invoke-WebRequest -Uri 'https://github.com/microsoft/winget-cli/releases/latest'
$msWinGetLatestRelease.links | Where-Object href -like '*msixbundle'  | ForEach-Object {Invoke-WebRequest -Uri ('https://github.com/'+ $_.href ) -OutFile $msWinGetMSIXBundlePath}
$msWinGetLatestRelease.links | Where-Object href -Like '*License*xml' | ForEach-Object {Invoke-WebRequest -Uri ('https://github.com/'+ $_.href ) -OutFile $msWinGetLicensePath}

#Invoke-WebRequest  "https://github.com/microsoft/winget-cli/releases/download/v1.3.1872/a941c144deac426082dc9f208f729138_License1.xml"           -OutFile $msWinGetLicensePath
#Invoke-WebRequest  "https://github.com/microsoft/winget-cli/releases/download/v1.3.1872/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"  -OutFile $msWinGetMSIXBundlePath

# Download the VC++ redistrubable for UWP apps from the Microsoft Store
(Invoke-WebRequest -Uri $msStoreDownloadAPIURL -Method Post -UseBasicParsing -body @{type='url'; url=$msWinGetStoreURL; ring='Retail'; lang='en-US'}).links |
    Where-Object OuterHTML -Like  "*Microsoft.VCLibs*UWPDesktop*$architecture*appx*" |
        Sort-Object outerHTML -Descending |  Select-Object -First 1 -ExpandProperty href |
                ForEach-Object {Invoke-WebRequest -Uri $_ -OutFile $msVCLibDownloadPath}

# Download the Windows UI redistrubable from the Microsoft Store
(Invoke-WebRequest -Uri $msStoreDownloadAPIURL -Method Post -UseBasicParsing -body @{type='url'; url=$msWinGetStoreURL; ring='Retail'; lang='en-US'}).links |
Where-Object OuterHTML -Like "*Microsoft.UI.Xaml*$architecture*appx*" |
    Sort-Object outerHTML -Descending |
        Select-Object -First 1 -ExpandProperty href |
            ForEach-Object {Invoke-WebRequest -Uri $_ -OutFile $msUIXamlDownloadPath}

# Install the WinGet and it's VC++ .msix with the downloaded license file
Add-AppProvisionedPackage -Online -PackagePath $msWinGetMSIXBundlePath -DependencyPackagePath ($msVCLibDownloadPath,$msUIXamlDownloadPath) -LicensePath $msWinGetLicensePath

# Force the creation of the execution alias with NtObjectManager, since one isn't generated automatically in the current user session
$appxPackage = Get-AppxPackage Microsoft.DesktopAppInstaller
$wingetTarget = Join-Path -Path $appxPackage.InstallLocation -ChildPath ((Get-AppxPackageManifest $appxPackage).Package.Applications.Application | Where-Object Id -eq 'winget' | Select-Object -ExpandProperty Executable)
NtObjectManager\Set-ExecutionAlias -Path 'C:\Windows\System32\winget.exe' -PackageName ($appxPackage.PackageFamilyName) -EntryPoint "$($appxPackage.PackageFamilyName)!winget" -Target $wingetTarget -AppType Desktop -Version 3
