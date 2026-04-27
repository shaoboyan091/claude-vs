<#
.SYNOPSIS
    Capture GPU frames using RenderDoc CLI.
.DESCRIPTION
    Wraps renderdoccmd for capture, injection into running processes, and replay.
    RenderDoc supports any GPU vendor and has MIT license.
.PARAMETER Executable
    Path to executable to launch and capture.
.PARAMETER Pid
    PID of running process to inject into (alternative to Executable).
.PARAMETER OutputPath
    Path for the .rdc capture file.
.PARAMETER CaptureFrame
    Frame number to capture (default: capture on F12 key or first frame).
.PARAMETER CaptureDelay
    Seconds to wait before capturing (used with -CaptureFrame).
.PARAMETER Arguments
    Arguments to pass to the executable.
.PARAMETER Replay
    Path to .rdc file to replay (analysis mode).
.PARAMETER ExportTextures
    Export all textures from a replay to a directory.
.PARAMETER RenderDocPath
    Path to renderdoccmd.exe. Auto-detected if omitted.
.EXAMPLE
    .\renderdoc-capture.ps1 -Executable "chrome.exe" -OutputPath "C:\tmp\cap.rdc" -Arguments "--no-sandbox"
    .\renderdoc-capture.ps1 -Pid 5678 -OutputPath "C:\tmp\inject.rdc"
    .\renderdoc-capture.ps1 -Replay "C:\tmp\cap.rdc"
#>
[CmdletBinding()]
param(
    [Parameter(ParameterSetName = "Launch")]
    [string]$Executable = "",

    [Parameter(ParameterSetName = "Inject")]
    [int]$ProcessId = 0,

    [Parameter(ParameterSetName = "Replay")]
    [string]$Replay = "",

    [Parameter()]
    [string]$OutputPath = "",

    [Parameter()]
    [int]$CaptureFrame = -1,

    [Parameter()]
    [int]$CaptureDelay = 0,

    [Parameter()]
    [string]$Arguments = "",

    [Parameter()]
    [string]$ExportTextures = "",

    [Parameter()]
    [string]$RenderDocPath = "",

    [Parameter()]
    [int]$Timeout = 120
)

$ErrorActionPreference = "Stop"

function Find-RenderDocCmd {
    $inPath = Get-Command renderdoccmd.exe -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }

    $candidates = @(
        "${env:ProgramFiles}\RenderDoc\renderdoccmd.exe"
        "${env:ProgramFiles(x86)}\RenderDoc\renderdoccmd.exe"
    )

    # Check registry for install path
    $regPaths = @(
        "HKLM:\SOFTWARE\Classes\RenderDoc.RDCCapture.1\DefaultIcon"
    )
    foreach ($rp in $regPaths) {
        try {
            $val = (Get-ItemProperty $rp -ErrorAction SilentlyContinue).'(Default)'
            if ($val -match '(.+)\\[^\\]+$') {
                $dir = $Matches[1]
                $exe = Join-Path $dir "renderdoccmd.exe"
                if (Test-Path $exe) { return $exe }
            }
        } catch {}
    }

    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }

    throw "renderdoccmd.exe not found. Install RenderDoc from https://renderdoc.org/"
}

function Invoke-RenderDocCmd {
    param([string]$ExePath, [string[]]$ArgList, [int]$TimeoutSec)

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ExePath
    $psi.Arguments = $ArgList -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    Write-Verbose "Running: $ExePath $($ArgList -join ' ')"
    $process = [System.Diagnostics.Process]::Start($psi)

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    $exited = $process.WaitForExit($TimeoutSec * 1000)
    if (-not $exited) {
        $process.Kill()
        throw "renderdoccmd timed out after ${TimeoutSec}s"
    }

    return @{
        exitCode = $process.ExitCode
        stdout   = $stdoutTask.Result
        stderr   = $stderrTask.Result
    }
}

try {
    if (-not $RenderDocPath) {
        $RenderDocPath = Find-RenderDocCmd
    }

    # Replay mode
    if ($Replay) {
        if (-not (Test-Path $Replay)) {
            throw "Capture file not found: $Replay"
        }

        if ($ExportTextures) {
            if (-not (Test-Path $ExportTextures)) {
                New-Item -ItemType Directory -Path $ExportTextures -Force | Out-Null
            }
            $result = Invoke-RenderDocCmd -ExePath $RenderDocPath -ArgList @(
                "replay", "`"$Replay`"", "--export-textures", "`"$ExportTextures`""
            ) -TimeoutSec $Timeout
        } else {
            $result = Invoke-RenderDocCmd -ExePath $RenderDocPath -ArgList @(
                "replay", "`"$Replay`""
            ) -TimeoutSec $Timeout
        }

        Write-Output (ConvertTo-Json @{
            success  = ($result.exitCode -eq 0)
            mode     = "replay"
            capture  = $Replay
            stdout   = $result.stdout
            stderr   = $result.stderr
        })
        exit $(if ($result.exitCode -eq 0) { 0 } else { 1 })
    }

    # Capture mode - need OutputPath
    if (-not $OutputPath) {
        $OutputPath = Join-Path $env:TEMP "renderdoc_capture_$(Get-Date -Format 'yyyyMMdd_HHmmss').rdc"
    }

    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    if ($Executable) {
        # Launch-and-capture mode
        if (-not (Test-Path $Executable)) {
            throw "Executable not found: $Executable"
        }

        # Chrome requires sandbox disabled for DLL injection capture
        if ($Executable -match 'chrome' -and $Arguments -notmatch 'disable-gpu-sandbox') {
            Write-Warning "Chrome detected: auto-adding --disable-gpu-sandbox --disable-gpu-watchdog for RenderDoc capture"
            $Arguments = "$Arguments --disable-gpu-sandbox --disable-gpu-watchdog".Trim()
        }

        $argList = @("capture", "-w")

        $argList += "-c"
        $argList += "`"$OutputPath`""

        if ($CaptureDelay -gt 0) {
            $argList += "--opt-delay-for-debugger"
            $argList += $CaptureDelay.ToString()
        }

        # Executable is a positional arg (not -e), must come after all options
        $argList += "`"$Executable`""

        if ($Arguments) {
            $argList += $Arguments
        }

        $result = Invoke-RenderDocCmd -ExePath $RenderDocPath -ArgList $argList -TimeoutSec $Timeout

        Write-Output (ConvertTo-Json @{
            success    = ($result.exitCode -eq 0)
            mode       = "launch-capture"
            executable = $Executable
            outputPath = $OutputPath
            stdout     = $result.stdout
            stderr     = $result.stderr
        })
    }
    elseif ($ProcessId -gt 0) {
        # Inject into running process
        $proc = Get-Process -Id $ProcessId -ErrorAction Stop

        $argList = @("inject", "--PID=$ProcessId")

        $result = Invoke-RenderDocCmd -ExePath $RenderDocPath -ArgList $argList -TimeoutSec $Timeout

        Write-Output (ConvertTo-Json @{
            success     = ($result.exitCode -eq 0)
            mode        = "inject"
            pid         = $ProcessId
            processName = $proc.ProcessName
            outputPath  = $OutputPath
            stdout      = $result.stdout
            stderr      = $result.stderr
        })
    }
    else {
        throw "Must specify -Executable, -Pid, or -Replay"
    }

} catch {
    Write-Error "RenderDoc operation failed: $_"
    exit 1
}
