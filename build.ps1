. (Join-Path -Path src -ChildPath Cobalt.ps1 -Resolve)

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
		$VerbOriginalCommandElements = $_.OriginalCommandElements ?? @()
		$VerbParameters = $_.Parameters ?? @()
		$VerbOutputHandlers = $_.OutputHandlers
		$Description = $_.Description
		$VerbDefaultParameterSetName = $_.DefaultParameterSetName
		$tempJson = New-TemporaryFile
		New-CrescendoCommand -Verb $_.Verb -Noun $Noun | ForEach-Object {
			$_.OriginalName = $BaseOriginalName
			# Marge command elements in order of noun-level first, then verb-level, then generic
			$_.OriginalCommandElements = ($NounOriginalCommandElements + $VerbOriginalCommandElements + $BaseOriginalCommandElements)
			$_.Description = $Description
			# Merge parameters in order of noun-level, then verb-level, then generic
			$_.Parameters = ($NounParameters + $VerbParameters + $BaseParameters)
			# Prefer verb-level default parameter set name first, then noun-level, then generic
			$_.DefaultParameterSetName = ($VerbDefaultParameterSetName ?? $NounDefaultParameterSetName) ?? $BaseDefaultParameterSetName
			# Prefer verb-level handlers first, then noun-level, then generic
			$_.OutputHandlers = ($VerbOutputHandlers ?? $NounOutputHandlers) ?? $BaseOutputHandlers
			$_
		} | ConvertTo-Json -Depth 100 | Out-File $tempJson
		# The -Depth parameter is required for complex objects with more than 2 layers of nesting
		$tempJsonArray += $tempJson
	}
}

Export-CrescendoModule -ConfigurationFile $tempJsonArray -ModuleName (Join-Path -Path src -ChildPath Cobalt.psm1) -Force
