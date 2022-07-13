<#
Copyright 2022 James O'Neill

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

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
