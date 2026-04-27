Describe "Tool discovery" -Tag "Integration" {

    $SrcRoot = "$PSScriptRoot/../../src"

    Context "Find-CdbExe reports clear errors when tools are missing" {
        $scriptContent = Get-Content "$SrcRoot/vs/windbg-attach.ps1" -Raw
        $funcDef = [regex]::Match($scriptContent, '(?s)function Find-CdbExe \{.*?\n\}').Value
        Invoke-Expression $funcDef

        It "Throws descriptive error mentioning Windows SDK or WinDbg" {
            Mock Get-Command { $null }
            Mock Test-Path { $false }
            Mock Get-ChildItem { @() }

            $err = $null
            try { Find-CdbExe } catch { $err = $_.Exception.Message }
            $err | Should Match "Windows SDK|WinDbg"
        }

        It "Succeeds when cdb.exe is in PATH" {
            Mock Get-Command {
                [PSCustomObject]@{ Source = "C:\tools\cdb.exe" }
            } -ParameterFilter { $Name -eq 'cdb.exe' }

            Find-CdbExe | Should Be "C:\tools\cdb.exe"
        }
    }

    Context "Find-RenderDocCmd reports clear errors when tools are missing" {
        $scriptContent = Get-Content "$SrcRoot/gpu/renderdoc-capture.ps1" -Raw
        $funcDef = [regex]::Match($scriptContent, '(?s)function Find-RenderDocCmd \{.*?\n\}').Value
        Invoke-Expression $funcDef

        It "Throws descriptive error mentioning RenderDoc" {
            Mock Get-Command { $null }
            Mock Test-Path { $false }
            Mock Get-ItemProperty { $null }

            $err = $null
            try { Find-RenderDocCmd } catch { $err = $_.Exception.Message }
            $err | Should Match "renderdoc|RenderDoc"
        }

        It "Succeeds when renderdoccmd.exe is in PATH" {
            Mock Get-Command {
                [PSCustomObject]@{ Source = "C:\tools\renderdoccmd.exe" }
            } -ParameterFilter { $Name -eq 'renderdoccmd.exe' }

            Find-RenderDocCmd | Should Be "C:\tools\renderdoccmd.exe"
        }
    }

    Context "Real tool availability on this machine" {
        It "Reports whether cdb.exe is available" {
            $cdb = Get-Command cdb.exe -ErrorAction SilentlyContinue
            if ($cdb) {
                $cdb.Source | Should Exist
                Write-Host "  cdb.exe found at: $($cdb.Source)"
            } else {
                Write-Host "  SKIPPED: cdb.exe not installed on this machine"
            }
        }

        It "Reports whether renderdoccmd.exe is available" {
            $rdc = Get-Command renderdoccmd.exe -ErrorAction SilentlyContinue
            if ($rdc) {
                $rdc.Source | Should Exist
                Write-Host "  renderdoccmd.exe found at: $($rdc.Source)"
            } else {
                Write-Host "  SKIPPED: renderdoccmd.exe not installed on this machine"
            }
        }
    }
}
