Describe "Dawn single-process E2E smoke tests" -Tag "E2E" {

    $SrcRoot = "$PSScriptRoot/../../src"
    $RunE2E = $env:CLAUDE_VS_E2E -eq "1"

    Context "windbg-attach launch mode with Dawn test binary" {
        It "Launches a test executable and captures stacks" {
            if (-not $RunE2E) { Write-Host "  SKIPPED: E2E not enabled"; return }

            $dawnExe = $env:DAWN_TEST_EXE
            if (-not $dawnExe -or -not (Test-Path $dawnExe)) {
                Write-Host "  SKIPPED: DAWN_TEST_EXE not set or not found"
                return
            }

            $output = & "$SrcRoot/vs/windbg-attach.ps1" `
                -Executable $dawnExe `
                -Arguments "--gtest_filter=BufferTests.MapRead_ZeroSized --gtest_print_time=0" `
                -Commands "~*k;q" 2>&1
            $result = $output | ConvertFrom-Json
            $result.success | Should Be $true
            $result.mode | Should Be "launch"
            $result.stdout | Should Not BeNullOrEmpty
        }
    }

    Context "windbg-break launch mode with breakpoint on main" {
        It "Sets breakpoint on main and captures hit data" {
            if (-not $RunE2E) { Write-Host "  SKIPPED: E2E not enabled"; return }

            $dawnExe = $env:DAWN_TEST_EXE
            if (-not $dawnExe -or -not (Test-Path $dawnExe)) {
                Write-Host "  SKIPPED: DAWN_TEST_EXE not set or not found"
                return
            }

            $output = & "$SrcRoot/vs/windbg-break.ps1" `
                -Executable $dawnExe `
                -Arguments "--gtest_filter=BufferTests.MapRead_ZeroSized --gtest_print_time=0" `
                -Breakpoints "main" `
                -OnHit full `
                -BreakOnEntry `
                -Timeout 60 2>&1
            $result = $output | ConvertFrom-Json
            $result.success | Should Be $true
            $result.mode | Should Be "launch"
            $result.breakpoints | Should Not BeNullOrEmpty
            $result.breakpoints[0].location | Should Be "main"
            ($result.breakpoints[0].hitCount -ge 1) | Should Be $true
            $result.breakpoints[0].hits[0].stack | Should Not BeNullOrEmpty
        }
    }
}
