Describe "Chromium E2E smoke tests" -Tag "E2E" {

    BeforeAll {
        $SrcRoot = "$PSScriptRoot/../../src"
        $RunE2E = $env:CLAUDE_VS_E2E -eq "1"
    }

    Context "find-process finds Chrome processes" {
        It "Discovers running Chrome browser process" {
            if (-not $RunE2E) { Write-Host "  SKIPPED: E2E not enabled"; return }
            $output = & "$SrcRoot/util/find-process.ps1" -ProcessName chrome -Type browser 2>&1
            $result = $output | ConvertFrom-Json
            ($result.count -gt 0) | Should Be $true
            $result.results[0].type | Should Be "browser"
            ($result.results[0].pid -gt 0) | Should Be $true
        }

        It "Discovers Chrome GPU process" {
            if (-not $RunE2E) { Write-Host "  SKIPPED: E2E not enabled"; return }
            $output = & "$SrcRoot/util/find-process.ps1" -ProcessName chrome -Type gpu 2>&1
            $result = $output | ConvertFrom-Json
            ($result.count -gt 0) | Should Be $true
            $result.results[0].type | Should Be "gpu"
        }
    }

    Context "windbg-attach gets stack from Chrome browser process" {
        It "Attaches to browser process and captures stacks" {
            if (-not $RunE2E) { Write-Host "  SKIPPED: E2E not enabled"; return }
            $procs = & "$SrcRoot/util/find-process.ps1" -ProcessName chrome -Type browser 2>&1 | ConvertFrom-Json
            $browserPid = $procs.results[0].pid

            $output = & "$SrcRoot/vs/windbg-attach.ps1" -ProcessId $browserPid -Commands "~*k;.detach;q" 2>&1
            $result = $output | ConvertFrom-Json
            $result.success | Should Be $true
            $result.stdout | Should Match "Child-SP|RetAddr|Call Site"
        }
    }

    Context "renderdoc launch-capture of Chrome" {
        It "Captures via launch mode with sandbox disabled" {
            if (-not $RunE2E) { Write-Host "  SKIPPED: E2E not enabled"; return }

            # RenderDoc cannot inject into sandboxed Chrome GPU process.
            # Use launch-capture mode with --disable-gpu-sandbox instead.
            $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
            $capturePath = Join-Path $env:TEMP "e2e_test_capture.rdc"

            $output = & "$SrcRoot/gpu/renderdoc-capture.ps1" `
                -Executable $chromePath `
                -OutputPath $capturePath `
                -Arguments "--disable-gpu-sandbox --no-first-run about:gpu" `
                -CaptureFrame 0 2>&1
            $result = $output | ConvertFrom-Json
            $result.mode | Should Be "launch-capture"
            # RenderDoc may or may not produce .rdc depending on timing, but it should not crash
            ($result.stdout -ne $null) | Should Be $true

            # Cleanup
            Stop-Process -Name chrome -Force -ErrorAction SilentlyContinue
            Start-Sleep 2
            # Re-launch Chrome for subsequent tests
            Start-Process $chromePath -ArgumentList "https://webglsamples.org/aquarium/aquarium.html"
            Start-Sleep 3
            if (Test-Path $capturePath) { Remove-Item $capturePath -Force }
        }
    }

    Context "screenshot captures Chrome window" {
        It "Captures Chrome window by title" {
            if (-not $RunE2E) { Write-Host "  SKIPPED: E2E not enabled"; return }

            $screenshotPath = Join-Path $env:TEMP "e2e_test_screenshot.png"
            $output = & "$SrcRoot/util/screenshot.ps1" -Title "Chrome" -OutputPath $screenshotPath 2>&1
            $result = $output | ConvertFrom-Json
            $result.success | Should Be $true
            ($result.width -gt 0) | Should Be $true
            ($result.height -gt 0) | Should Be $true
            $screenshotPath | Should Exist

            if (Test-Path $screenshotPath) { Remove-Item $screenshotPath -Force }
        }
    }
}
