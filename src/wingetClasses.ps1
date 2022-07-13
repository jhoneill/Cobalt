using namespace 'System.Management.Automation'
using namespace 'System.Management.Automation.Language'
using namespace 'System.Collections'
using namespace 'System.Collections.Generic'

class wingetIDCompleter        : IArgumentCompleter {
    [IEnumerable[CompletionResult]] CompleteArgument( [string]$CommandName, [string]$ParameterName, [string]$WordToComplete,
                                                      [CommandAst]$CommandAst, [IDictionary] $FakeBoundParameters) {
        $results        = [List[CompletionResult]]::new()
        if (-not $FakeBoundParameters['MSStore']) {
            $wordToComplete = ($wordToComplete -replace "^`"|^'|'$|`"$", '' ) +"*"
            $global:WingetVersions.keys | Where-Object {$_ -like  $wordToComplete}| Sort-Object | ForEach-Object {
                if ($_ -notmatch '\W'){$results.Add([System.Management.Automation.CompletionResult]::new(    $_    , $_, ([System.Management.Automation.CompletionResultType]::ParameterValue) , $_)) }
                else                  {$results.Add([System.Management.Automation.CompletionResult]::new("'$($_)'" , $_, ([System.Management.Automation.CompletionResultType]::ParameterValue) , $_)) }
            }
        }
        return $results
    }
}

class wingetVerSionCompleter   : IArgumentCompleter {
    [IEnumerable[CompletionResult]] CompleteArgument( [string]$CommandName, [string]$ParameterName, [string]$WordToComplete,
                                                      [CommandAst]$CommandAst, [IDictionary] $FakeBoundParameters) {
        $results        = [List[CompletionResult]]::new()
        $wordToComplete = ($wordToComplete -replace "^`"|^'|'$|`"$", '' ) +"*"
        if ($FakeBoundParameters['ID']) {
            $global:WingetVersions[$FakeBoundParameters['ID']] | Where-Object {$_ -like  $wordToComplete}| sort-object | ForEach-Object {
                if ($_ -notmatch '\W'){$results.Add([System.Management.Automation.CompletionResult]::new(    $_    , $_, ([System.Management.Automation.CompletionResultType]::ParameterValue) , $_)) }
                else                  {$results.Add([System.Management.Automation.CompletionResult]::new("'$($_)'" , $_, ([System.Management.Automation.CompletionResultType]::ParameterValue) , $_)) }
            }
        }
        return $results
    }
}

class wingetCommandCompleter   : IArgumentCompleter {
    [IEnumerable[CompletionResult]] CompleteArgument( [string]$CommandName, [string]$ParameterName, [string]$WordToComplete,
                                                      [CommandAst]$CommandAst, [IDictionary] $FakeBoundParameters) {
        $results        = [List[CompletionResult]]::new()
        $wordToComplete = ($wordToComplete -replace "^`"|^'|'$|`"$", '' ) +"*"
        $Global:WingetCommands.get_keys() | Where-Object {$_ -like  $wordToComplete}| Sort-Object | ForEach-Object {
            if ($_ -notmatch '\W'){$results.Add([System.Management.Automation.CompletionResult]::new(    $_    , $_, ([System.Management.Automation.CompletionResultType]::ParameterValue) , $_)) }
            else                  {$results.Add([System.Management.Automation.CompletionResult]::new("'$($_)'" , $_, ([System.Management.Automation.CompletionResultType]::ParameterValue) , $_)) }
        }
        return $results
    }
}

class wingetTagCompleter       : IArgumentCompleter {
    [IEnumerable[CompletionResult]] CompleteArgument( [string]$CommandName, [string]$ParameterName, [string]$WordToComplete,
                                                      [CommandAst]$CommandAst, [IDictionary] $FakeBoundParameters) {
        $results        = [List[CompletionResult]]::new()
        $wordToComplete = ($wordToComplete -replace "^`"|^'|'$|`"$", '' ) +"*"
        $Global:WingetTags.get_keys() | Where-Object {$_ -like  $wordToComplete}| Sort-Object | ForEach-Object {
            if ($_ -notmatch '\W'){$results.Add([System.Management.Automation.CompletionResult]::new(    $_    , $_, ([System.Management.Automation.CompletionResultType]::ParameterValue) , $_)) }
            else                  {$results.Add([System.Management.Automation.CompletionResult]::new("'$($_)'" , $_, ([System.Management.Automation.CompletionResultType]::ParameterValue) , $_)) }
        }
        return $results
    }
}
