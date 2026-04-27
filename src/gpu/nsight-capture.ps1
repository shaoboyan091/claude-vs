<#
.SYNOPSIS
    Capture GPU frames or traces using NVIDIA Nsight Graphics.
.DESCRIPTION
    Wraps ngfx.exe CLI for frame debugging and GPU trace capture.
    Requires NVIDIA GPU.
.PARAMETER Executable
    Path to executable to capture.
.PARAMETER Activity
    Nsight activity: FrameDebugger or GPUTrace.
.PARAMETER OutputPath
    Path for the capture output.
.PARAMETER Arguments
    Arguments to pass to the executable.
.PARAMETER NgfxPath
    Path to ngfx.exe. Auto-detected if omitted.
.PARAMETER CaptureFrame
    Frame number to capture (default: 1).
.PARAMETER Timeout
    Max seconds to wait (default: 120).
.EXAMPLE
    .\nsight-capture.ps1 -Executable "chrome.exe" -Activity FrameDebugger -OutputPath "C:\tmp\nsight"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Executable,

    [Parameter()]
    [ValidateSet("FrameDebugger", "GPUTrace")]
    [string]$Activity = "FrameDebugger",

    [Parameter()]
    [string]$OutputPath = "",

    [Parameter()]
    [string]$Arguments = "",

    [Parameter()]
    [string]$NgfxPath = "",

    [Parameter()]
    [int]$CaptureFrame = 1,

    [Parameter()]
    [int]$Timeout = 120
)

$ErrorActionPreference = "Stop"

function Find-NgfxExe {
    $inPath = Get-Command ngfx.exe -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }

    # Search NVIDIA Nsight Graphics install dirs
    $baseDirs = @(
        "${env:ProgramFiles}\NVIDIA Corporation\Nsight Graphics*"
        "${env:ProgramFiles(x86)}\NVIDIA Corporation\Nsight Graphics*"
    )

    foreach ($pattern in $baseDirs) {
        $dirs = Get-ChildItem $pattern -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        foreach ($dir in $dirs) {
            $targets = @(
                (Join-Path $dir.FullName "host\windows-desktop-nomad-x64\ngfx.exe")
                (Join-Path $dir.FullName "target\windows-desktop-nomad-x64\ngfx.exe")
                (Join-Path $dir.FullName "ngfx.exe")
            )
            foreach ($t in $targets) {
                if (Test-Path $t) { return $t }
            }
        }
    }

    throw "ngfx.exe not found. Install NVIDIA Nsight Graphics from https://developer.nvidia.com/nsight-graphics"
}

try {
    if (-not $NgfxPath) {
        $NgfxPath = Find-NgfxExe
    }

    if (-not (Test-Path $Executable)) {
        throw "Executable not found: $Executable"
    }

    if (-not $OutputPath) {
        $OutputPath = Join-Path $env:TEMP "nsight_capture_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }

    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    # Map activity to ngfx activity name
    $activityName = switch ($Activity) {
        "FrameDebugger" { "Frame Debugger" }
        "GPUTrace"      { "GPU Trace" }
    }

    $args = @(
        "--activity", "`"$activityName`""
        "--exe", "`"$Executable`""
    )

    if ($Arguments) {
        $args += "--args"
        $args += "`"$Arguments`""
    }

    $args += "--output"
    $args += "`"$OutputPath`""

    $args += "--frame"
    $args += $CaptureFrame.ToString()

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $NgfxPath
    $psi.Arguments = $args -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    Write-Verbose "Running: $NgfxPath $($args -join ' ')"
    $process = [System.Diagnostics.Process]::Start($psi)

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    $exited = $process.WaitForExit($Timeout * 1000)
    if (-not $exited) {
        $process.Kill()
        Write-Warning "ngfx timed out after ${Timeout}s"
    }

    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result

    # Check for output files
    $outputFiles = @()
    if (Test-Path $OutputPath) {
        if ((Get-Item $OutputPath).PSIsContainer) {
            $outputFiles = @(Get-ChildItem $OutputPath -Recurse -File | ForEach-Object { $_.FullName })
        } else {
            $outputFiles = @($OutputPath)
        }
    }

    Write-Output (ConvertTo-Json @{
        success     = ($process.ExitCode -eq 0)
        activity    = $Activity
        executable  = $Executable
        outputPath  = $OutputPath
        outputFiles = $outputFiles
        stdout      = $stdout
        stderr      = $stderr
    } -Depth 3)

} catch {
    Write-Error "Nsight capture failed: $_"
    exit 1
}
