<#
.SYNOPSIS
    Attach WinDbg/cdb to a process for automated debugging.
.DESCRIPTION
    Wraps cdb.exe (console WinDbg) for headless debug sessions.
    Supports command files, child process debugging, and log output.
.PARAMETER Pid
    Process ID to attach to.
.PARAMETER CommandFile
    Path to a cdb command script to execute after attach.
.PARAMETER Commands
    Inline cdb commands (semicolon-separated). Alternative to CommandFile.
.PARAMETER ChildProcesses
    If set, uses -o flag to debug child processes too.
.PARAMETER OutputLog
    Path to write cdb session log.
.PARAMETER CdbPath
    Path to cdb.exe. Auto-detected from Windows SDK or WinDbg install if omitted.
.PARAMETER Timeout
    Max seconds to wait for cdb session (default: 60).
.EXAMPLE
    .\windbg-attach.ps1 -Pid 1234 -Commands "k;~*k;.detach;q"
    .\windbg-attach.ps1 -Pid 1234 -CommandFile "C:\scripts\dump-stacks.txt" -OutputLog "C:\tmp\debug.log"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [int]$ProcessId,

    [Parameter()]
    [string]$CommandFile = "",

    [Parameter()]
    [string]$Commands = "",

    [Parameter()]
    [switch]$ChildProcesses,

    [Parameter()]
    [string]$OutputLog = "",

    [Parameter()]
    [string]$CdbPath = "",

    [Parameter()]
    [int]$Timeout = 60
)

$ErrorActionPreference = "Stop"

function Find-CdbExe {
    # Check common install locations
    $candidates = @(
        # Windows SDK
        "${env:ProgramFiles(x86)}\Windows Kits\10\Debuggers\x64\cdb.exe"
        "${env:ProgramFiles}\Windows Kits\10\Debuggers\x64\cdb.exe"
        # WinDbg Preview (Store app)
        "${env:LOCALAPPDATA}\Microsoft\WindowsApps\cdb.exe"
    )

    # Also check PATH
    $inPath = Get-Command cdb.exe -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }

    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }

    # Search in WinDbg install dirs
    $windbgDirs = Get-ChildItem "${env:LOCALAPPDATA}\Microsoft\WinDbg*" -Directory -ErrorAction SilentlyContinue
    foreach ($dir in $windbgDirs) {
        $exe = Join-Path $dir.FullName "cdb.exe"
        if (Test-Path $exe) { return $exe }
    }

    throw "cdb.exe not found. Install Windows SDK or WinDbg Preview."
}

try {
    if (-not $CdbPath) {
        $CdbPath = Find-CdbExe
    }
    if (-not (Test-Path $CdbPath)) {
        throw "cdb.exe not found at: $CdbPath"
    }

    # Verify target process exists
    $proc = Get-Process -Id $ProcessId -ErrorAction Stop

    # Build argument list
    $args = @()
    $args += "-p"
    $args += $ProcessId.ToString()

    if ($ChildProcesses) {
        $args += "-o"
    }

    if ($OutputLog) {
        $logDir = Split-Path -Parent $OutputLog
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $args += "-loga"
        $args += $OutputLog
    }

    # Build commands to execute
    $cmdString = ""
    if ($CommandFile) {
        if (-not (Test-Path $CommandFile)) {
            throw "Command file not found: $CommandFile"
        }
        $cmdString = "`$`<$CommandFile;.detach;q"
    } elseif ($Commands) {
        $cmdString = "$Commands"
        # Ensure session ends cleanly
        if ($cmdString -notmatch '\.detach' -and $cmdString -notmatch '\bq\b') {
            $cmdString += ";.detach;q"
        }
    } else {
        # Default: dump all thread stacks, detach, quit
        $cmdString = "~*k;.detach;q"
    }

    $args += "-c"
    $args += "`"$cmdString`""

    Write-Verbose "Running: $CdbPath $($args -join ' ')"

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $CdbPath
    $psi.Arguments = $args -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($psi)

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    $exited = $process.WaitForExit($Timeout * 1000)
    if (-not $exited) {
        $process.Kill()
        throw "cdb session timed out after ${Timeout}s"
    }

    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result

    $output = @{
        success    = ($process.ExitCode -eq 0)
        exitCode   = $process.ExitCode
        pid        = $ProcessId
        processName = $proc.ProcessName
        stdout     = $stdout
        stderr     = $stderr
        cdbPath    = $CdbPath
    }

    if ($OutputLog) {
        $output.logFile = $OutputLog
    }

    Write-Output (ConvertTo-Json $output -Depth 3)

} catch {
    Write-Error "WinDbg attach failed: $_"
    exit 1
}
