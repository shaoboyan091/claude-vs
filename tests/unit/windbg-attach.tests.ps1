Describe "windbg-attach.ps1" {

    $ScriptPath = "$PSScriptRoot/../../src/vs/windbg-attach.ps1"
    $scriptContent = Get-Content $ScriptPath -Raw

    $findCdbDef = [regex]::Match($scriptContent, '(?s)function Find-CdbExe \{.*?\n\}').Value
    Invoke-Expression $findCdbDef

    Context "Find-CdbExe searches expected paths" {
        It "Checks Windows SDK x64 path" {
            $findCdbDef | Should Match 'Windows Kits\\10\\Debuggers\\x64\\cdb\.exe'
        }

        It "Checks WinDbg Preview Store app path" {
            $findCdbDef | Should Match 'Microsoft\\WindowsApps\\cdb\.exe'
        }

        It "Checks PATH via Get-Command" {
            $findCdbDef | Should Match 'Get-Command cdb\.exe'
        }

        It "Searches LOCALAPPDATA WinDbg directories" {
            $findCdbDef | Should Match 'WinDbg\*'
        }

        It "Throws when cdb.exe not found anywhere" {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'cdb.exe' }
            Mock Test-Path { $false }
            Mock Get-ChildItem { @() }

            { Find-CdbExe } | Should Throw "not found"
        }
    }

    Context "Argument construction" {
        It "Includes -p flag with PID" {
            $scriptContent | Should Match '\$cmdArgs \+= "-p"'
            $scriptContent | Should Match '\$cmdArgs \+= \$ProcessId\.ToString\(\)'
        }

        It "Includes -o flag when ChildProcesses is set" {
            $scriptContent | Should Match 'if \(\$ChildProcesses\)[\s\S]*?\$cmdArgs \+= "-o"'
        }

        It "Includes -c flag with commands" {
            $scriptContent | Should Match '\$cmdArgs \+= "-c"'
        }

        It "Includes -loga flag when OutputLog specified" {
            $scriptContent | Should Match '\$cmdArgs \+= "-loga"'
        }
    }

    Context "Default commands when none specified" {
        It "Uses '~*k;.detach;q' as default" {
            $scriptContent | Should Match '~\*k;\.detach;q'
        }
    }

    Context ".detach;q append logic" {
        It "Appends .detach;q when missing from Commands" {
            $scriptContent | Should Match "if \(\`$cmdString -notmatch '\\\.detach'"
        }

        It "Does not append when .detach already present" {
            $scriptContent | Should Match '-notmatch.*\\\.detach.*-and.*-notmatch.*\\bq\\b'
        }

        It "Always appends .detach;q after CommandFile execution" {
            $scriptContent | Should Match '\$`<\$CommandFile;\.detach;q'
        }
    }

    Context "Process execution (mocked)" {
        $fakePid = 9999

        It "Has ProcessId parameter for attach mode" {
            $cmd = Get-Command $ScriptPath
            $cmd.Parameters['ProcessId'] | Should Not BeNullOrEmpty
        }

        It "Has Executable parameter for launch mode" {
            $cmd = Get-Command $ScriptPath
            $cmd.Parameters['Executable'] | Should Not BeNullOrEmpty
        }

        It "Has WorkingDirectory parameter for launch mode" {
            $cmd = Get-Command $ScriptPath
            $cmd.Parameters['WorkingDirectory'] | Should Not BeNullOrEmpty
        }

        It "Verifies target process exists before attaching" {
            $scriptContent | Should Match 'Get-Process -Id \$ProcessId -ErrorAction Stop'
        }

        It "Has default timeout of 60 seconds" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
            $paramBlock = $ast.ParamBlock
            $timeoutParam = $paramBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Timeout' }
            $timeoutParam.DefaultValue.Value | Should Be 60
        }

        It "Kills process and throws on timeout" {
            $scriptContent | Should Match 'if \(-not \$exited\)[\s\S]*?\$process\.Kill\(\)'
        }
    }

    Context "Launch mode (run executable under debugger)" {
        It "Uses -g -G flags for launch mode" {
            $scriptContent | Should Match '\$cmdArgs \+= "-g"'
            $scriptContent | Should Match '\$cmdArgs \+= "-G"'
        }

        It "Puts executable at end of argument list" {
            $scriptContent | Should Match '\$cmdArgs \+= \$Executable'
        }

        It "Sets WorkingDirectory on ProcessStartInfo" {
            $scriptContent | Should Match '\$psi\.WorkingDirectory = \$WorkingDirectory'
        }

        It "Requires either ProcessId or Executable" {
            $scriptContent | Should Match 'Must specify either -ProcessId.*or -Executable'
        }

        It "Uses q instead of .detach;q in launch mode defaults" {
            $scriptContent | Should Match '\$cmdString = "~\*k;q"'
        }
    }
}
