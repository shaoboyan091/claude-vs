Describe "windbg-break.ps1" {

    $ScriptPath = "$PSScriptRoot/../../src/vs/windbg-break.ps1"
    $scriptContent = Get-Content $ScriptPath -Raw

    Context "Parameter definitions" {
        $cmd = Get-Command $ScriptPath

        It "Has Breakpoints parameter as string[]" {
            $cmd.Parameters['Breakpoints'].ParameterType.Name | Should Be 'String[]'
        }

        It "Has OnHit with ValidateSet (stack, locals, full, step)" {
            $attrs = $cmd.Parameters['OnHit'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $attrs | Should Not BeNullOrEmpty
            $vals = $attrs.ValidValues
            ($vals -contains "stack") | Should Be $true
            ($vals -contains "locals") | Should Be $true
            ($vals -contains "full") | Should Be $true
            ($vals -contains "step") | Should Be $true
        }

        It "Has StepMode with ValidateSet (over, into)" {
            $attrs = $cmd.Parameters['StepMode'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $attrs | Should Not BeNullOrEmpty
            $vals = $attrs.ValidValues
            ($vals -contains "over") | Should Be $true
            ($vals -contains "into") | Should Be $true
        }

        It "Has MaxHits default 1" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
            $param = $ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'MaxHits' }
            $param.DefaultValue.Value | Should Be 1
        }

        It "Has StepCount default 10" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
            $param = $ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'StepCount' }
            $param.DefaultValue.Value | Should Be 10
        }

        It "Has Timeout default 120" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
            $param = $ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Timeout' }
            $param.DefaultValue.Value | Should Be 120
        }

        It "Has BreakOnEntry switch parameter" {
            $cmd.Parameters['BreakOnEntry'].SwitchParameter | Should Be $true
        }

        It "Has Executable parameter for launch mode" {
            $cmd.Parameters['Executable'] | Should Not BeNullOrEmpty
        }

        It "Has ProcessId parameter for attach mode" {
            $cmd.Parameters['ProcessId'] | Should Not BeNullOrEmpty
        }

        It "Has SymbolPath parameter" {
            $cmd.Parameters['SymbolPath'] | Should Not BeNullOrEmpty
        }

        It "Has PreCommands parameter" {
            $cmd.Parameters['PreCommands'] | Should Not BeNullOrEmpty
        }

        It "Has ValidateRange on MaxHits" {
            $attrs = $cmd.Parameters['MaxHits'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $attrs | Should Not BeNullOrEmpty
        }

        It "Has ValidateRange on StepCount" {
            $attrs = $cmd.Parameters['StepCount'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $attrs | Should Not BeNullOrEmpty
        }

        It "Has ValidateRange on Timeout" {
            $attrs = $cmd.Parameters['Timeout'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $attrs | Should Not BeNullOrEmpty
        }

        It "Has ValidateNotNullOrEmpty on Breakpoints" {
            $attrs = $cmd.Parameters['Breakpoints'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateNotNullOrEmptyAttribute] }
            $attrs | Should Not BeNullOrEmpty
        }
    }

    Context "Command file approach" {
        It "Uses temp file via GetTempFileName" {
            $scriptContent | Should Match 'GetTempFileName'
        }

        It "Uses dollar-less-than for command file execution" {
            $scriptContent | Should Match '\$<'
        }

        It "Cleans up temp file in finally block" {
            $scriptContent | Should Match 'finally'
            $scriptContent | Should Match 'Remove-Item \$tempFile'
        }

        It "Has Build-CommandFile function" {
            $scriptContent | Should Match 'function Build-CommandFile'
        }
    }

    Context "Breakpoint command construction" {
        It "Uses bu command for breakpoints" {
            $scriptContent | Should Match '\bbu\b'
        }

        It "Uses .echo ==BP_HIT== markers" {
            $scriptContent | Should Match '\.echo ==BP_HIT=='
        }

        It "Uses gc command to continue after breakpoint" {
            $scriptContent | Should Match '\bgc\b'
        }

        It "Appends g command to start execution" {
            $scriptContent | Should Match '\+= "g"'
        }
    }

    Context "MaxHits via pseudo-register counter" {
        It "Initializes counter register t0" {
            $scriptContent | Should Match 'r \`\$t0 = 0'
        }

        It "Increments counter on each hit" {
            $scriptContent | Should Match 'r \`\$t0 = @\`\$t0 \+ 1'
        }

        It "Uses .if to check hit count against MaxHits" {
            $scriptContent | Should Match '\.if \(@\`\$t0 >='
        }
    }

    Context "OnHit action mapping" {
        It "Stack action returns marker and k command" {
            $scriptContent | Should Match '"stack"\s*\{\s*return'
            $scriptContent | Should Match 'marker};k'
        }

        It "Locals action returns marker with k and dv /t" {
            $scriptContent | Should Match 'marker};k;dv /t"'
        }

        It "Full action returns marker with k, dv /t, and r" {
            $scriptContent | Should Match 'marker};k;dv /t;r"'
        }

        It "Step action generates step commands in a loop" {
            $scriptContent | Should Match '"step"\s*\{'
            $scriptContent | Should Match 'for \(\$i = 1'
        }
    }

    Context "Step mode" {
        It "Step-over uses p command, step-into uses t command" {
            $scriptContent | Should Match '"into"\) \{ "t" \} else \{ "p" \}'
        }

        It "Uses ==STEP== markers for step output" {
            $scriptContent | Should Match '==STEP=='
        }
    }

    Context "Symbol and pre-command setup" {
        It "Supports SymbolPath with .sympath+" {
            $scriptContent | Should Match '\.sympath\+'
        }

        It "Calls .reload after setting symbol path" {
            $scriptContent | Should Match '\.reload'
        }

        It "Runs PreCommands before breakpoints" {
            $scriptContent | Should Match '\$PreCmds'
        }
    }

    Context "Exception handling" {
        It "Disables first-chance exceptions with sxd *" {
            $scriptContent | Should Match 'sxd \*'
        }

        It "Enables process exit event with sxe epr" {
            $scriptContent | Should Match 'sxe epr'
        }
    }

    Context "Output parsing" {
        It "Has Parse-BreakpointOutput function" {
            $scriptContent | Should Match 'function Parse-BreakpointOutput'
        }

        It "Splits output by BP_HIT markers" {
            $scriptContent | Should Match '==BP_HIT=='
        }

        It "Splits step output by STEP markers" {
            $scriptContent | Should Match '==STEP==\(\\\d\+\)==|==STEP=='
        }

        It "Produces JSON output with breakpoints array" {
            $scriptContent | Should Match 'breakpoints\s*=\s*\$bpResults'
        }

        It "Parses markers sequentially not per-location" {
            $scriptContent | Should Match 'allMatches'
        }

        It "Parses per-step stack and locals" {
            $scriptContent | Should Match 'sStack'
            $scriptContent | Should Match 'sLocals'
        }
    }

    Context "Process execution pattern" {
        It "Uses ProcessStartInfo for process launch" {
            $scriptContent | Should Match 'System\.Diagnostics\.ProcessStartInfo'
        }

        It "Uses ReadToEndAsync for async stdout/stderr" {
            $scriptContent | Should Match 'ReadToEndAsync'
        }

        It "Kills process on timeout" {
            $scriptContent | Should Match 'if \(-not \$exited\)[\s\S]*?\$process\.Kill\(\)'
        }

        It "Outputs JSON via ConvertTo-Json" {
            $scriptContent | Should Match 'ConvertTo-Json \$output -Depth 5'
        }
    }

    Context "Launch vs attach mode" {
        It "Uses -g flag in launch mode (skip initial break)" {
            $scriptContent | Should Match '\$cmdArgs \+= "-g"'
        }

        It "Uses -G flag in launch mode (skip final break)" {
            $scriptContent | Should Match '\$cmdArgs \+= "-G"'
        }

        It "Uses -p flag with PID in attach mode" {
            $scriptContent | Should Match '\$cmdArgs \+= "-p"'
        }

        It "BreakOnEntry controls -g flag" {
            $scriptContent | Should Match 'if \(-not \$BreakOnEntry\)'
        }

        It "Requires either ProcessId or Executable" {
            $scriptContent | Should Match 'Must specify either -ProcessId.*or -Executable'
        }

        It "Uses .detach in attach mode quit command" {
            $scriptContent | Should Match '\.detach;q'
        }
    }
}
