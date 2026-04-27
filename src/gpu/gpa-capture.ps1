<#
.SYNOPSIS
    Capture GPU frames using Intel GPA.
.DESCRIPTION
    Wraps gpa-injector.exe for D3D11/D3D12 frame capture.
    Supports Chromium with special flags for D3D11on12 and Dawn.
.PARAMETER Executable
    Path to executable to capture.
.PARAMETER Api
    Graphics API target: d3d11, d3d12, or vulkan.
.PARAMETER OutputDir
    Directory for capture output.
.PARAMETER ChromeArgs
    Additional Chrome arguments (auto-adds necessary flags for each API).
.PARAMETER GpaPath
    Path to gpa-injector.exe. Auto-detected if omitted.
.PARAMETER Duration
    Capture duration in seconds (default: 10).
.EXAMPLE
    .\gpa-capture.ps1 -Executable "chrome.exe" -Api d3d12 -OutputDir "C:\tmp\gpa"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Executable,

    [Parameter()]
    [ValidateSet("d3d11", "d3d12", "vulkan")]
    [string]$Api = "d3d11",

    [Parameter()]
    [string]$OutputDir = "",

    [Parameter()]
    [string]$ChromeArgs = "",

    [Parameter()]
    [string]$GpaPath = "",

    [Parameter()]
    [int]$Duration = 10
)

$ErrorActionPreference = "Stop"

function Find-GpaInjector {
    $inPath = Get-Command gpa-injector.exe -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }

    $candidates = @(
        "${env:ProgramFiles}\Intel\GPA\bin\gpa-injector.exe"
        "${env:ProgramFiles(x86)}\Intel\GPA\bin\gpa-injector.exe"
        "${env:ProgramFiles}\Intel\Graphics Performance Analyzers\bin\gpa-injector.exe"
    )

    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }

    throw "gpa-injector.exe not found. Install Intel GPA from https://www.intel.com/content/www/us/en/developer/tools/graphics-performance-analyzers/overview.html"
}

try {
    if (-not $GpaPath) {
        $GpaPath = Find-GpaInjector
    }

    if (-not (Test-Path $Executable)) {
        throw "Executable not found: $Executable"
    }

    if (-not $OutputDir) {
        $OutputDir = Join-Path $env:TEMP "gpa_capture_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    # Build arguments
    $args = @(
        "--injection-mode", "1"
        "-t", "`"$Executable`""
        "-L", "capture"
        "--output-dir", "`"$OutputDir`""
    )

    # API-specific flags
    $extraChromeArgs = $ChromeArgs
    # Chrome requires sandbox disabled for DLL injection capture
    if ($Executable -match 'chrome' -and $extraChromeArgs -notmatch 'disable-gpu-sandbox') {
        Write-Warning "Chrome detected: auto-adding --disable-gpu-sandbox --disable-gpu-watchdog for GPA capture"
        $extraChromeArgs += " --disable-gpu-sandbox --disable-gpu-watchdog"
    }
    switch ($Api) {
        "d3d12" {
            $args += "--hook-d3d11on12"
            # For Chromium WebGPU: enable Dawn D3D12 backend
            if ($Executable -match 'chrome') {
                $extraChromeArgs += " --enable-unsafe-webgpu --use-angle=d3d11"
            }
        }
        "vulkan" {
            $args += "--hook-vulkan"
            if ($Executable -match 'chrome') {
                $extraChromeArgs += " --use-vulkan --enable-features=Vulkan"
            }
        }
    }

    if ($extraChromeArgs.Trim()) {
        $args += "--"
        $args += $extraChromeArgs.Trim()
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $GpaPath
    $psi.Arguments = $args -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    Write-Verbose "Running: $GpaPath $($args -join ' ')"
    $process = [System.Diagnostics.Process]::Start($psi)

    # Let it capture for Duration seconds, then signal stop
    Start-Sleep -Seconds $Duration

    if (-not $process.HasExited) {
        $process.Kill()
    }

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()

    # Find capture files
    $captures = Get-ChildItem $OutputDir -Recurse -File -ErrorAction SilentlyContinue

    Write-Output (ConvertTo-Json @{
        success    = $true
        api        = $Api
        executable = $Executable
        outputDir  = $OutputDir
        captures   = @($captures | ForEach-Object { $_.FullName })
        stdout     = $stdout
        stderr     = $stderr
    } -Depth 3)

} catch {
    Write-Error "GPA capture failed: $_"
    exit 1
}
