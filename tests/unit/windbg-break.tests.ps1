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

        It "Uses $$><@ for quoted command file execution" {
            $scriptContent | Should Match '\$\$><@'
        }

        It "Uses 8.3 short path for temp file" {
            $scriptContent | Should Match 'ShortPath'
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

    Context "Per-breakpoint hit counters" {
        It "Initializes per-BP counter registers" {
            $scriptContent | Should Match 'r \`\$t\$i = 0'
        }

        It "Increments per-BP counter on each hit" {
            $scriptContent | Should Match 'r \`\$t\$i = @\`\$t\$i \+ 1'
        }

        It "Uses .if to check per-BP hit count against MaxHits" {
            $scriptContent | Should Match '\.if \(@\`\$t\$i >='
        }

        It "Enforces 20 breakpoint limit" {
            $scriptContent | Should Match 'Maximum 20 breakpoints'
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

        It "Re-enables access violation with sxe av" {
            $scriptContent | Should Match 'sxe av'
        }

        It "Re-enables stack overflow with sxe sov" {
            $scriptContent | Should Match 'sxe sov'
        }

        It "Enables process exit event with sxe ep and a handler command" {
            $scriptContent | Should Match 'sxe -c.*PROCESS_EXITED.*ep'
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
            $scriptContent | Should Match '==STEP=='
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

        It "Uses improved locals detection regex with = pattern" {
            $scriptContent | Should Match '\\w\+\\s\+=\\s\+'
        }

        It "Excludes stack header lines from locals detection" {
            $scriptContent | Should Match 'Child-SP|RetAddr|Call Site'
        }

        It "Register detection requires hex digit after equals" {
            $scriptContent | Should Match '\[a-z\].*=\[0-9a-f\]'
        }
    }

    Context "Process execution pattern" {
        It "Uses ProcessStartInfo for process launch" {
            $scriptContent | Should Match 'System\.Diagnostics\.ProcessStartInfo'
        }

        It "Uses ReadToEndAsync for async stdout/stderr" {
            $scriptContent | Should Match 'ReadToEndAsync'
        }

        It "Redirects stdin for graceful shutdown" {
            $scriptContent | Should Match 'RedirectStandardInput\s*=\s*\$true'
        }

        It "Attempts graceful detach before kill on timeout" {
            $scriptContent | Should Match 'StandardInput\.WriteLine.*\.detach'
        }

        It "Falls back to Kill on timeout" {
            $scriptContent | Should Match '\$process\.Kill\(\)'
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

        It "Warns when BreakOnEntry used in attach mode" {
            $scriptContent | Should Match 'Write-Warning.*BreakOnEntry.*attach'
        }

        It "Requires either ProcessId or Executable" {
            $scriptContent | Should Match 'Must specify either -ProcessId.*or -Executable'
        }

        It "Rejects both ProcessId and Executable" {
            $scriptContent | Should Match 'Cannot specify both'
        }

        It "Uses .detach in attach mode quit command" {
            $scriptContent | Should Match '\.detach;q'
        }
    }

    Context "Build-BreakpointAction output" {
        BeforeAll {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
            $functions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
            foreach ($fn in $functions) {
                Invoke-Expression $fn.Extent.Text
            }
        }

        It "Returns marker and k for stack mode" {
            $result = Build-BreakpointAction -Location "mod!Func" -Action "stack" -Steps 0 -StepCmd "p"
            $result | Should Match '==BP_HIT==mod!Func=='
            $result | Should Match ';k$'
        }

        It "Returns marker, k, dv /t for locals mode" {
            $result = Build-BreakpointAction -Location "mod!Func" -Action "locals" -Steps 0 -StepCmd "p"
            $result | Should Match ';k;dv /t$'
        }

        It "Returns marker, k, dv /t, r for full mode" {
            $result = Build-BreakpointAction -Location "mod!Func" -Action "full" -Steps 0 -StepCmd "p"
            $result | Should Match ';k;dv /t;r$'
        }

        It "Returns step commands with STEP markers for step mode" {
            $result = Build-BreakpointAction -Location "mod!Func" -Action "step" -Steps 3 -StepCmd "p"
            $result | Should Match '==STEP==1=='
            $result | Should Match '==STEP==2=='
            $result | Should Match '==STEP==3=='
            $result | Should Match ';p;'
        }

        It "Uses t command for step-into mode" {
            $result = Build-BreakpointAction -Location "mod!Func" -Action "step" -Steps 1 -StepCmd "t"
            $result | Should Match ';t;'
        }
    }

    Context "Build-CommandFile output" {
        BeforeAll {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
            $functions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
            foreach ($fn in $functions) {
                Invoke-Expression $fn.Extent.Text
            }
        }

        It "Generates file with counter init, bu commands, and g" {
            $tmpFile = [System.IO.Path]::GetTempFileName()
            try {
                Build-CommandFile -TempPath $tmpFile `
                    -BpLocations @("mod!FuncA", "mod!FuncB") `
                    -Action "full" -Steps 10 -StepCmd "p" `
                    -MaxHitCount 2 -IsAttachMode $false `
                    -SymPath "" -PreCmds ""
                $content = Get-Content $tmpFile -Raw

                $content | Should Match 'r \$t0 = 0'
                $content | Should Match 'r \$t1 = 0'
                $content | Should Match 'bu mod!FuncA'
                $content | Should Match 'bu mod!FuncB'
                $content | Should Match '\ng\s*$'
            } finally {
                Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
            }
        }

        It "Includes .sympath+ and .reload when SymPath is set" {
            $tmpFile = [System.IO.Path]::GetTempFileName()
            try {
                Build-CommandFile -TempPath $tmpFile `
                    -BpLocations @("mod!Func") `
                    -Action "stack" -Steps 0 -StepCmd "p" `
                    -MaxHitCount 1 -IsAttachMode $false `
                    -SymPath "C:\symbols" -PreCmds ""
                $content = Get-Content $tmpFile -Raw

                $content | Should Match '\.sympath\+ C:\\symbols'
                $content | Should Match '\.reload'
            } finally {
                Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
            }
        }

        It "Includes .detach in quit command for attach mode" {
            $tmpFile = [System.IO.Path]::GetTempFileName()
            try {
                Build-CommandFile -TempPath $tmpFile `
                    -BpLocations @("mod!Func") `
                    -Action "stack" -Steps 0 -StepCmd "p" `
                    -MaxHitCount 1 -IsAttachMode $true `
                    -SymPath "" -PreCmds ""
                $content = Get-Content $tmpFile -Raw

                $content | Should Match '\.detach;q'
            } finally {
                Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Parse-BreakpointOutput with realistic input" {
        BeforeAll {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
            $functions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
            foreach ($fn in $functions) {
                Invoke-Expression $fn.Extent.Text
            }
        }

        It "Parses single breakpoint hit with stack" {
            $raw = "some preamble`n==BP_HIT==mod!Func==`nChild-SP          RetAddr           Call Site`n00000000`'1234abcd 00000000`'5678efgh mod!Func+0x10`n"
            $results = @(Parse-BreakpointOutput -RawOutput $raw -Locations @("mod!Func"))
            $results.Count | Should Be 1
            $results[0].hitCount | Should Be 1
            $results[0].location | Should Be "mod!Func"
            $results[0].hits[0].stack | Should Match 'mod!Func'
        }

        It "Parses multiple hits for same breakpoint" {
            $raw = "==BP_HIT==mod!Func==`nstack1`n==BP_HIT==mod!Func==`nstack2`n"
            $results = @(Parse-BreakpointOutput -RawOutput $raw -Locations @("mod!Func"))
            $results[0].hitCount | Should Be 2
        }

        It "Parses step output with STEP markers" {
            $raw = "==BP_HIT==mod!Func==`ninitial stack`n==STEP==1==`nmod!Func+0x5:`n00 00`nChildSP line`n==STEP==2==`nmod!Func+0xa:`n"
            $results = @(Parse-BreakpointOutput -RawOutput $raw -Locations @("mod!Func"))
            $results[0].hits[0].steps.Count | Should Be 2
            $results[0].hits[0].steps[0].step | Should Be 1
            $results[0].hits[0].steps[1].step | Should Be 2
        }

        It "Returns zero hitCount for unhit breakpoints" {
            $raw = "==BP_HIT==mod!FuncA==`nstack`n"
            $results = @(Parse-BreakpointOutput -RawOutput $raw -Locations @("mod!FuncA", "mod!FuncB"))
            $results[1].hitCount | Should Be 0
            $results[1].location | Should Be "mod!FuncB"
        }

        It "Parses locals with assignment pattern" {
            $raw = "==BP_HIT==mod!Func==`nChild-SP RetAddr Call Site`n00 00 mod!Func`nint x = 42`nfloat y = 3.14`n"
            $results = @(Parse-BreakpointOutput -RawOutput $raw -Locations @("mod!Func"))
            $results[0].hits[0].locals | Should Match 'x = 42'
        }

        It "Parses registers starting with lowercase letters" {
            $raw = "==BP_HIT==mod!Func==`nChild-SP RetAddr Call Site`n00 00 mod!Func`nrax=0000000000000001 rbx=0000000000000002`n"
            $results = @(Parse-BreakpointOutput -RawOutput $raw -Locations @("mod!Func"))
            $results[0].hits[0].registers | Should Match 'rax=0000000000000001'
        }
    }

    Context "Error validation" {
        It "Throws when both Executable and ProcessId are specified" {
            {
                & $ScriptPath -Executable "C:\fake.exe" -ProcessId 9999 -Breakpoints "main" 2>&1
            } | Should Throw
        }
    }
}
