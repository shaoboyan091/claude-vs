Describe "screenshot.ps1" {

    BeforeAll {
        $ScriptPath = "$PSScriptRoot/../../src/util/screenshot.ps1"
        $scriptContent = Get-Content $ScriptPath -Raw
    }

    Context "Parameter set validation" {
        BeforeAll {
            $cmd = Get-Command $ScriptPath
        }

        It "Has ByPid parameter set with Pid parameter" {
            ($cmd.ParameterSets.Name -contains "ByPid") | Should Be $true
            $pidParam = $cmd.Parameters['ProcessId']
            $pidParam | Should Not BeNullOrEmpty
        }

        It "Has ByTitle parameter set with Title parameter" {
            ($cmd.ParameterSets.Name -contains "ByTitle") | Should Be $true
            $titleParam = $cmd.Parameters['Title']
            $titleParam | Should Not BeNullOrEmpty
        }

        It "Has FullScreen parameter set" {
            ($cmd.ParameterSets.Name -contains "FullScreen") | Should Be $true
            $fsParam = $cmd.Parameters['FullScreen']
            $fsParam.SwitchParameter | Should Be $true
        }

        It "OutputPath is mandatory" {
            $cmd.Parameters['OutputPath'].Attributes.Where({ $_.Mandatory }) | Should Not BeNullOrEmpty
        }

        It "Pid and Title are mutually exclusive" {
            $pidSets = $cmd.Parameters['ProcessId'].ParameterSets.Keys
            $titleSets = $cmd.Parameters['Title'].ParameterSets.Keys
            $pidSets | Should Not Contain "ByTitle"
            $titleSets | Should Not Contain "ByPid"
        }
    }

    Context "Output directory creation" {
        It "Creates output directory if it does not exist" {
            $scriptContent | Should Match 'New-Item -ItemType Directory -Path \$outDir -Force'
        }

        It "Checks directory existence before creating" {
            $scriptContent | Should Match 'if \(\$outDir -and -not \(Test-Path \$outDir\)\)'
        }
    }

    Context "Window capture logic" {
        It "Uses PrintWindow API with PW_RENDERFULLCONTENT flag" {
            $scriptContent | Should Match 'PrintWindow\(\$hwnd, \$hdc, 0x2\)'
        }

        It "Validates window dimensions are positive" {
            $scriptContent | Should Match 'if \(\$width -le 0 -or \$height -le 0\)'
        }

        It "Saves as PNG format" {
            $scriptContent | Should Match 'ImageFormat\]::Png'
        }
    }

    Context "JSON output structure" {
        It "Returns success, path, width, height, and method fields" {
            $scriptContent | Should Match 'success\s*='
            $scriptContent | Should Match 'path\s*='
            $scriptContent | Should Match 'width\s*='
            $scriptContent | Should Match 'height\s*='
            $scriptContent | Should Match 'method\s*='
        }
    }
}
