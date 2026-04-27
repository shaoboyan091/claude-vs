Describe "renderdoc-capture.ps1" {

    BeforeAll {
        $ScriptPath = "$PSScriptRoot/../../src/gpu/renderdoc-capture.ps1"
        $scriptContent = Get-Content $ScriptPath -Raw

        $findRdcDef = [regex]::Match($scriptContent, '(?s)function Find-RenderDocCmd \{.*?\n\}').Value
        Invoke-Expression $findRdcDef
    }

    Context "Find-RenderDocCmd searches expected paths" {
        It "Checks PATH via Get-Command" {
            $findRdcDef | Should Match 'Get-Command renderdoccmd\.exe'
        }

        It "Checks Program Files directories" {
            $findRdcDef | Should Match 'ProgramFiles.*RenderDoc\\renderdoccmd\.exe'
        }

        It "Checks registry for install path" {
            $findRdcDef | Should Match 'RenderDoc\.RDCCapture'
        }

        It "Throws when renderdoccmd.exe not found" {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'renderdoccmd.exe' }
            Mock Test-Path { $false }
            Mock Get-ItemProperty { $null }

            { Find-RenderDocCmd } | Should Throw "not found"
        }
    }

    Context "Argument construction for launch-capture mode" {
        It "Uses 'capture' subcommand with -w flag" {
            $scriptContent | Should Match '\$argList = @\("capture", "-w"\)'
        }

        It "Adds --capture-frame when CaptureFrame >= 0" {
            $scriptContent | Should Match '--capture-frame'
        }

        It "Adds --capture-delay when CaptureDelay > 0" {
            $scriptContent | Should Match '--capture-delay'
        }

        It "Uses -c for output path and -e for executable" {
            $scriptContent | Should Match '\$argList \+= "-c"'
            $scriptContent | Should Match '\$argList \+= "-e"'
        }

        It "Passes extra arguments after -- separator" {
            $scriptContent | Should Match '\$argList \+= "--"'
        }
    }

    Context "Argument construction for inject mode" {
        It "Uses 'inject' subcommand with --PID flag" {
            $scriptContent | Should Match '"inject", "--PID=\$ProcessId"'
        }
    }

    Context "Argument construction for replay mode" {
        It "Uses 'replay' subcommand" {
            $scriptContent | Should Match '"replay"'
        }

        It "Supports --export-textures option" {
            $scriptContent | Should Match '--export-textures'
        }

        It "Verifies capture file exists before replay" {
            $scriptContent | Should Match 'if \(-not \(Test-Path \$Replay\)\)'
        }
    }

    Context "Output path auto-generation when omitted" {
        It "Generates temp path with timestamp pattern" {
            $scriptContent | Should Match 'renderdoc_capture_.*yyyyMMdd_HHmmss.*\.rdc'
        }

        It "Uses TEMP environment variable" {
            $scriptContent | Should Match '\$env:TEMP'
        }

        It "Creates output directory if it does not exist" {
            $scriptContent | Should Match 'New-Item -ItemType Directory -Path \$outDir -Force'
        }
    }

    Context "Parameter sets" {
        It "Has Launch, Inject, and Replay parameter sets" {
            $cmd = Get-Command $ScriptPath
            ($cmd.ParameterSets.Name -contains "Launch") | Should Be $true
            ($cmd.ParameterSets.Name -contains "Inject") | Should Be $true
            ($cmd.ParameterSets.Name -contains "Replay") | Should Be $true
        }
    }
}
