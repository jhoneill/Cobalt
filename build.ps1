.           (Join-Path -Path src -ChildPath Cobalt.ps1 -Resolve)
$psm1path = (Join-Path -Path src -ChildPath Cobalt.psm1)
$tempJsonArray = @()

$commands | ForEach-Object {
	$Noun = $_.Noun
	# Inherit noun-level attributes (if they exist) for all commands
	# If no noun-level original command elements or parameters exist, return an empty array for easy merging later
	$NounOriginalCommandElements = $_.OriginalCommandElements ?? @()
	$NounParameters = $_.Parameters ?? @()
	# Output handlers work differently - they will supercede each other, instead of being merged.
	$NounOutputHandlers = $_.OutputHandlers
	$NounDefaultParameterSetName = $_.DefaultParameterSetName
	$_.Verbs | ForEach-Object {
		# Same logic as nouns - prepare verb-level original command elements and parameters for merging, but not output handlers
		$tempJson = New-TemporaryFile
        $nccParams = @{ #Put the parameters for the new crescendo command into a hash table then splat it
            Verb                    = $_.Verb
            Noun                    = $Noun
            Description             = $_.Description
            OriginalName            = $BaseOriginalName
            # Merge command elements in order of noun-level first, then verb-level, then generic
            OriginalCommandElements = ($NounOriginalCommandElements + ($_.OriginalCommandElements ?? @()) + $BaseOriginalCommandElements)
            # Merge parameters in order of noun-level, then verb-level, then generic
            Parameters              = ($NounParameters + ($_.Parameters ?? @()) + $BaseParameters)
            # Prefer verb-level handlers first, then noun-level, then generic
            OutputHandlers          = ($_.OutputHandlers ?? $NounOutputHandlers) ?? $BaseOutputHandlers
            # Prefer verb-level default parameter set name first, then noun-level, then generic
            DefaultParameterSetName = ($_.DefaultParameterSetName ?? $NounDefaultParameterSetName) ?? $BaseDefaultParameterSetName
        }
        if ($_.ConfirmImpact)         {$nccParams['ConfirmImpact']         = $_.ConfirmImpact}
        if ($_.SupportsShouldProcess) {$nccParams['SupportsShouldProcess'] = $_.SupportsShouldProcess}
        if ($_.Platform)              {$nccParams['Platform']              = $_.Platform}
        New-CrescendoCommand @nccParams | ConvertTo-Json -Depth 100 | Out-File $tempJson
		# The -Depth parameter is required for complex objects with more than 2 layers of nesting
		$tempJsonArray += $tempJson
	}
}

Export-CrescendoModule -ConfigurationFile $tempJsonArray -ModuleName $psm1Path -Force -TypesToProcess .\winget.types.ps1xml -ScriptsToProcess .\wingetClasses.ps1 -RequiredModules getsql, powershell-yaml -FunctionsToExport @(
'Get-InstalledSoftware', 'Clear-WingetCache', 'Update-WingetCache', 'Find-WinGetPackage', 'Get-WinGetPackage', 'Install-WinGetPackage', 'Uninstall-WinGetPackage', 'Update-WinGetPackage','Get-WinGetPackageInfo',
  'Get-WinGetPackageUpdate' , 'Get-WinGetSource', 'Register-WinGetSource', 'Unregister-WinGetSource') -Author "Ethan Bergstrom, James O'Neill" -Copyright "Orginal work Copyright 2021 Ethan Bergstrom, additions Copyright 2022 James O'Neill"
Get-Content .\winget-tools.ps1 >> $psm1path
