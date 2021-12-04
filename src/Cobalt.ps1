$BaseOriginalName = 'WinGet'

$BaseOriginalCommandElements = @()

$BaseParameters = @()

$BaseOutputHandlers = @{
    ParameterSetName = 'Default'
    Handler = {
        param ( $output )
    }
}
# The general structure of this hashtable is to define noun-level attributes, which are -probably- common across all commands for the same noun, but still allow for customization at more specific verb-level defition for that noun.
# The following three command attributes have the following order of precedence:
# 	OriginalCommandElements will be MERGED in the order of Noun + Verb + Base
#		Example: Noun WinGetSource's element 'source', Verb Register's element 'add', and Base elements are merged to become 'WinGet source add --limit-output --yes'
# 	Parameters will be MERGED in the order of Noun + Verb + Base
#		Example: Noun WinGetPackage's parameters for package name and version and Verb Install's parameter specifying source information are merged to become '<packageName> --version=<packageVersion> --source=<packageSource>'.
#			These are then appended to the merged original command elements, to create 'WinGet install <packageName> --version=<packageVersion> --source=<packageSource> --limit-output --yes'
# 	OutputHandler sets will SUPERCEDE each other in the order of: Verb -beats-> Noun -beats-> Base. This allows reusability of PowerShell parsing code.
#		Example: Noun WinGetPackage has inline output handler PowerShell code with complex regex that works for both Install-WinGetPackage and Uninstall-WinGetPackage, but Get-WinGetPackage's native output uses simple vertical bar delimiters.
#		Example 2: The native commands for Register-WinGetSource and Unregister-WinGetSource don't return any output, and until Crescendo supports error handling by exit codes, a base required default output handler that doesn't do anything can be defined and reused in multiple places.
$Commands = @(
    @{
        Noun = 'WinGetSource'
        OriginalCommandElements = @('source')
        Verbs = @(
            @{
                Verb = 'Get'
                Description = 'Return WinGet package sources'
                OriginalCommandElements = @('export')
                Parameters = @(
                    @{
                        Name = 'Name'
                        ParameterType = 'string'
                        Description = 'Source Name'
                        OriginalName = '--name='
                        NoGap = $true
                    }
                )
                OutputHandlers = @{
                    ParameterSetName = 'Default'
                    Handler = {
                        param ($output)
                        if ($output) {
                            $output | ConvertFrom-Json
                        }
                    }
                }
            },
            @{
                Verb = 'Register'
                Description = 'Register a new WinGet package source'
                OriginalCommandElements = @('add')
                Parameters = @(
                    @{
                        Name = 'Name'
                        ParameterType = 'string'
                        Description = 'Source Name'
                        OriginalName = '--name='
                        NoGap = $true
                        Mandatory = $true
                    },
                    @{
                        Name = 'Argument'
                        OriginalName = '--arg='
                        ParameterType = 'string'
                        Description = 'Source Argument'
                        NoGap = $true
                        Mandatory = $true
                    }
                )
                OutputHandlers = @{
                    ParameterSetName = 'Default'
                    Handler = {
                        param ($output)
                        if ($output) {
                            if ($output[-1] -ne 'Done') {
                                Write-Error ($output -join "`r`n")
                            }
                        }
                    }
                }
            },
            @{
                Verb = 'Unregister'
                Description = 'Unegister an existing WinGet package source'
                OriginalCommandElements = @('remove')
                Parameters = @(
                    @{
                        Name = 'Name'
                        ParameterType = 'string'
                        Description = 'Source Name'
                        OriginalName = '--name='
                        NoGap = $true
                        Mandatory = $true
                        ValueFromPipelineByPropertyName = $true
                    }
                )
                OutputHandlers = @{
                    ParameterSetName = 'Default'
                    Handler = {
                        param ($output)
                        if ($output) {
                            if ($output[-1] -match 'Did not find a source') {
                                Write-Error ($output -join "`r`n")
                            }
                        }
                    }
                }
            }
        )
    },
    @{
        Noun = 'WinGetPackage'
        Parameters = @(
            @{
                Name = 'ID'
                OriginalName = '--id='
                ParameterType = 'string'
                Description = 'Package ID'
                NoGap = $true
                ValueFromPipelineByPropertyName = $true
            },
            @{
                Name = 'Exact'
                OriginalName = '--exact'
                ParameterType = 'switch'
                Description = 'Search by exact package name'
            },
            @{
                Name = 'Source'
                OriginalName = '--source='
                ParameterType = 'string'
                Description = 'Package Source'
                NoGap = $true
                ValueFromPipelineByPropertyName = $true
            }
        )
        OutputHandlers = @{
            ParameterSetName = 'Default'
            Handler = {
                param ( $output )

                if ($output -Match '^Name') {

                    $headerLine = $output.IndexOf(($output -Match '^Name' | Select-Object -First 1))

                    if ($headerLine -ne -1) {
                        $idIndex = $output[$headerLine].IndexOf('Id')
                        $versionIndex = $output[$headerLine].IndexOf('Version')
                        $availableIndex = $output[$headerLine].IndexOf('Available')
                        $sourceIndex = $output[$headerLine].IndexOf('Source')

                        # Stop gathering version data at the 'Available' column if it exists, if not continue on to the 'Source' column (if it exists)
                        $versionEndIndex = $(
                            if ($availableIndex -ne -1) {
                                $availableIndex
                            } else {
                                $sourceIndex
                            }
                        )

                        # The -replace cleans up errant characters that come from WinGet's poor treatment of truncated columnar output
                        $output -replace '[^i\p{IsBasicLatin}]',' ' | Select-Object -Skip ($headerLine+2) | ForEach-Object {
                            $package = [ordered]@{
                                ID = $_.SubString($idIndex,$versionIndex-$idIndex).Trim()
                            }

                            # I'm so sorry, blame WinGet
                            # If neither the 'Available' or 'Source' column exist, gather version data to the end of the string
                            $package.Version = $(
                                if ($versionEndIndex -ne -1) {
                                    $_.SubString($versionIndex,$versionEndIndex-$versionIndex)
                                } else {
                                    $_.SubString($versionIndex)
                                }
                            ).Trim() -replace '[^\.\d]'

                            # If the 'Source' column was included in the output, include it in our output, too
                            if (($sourceIndex -ne -1) -And ($_.Length -ge $sourceIndex)) {
                                $package.Source = $_.SubString($sourceIndex).Trim() -split ' ' | Select-Object -Last 1
                            }

                            [pscustomobject]$package
                        }
                    }
                }
            }
        }
        Verbs = @(
            @{
                Verb = 'Install'
                Description = 'Install a new package with WinGet'
                OriginalCommandElements = @('install','--accept-package-agreements','--accept-source-agreements','--silent')
                Parameters = @(
                    @{
                        Name = 'Version'
                        OriginalName = '--version='
                        ParameterType = 'string'
                        Description = 'Package Version'
                        NoGap = $true
                        ValueFromPipelineByPropertyName = $true
                    }
                )
                OutputHandlers = @{
                    ParameterSetName = 'Default'
                    Handler = {
                        param ($output)
                        if ($output) {
                            if ($output -match 'failed') {
                                Write-Error ($output -join "`r`n")
                            } else {
                                $output | ForEach-Object {
                                    if ($_ -match '\[(?<id>[\S]+)\] Version (?<version>[\S]+)' -and $Matches.id -and $Matches.version) {
                                            [pscustomobject]@{
                                                ID = $Matches.id
                                                Version = $Matches.version
                                            }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            @{
                Verb = 'Get'
                Description = 'Get a list of installed WinGet packages'
                OriginalCommandElements = @('list','--accept-source-agreements')
            },
            @{
                Verb = 'Find'
                Description = 'Find a list of available WinGet packages'
                OriginalCommandElements = @('search','--accept-source-agreements')
            },
            @{
                Verb = 'Uninstall'
                Description = 'Uninstall an existing package with WinGet'
                OriginalCommandElements = @('uninstall','--accept-source-agreements','--silent')
                # We don't know what failed WinGet package uninstallation looks like
                OutputHandlers = @{
                    ParameterSetName = 'Default'
                    Handler = {
                        param ($output)
                    }
                }
            }
        )
    }
)
