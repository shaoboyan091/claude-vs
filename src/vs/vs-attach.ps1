<#
.SYNOPSIS
    Attach Visual Studio debugger to a running process.
.DESCRIPTION
    Uses vsjitdebugger.exe or devenv.exe for interactive debugging.
    This is for interactive use only - VS has no headless debug CLI.
.PARAMETER Pid
    Process ID to attach to.
.PARAMETER Executable
    Launch executable under debugger (uses devenv /debugexe).
.PARAMETER Arguments
    Arguments for the executable when using -Executable.
.PARAMETER VsVersion
    VS version preference: "2022", "2019", or "auto" (default: auto).
.EXAMPLE
    .\vs-attach.ps1 -Pid 1234
    .\vs-attach.ps1 -Executable "C:\work\cr\src\out\Default\chrome.exe" -Arguments "--no-sandbox"
#>
[CmdletBinding()]
param(
    [Parameter(ParameterSetName = "Attach")]
    [int]$ProcessId = 0,

    [Parameter(ParameterSetName = "Launch")]
    [string]$Executable = "",

    [Parameter(ParameterSetName = "Launch")]
    [string]$Arguments = "",

    [Parameter()]
    [ValidateSet("2022", "2019", "auto")]
    [string]$VsVersion = "auto"
)

$ErrorActionPreference = "Stop"

function Find-DevEnv {
    param([string]$Version)

    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vsWhere)) {
        throw "vswhere.exe not found. Is Visual Studio installed?"
    }

    $vsWhereArgs = @("-latest", "-property", "installationPath")
    if ($Version -ne "auto") {
        $versionRange = switch ($Version) {
            "2022" { "[17.0,18.0)" }
            "2019" { "[16.0,17.0)" }
        }
        $vsWhereArgs += "-version"
        $vsWhereArgs += $versionRange
    }

    $installPath = & $vsWhere @vsWhereArgs 2>$null | Select-Object -First 1
    if (-not $installPath) {
        throw "Visual Studio $Version not found"
    }

    $devenv = Join-Path $installPath "Common7\IDE\devenv.exe"
    if (-not (Test-Path $devenv)) {
        throw "devenv.exe not found at: $devenv"
    }

    return $devenv
}

function Find-JitDebugger {
    $jit = Get-Command vsjitdebugger.exe -ErrorAction SilentlyContinue
    if ($jit) { return $jit.Source }

    $candidates = @(
        "${env:ProgramFiles}\Common Files\Microsoft Shared\VS7Debug\vsjitdebugger.exe"
        "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\VS7Debug\vsjitdebugger.exe"
    )

    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }

    return $null
}

try {
    if ($ProcessId -gt 0) {
        # Attach mode - prefer vsjitdebugger for quick attach
        $proc = Get-Process -Id $ProcessId -ErrorAction Stop

        $jitDbg = Find-JitDebugger
        if ($jitDbg) {
            Write-Verbose "Using vsjitdebugger: $jitDbg"
            Start-Process -FilePath $jitDbg -ArgumentList "-p $ProcessId"
            Write-Output (ConvertTo-Json @{
                success = $true
                method  = "vsjitdebugger"
                pid     = $ProcessId
                processName = $proc.ProcessName
                note    = "VS JIT Debugger launched. Select debugger instance in dialog."
            })
        } else {
            # Fallback: open devenv and use automation
            $devenv = Find-DevEnv -Version $VsVersion
            Write-Warning "vsjitdebugger not found, launching devenv (manual attach required)"
            Start-Process -FilePath $devenv
            Write-Output (ConvertTo-Json @{
                success = $true
                method  = "devenv-manual"
                pid     = $ProcessId
                note    = "Launched VS. Manually attach via Debug > Attach to Process (Ctrl+Alt+P) to PID $ProcessId"
            })
        }
    }
    elseif ($Executable) {
        if (-not (Test-Path $Executable)) {
            throw "Executable not found: $Executable"
        }

        $devenv = Find-DevEnv -Version $VsVersion
        $devenvArgs = "/debugexe `"$Executable`""
        if ($Arguments) {
            $devenvArgs += " $Arguments"
        }

        Write-Verbose "Running: $devenv $devenvArgs"
        Start-Process -FilePath $devenv -ArgumentList $devenvArgs

        Write-Output (ConvertTo-Json @{
            success    = $true
            method     = "devenv-debugexe"
            executable = $Executable
            arguments  = $Arguments
            note       = "VS launched with debugger. Press F5 to start."
        })
    }
    else {
        throw "Must specify either -Pid or -Executable"
    }

} catch {
    Write-Error "VS attach failed: $_"
    exit 1
}
