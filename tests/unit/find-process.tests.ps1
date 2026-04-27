Describe "find-process.ps1" {

    $ScriptPath = "$PSScriptRoot/../../src/util/find-process.ps1"

    Context "Parameter validation" {
        It "Has default ProcessName of 'chrome'" {
            $cmd = Get-Command $ScriptPath
            $cmd.Parameters['ProcessName'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }) | Should Not BeNullOrEmpty
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
            $paramBlock = $ast.ParamBlock
            $pnParam = $paramBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'ProcessName' }
            $pnParam.DefaultValue.Value | Should Be "chrome"
        }

        It "Type parameter accepts only valid values" {
            $cmd = Get-Command $ScriptPath
            $validateSet = $cmd.Parameters['Type'].Attributes.Where({ $_ -is [System.Management.Automation.ValidateSetAttribute] })
            $validateSet.Count | Should Be 1
            ($validateSet[0].ValidValues -contains "browser") | Should Be $true
            ($validateSet[0].ValidValues -contains "gpu") | Should Be $true
            ($validateSet[0].ValidValues -contains "renderer") | Should Be $true
            ($validateSet[0].ValidValues -contains "utility") | Should Be $true
            ($validateSet[0].ValidValues -contains "crashpad") | Should Be $true
        }

        It "Rejects invalid Type values" {
            { & $ScriptPath -Type "invalid" } | Should Throw
        }
    }

    Context "Get-ChromeProcessType logic" {
        $scriptContent = Get-Content $ScriptPath -Raw
        $functionDef = [regex]::Match($scriptContent, '(?s)function Get-ChromeProcessType \{.*?\n\}').Value
        Invoke-Expression $functionDef

        It "Returns 'browser' for null/empty command line" {
            Get-ChromeProcessType -CommandLine "" | Should Be "browser"
            Get-ChromeProcessType -CommandLine $null | Should Be "browser"
            Get-ChromeProcessType -CommandLine "   " | Should Be "browser"
        }

        It "Returns 'browser' when no --type= flag present" {
            Get-ChromeProcessType -CommandLine "chrome.exe --flag1 --flag2" | Should Be "browser"
        }

        It "Returns 'gpu' for --type=gpu" {
            Get-ChromeProcessType -CommandLine "chrome.exe --type=gpu --other-flag" | Should Be "gpu"
        }

        It "Returns 'renderer' for --type=renderer" {
            Get-ChromeProcessType -CommandLine "chrome.exe --type=renderer --disable-features=X" | Should Be "renderer"
        }

        It "Returns 'utility' for --type=utility" {
            Get-ChromeProcessType -CommandLine "chrome.exe --type=utility --utility-sub-type=network" | Should Be "utility"
        }
    }

    Context "Process filtering with mocked Get-CimInstance" {
        $mockProcesses = @(
                [PSCustomObject]@{
                    ProcessId       = 1000
                    Name            = "chrome.exe"
                    CommandLine     = "C:\chrome\chrome.exe --flag"
                    ExecutablePath  = "C:\chrome\chrome.exe"
                    ParentProcessId = 500
                }
                [PSCustomObject]@{
                    ProcessId       = 1001
                    Name            = "chrome.exe"
                    CommandLine     = "C:\chrome\chrome.exe --type=gpu --enable-features"
                    ExecutablePath  = "C:\chrome\chrome.exe"
                    ParentProcessId = 1000
                }
                [PSCustomObject]@{
                    ProcessId       = 1002
                    Name            = "chrome.exe"
                    CommandLine     = "C:\chrome\chrome.exe --type=renderer --renderer-client-id=5"
                    ExecutablePath  = "C:\chrome\chrome.exe"
                    ParentProcessId = 1000
                }
            )

        It "Returns all processes when no Type filter" {
            Mock Get-CimInstance { $mockProcesses }

            $result = & $ScriptPath -ProcessName "chrome" 2>$null | ConvertFrom-Json
            $result.count | Should Be 3
        }

        It "Filters to only gpu type" {
            Mock Get-CimInstance { $mockProcesses }

            $result = & $ScriptPath -ProcessName "chrome" -Type "gpu" 2>$null | ConvertFrom-Json
            $result.count | Should Be 1
            $result.results[0].pid | Should Be 1001
        }

        It "Exits with error when no processes found" {
            Mock Get-CimInstance { $null }

            $result = & $ScriptPath -ProcessName "nonexistent" 2>&1
            ($LASTEXITCODE -ne 0) | Should Be $true
        }
    }

    Context "JSON output structure" {
        It "Contains count and results fields on success" {
            $mockProcesses = @(
                [PSCustomObject]@{
                    ProcessId       = 100
                    Name            = "chrome.exe"
                    CommandLine     = "chrome.exe"
                    ExecutablePath  = "C:\chrome.exe"
                    ParentProcessId = 1
                }
            )
            Mock Get-CimInstance { $mockProcesses }

            $result = & $ScriptPath 2>$null | ConvertFrom-Json
            ($result.PSObject.Properties.Name -contains "count") | Should Be $true
            ($result.PSObject.Properties.Name -contains "results") | Should Be $true
        }

        It "Each result has pid, type, cmdline, exe, parentPid" {
            $mockProcesses = @(
                [PSCustomObject]@{
                    ProcessId       = 100
                    Name            = "chrome.exe"
                    CommandLine     = "chrome.exe --type=gpu"
                    ExecutablePath  = "C:\chrome.exe"
                    ParentProcessId = 1
                }
            )
            Mock Get-CimInstance { $mockProcesses }

            $result = & $ScriptPath 2>$null | ConvertFrom-Json
            $item = $result.results[0]
            ($item.PSObject.Properties.Name -contains "pid") | Should Be $true
            ($item.PSObject.Properties.Name -contains "type") | Should Be $true
            ($item.PSObject.Properties.Name -contains "cmdline") | Should Be $true
            ($item.PSObject.Properties.Name -contains "exe") | Should Be $true
            ($item.PSObject.Properties.Name -contains "parentPid") | Should Be $true
        }
    }
}
