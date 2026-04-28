<#
.SYNOPSIS
    Launch Chromium with debug flags and attach a debugger to target process.
.DESCRIPTION
    Launches Chrome with --gpu-startup-dialog or --renderer-startup-dialog,
    waits for the dialog, discovers the target PID, and attaches WinDbg or VS.
.PARAMETER ChromePath
    Path to chrome.exe. Default: C:\work\cr\src\out\Default\chrome.exe.
.PARAMETER Target
    Which process type to debug: gpu, renderer, or browser.
.PARAMETER Debugger
    Which debugger to use: windbg (default, automated) or vs (interactive).
.PARAMETER Url
    URL to open in Chrome.
.PARAMETER ExtraArgs
    Additional Chrome command-line flags.
.PARAMETER CdbCommands
    WinDbg commands to run after attach (only for windbg debugger).
.PARAMETER OutputLog
    Path for WinDbg log output.
.EXAMPLE
    .\chromium-debug.ps1 -Target gpu -Debugger windbg -CdbCommands "k;.detach;q"
    .\chromium-debug.ps1 -Target renderer -Debugger vs -Url "https://webglsamples.org"
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$ChromePath = "C:\work\cr\src\out\Default\chrome.exe",

    [Parameter(Mandatory)]
    [ValidateSet("gpu", "renderer", "browser")]
    [string]$Target,

    [Parameter()]
    [ValidateSet("windbg", "vs")]
    [string]$Debugger = "windbg",

    [Parameter()]
    [string]$Url = "about:blank",

    [Parameter()]
    [string[]]$ExtraArgs = @(),

    [Parameter()]
    [string]$CdbCommands = "",

    [Parameter()]
    [string]$OutputLog = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Wait-ForChromeProcess {
    param([string]$ProcessType, [int]$TimeoutSeconds = 30)

    $findProcess = Join-Path $ScriptDir "..\util\find-process.ps1"

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $result = & $findProcess -ProcessName chrome -Type $ProcessType 2>$null
            if ($result) {
                $parsed = $result | ConvertFrom-Json
                if ($parsed.count -gt 0) {
                    return $parsed.results[0]
                }
            }
        } catch {
            # Process not yet available
        }
        Start-Sleep -Milliseconds 500
    }
    throw "Timed out waiting for Chrome '$ProcessType' process"
}

$debugSuccess = $false
try {
    if (-not (Test-Path $ChromePath)) {
        throw "Chrome not found at: $ChromePath"
    }

    # Build Chrome launch arguments
    $chromeArgs = @($Url)

    switch ($Target) {
        "gpu" {
            $chromeArgs += "--gpu-startup-dialog"
            # Warn about sandbox when targeting GPU process
            $allArgs = $ExtraArgs -join ' '
            if ($allArgs -notmatch 'disable-gpu-sandbox') {
                Write-Warning "Targeting GPU process: consider adding --disable-gpu-sandbox via -ExtraArgs if debugger attach fails"
            }
        }
        "renderer" {
            $chromeArgs += "--renderer-startup-dialog"
        }
        "browser" {
            # Browser process is the main process, no special flag needed
            # We'll just launch and grab the main PID
        }
    }

    $chromeArgs += $ExtraArgs

    Write-Verbose "Launching: $ChromePath $($chromeArgs -join ' ')"
    $chromeProc = Start-Process -FilePath $ChromePath -ArgumentList $chromeArgs -PassThru

    if ($Target -eq "browser") {
        $targetPid = $chromeProc.Id
        Write-Verbose "Browser PID: $targetPid"
    } else {
        Write-Host "Waiting for Chrome $Target process (dialog will appear)..."
        Write-Host "The startup dialog shows the PID. The script will auto-detect it."
        $targetProcess = Wait-ForChromeProcess -ProcessType $Target -TimeoutSeconds 30
        $targetPid = $targetProcess.pid
        Write-Verbose "$Target process PID: $targetPid"
    }

    # Attach debugger
    $attachResult = $null
    switch ($Debugger) {
        "windbg" {
            $attachArgs = @{
                ProcessId = $targetPid
            }
            if ($CdbCommands) { $attachArgs.Commands = $CdbCommands }
            if ($OutputLog) { $attachArgs.OutputLog = $OutputLog }

            $windbgScript = Join-Path $ScriptDir "windbg-attach.ps1"
            $attachResult = & $windbgScript @attachArgs
        }
        "vs" {
            $vsScript = Join-Path $ScriptDir "vs-attach.ps1"
            $attachResult = & $vsScript -ProcessId $targetPid
        }
    }

    $debugSuccess = $true

    if ($attachResult) {
        $attachResult = $attachResult | ConvertFrom-Json
    }

    Write-Output (ConvertTo-Json @{
        success       = $true
        chromePid     = $chromeProc.Id
        targetPid     = $targetPid
        targetType    = $Target
        debugger      = $Debugger
        debuggerResult = $attachResult
    } -Depth 4)

} catch {
    Write-Error "Chromium debug failed: $_"
    exit 1
} finally {
    # Only kill Chrome if the debugger failed to attach;
    # on success the user wants Chrome to keep running
    if (-not $debugSuccess -and $chromeProc -and -not $chromeProc.HasExited) {
        try { $chromeProc.Kill() } catch { }
    }
}
