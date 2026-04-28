<#
.SYNOPSIS
    Attach WinDbg/cdb to a running process, or launch an executable under the debugger.
.DESCRIPTION
    Wraps cdb.exe (console WinDbg) for headless debug sessions.
    Two modes:
      Attach mode: -ProcessId <pid> attaches to an existing process.
      Launch mode:  -Executable <path> starts the program under the debugger.
    Launch mode solves the race condition where short-lived processes (tests)
    exit before a separate attach can reach them.
.PARAMETER ProcessId
    Process ID to attach to (attach mode).
.PARAMETER Executable
    Path to executable to launch under the debugger (launch mode).
.PARAMETER Arguments
    Arguments to pass to the executable (launch mode only).
.PARAMETER WorkingDirectory
    Working directory for the launched process (launch mode only).
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
    .\windbg-attach.ps1 -ProcessId 1234 -Commands "k;~*k;.detach;q"
    .\windbg-attach.ps1 -Executable "C:\tests\my_test.exe" -Arguments "--gtest_filter=Foo*" -Commands "~*k;q"
    .\windbg-attach.ps1 -Executable "C:\dawn\out\Debug\dawn_end2end_tests.exe" -WorkingDirectory "C:\dawn\out\Debug" -Arguments "--gtest_filter=BufferTests.*"
#>
[CmdletBinding()]
param(
    [Parameter()]
    [int]$ProcessId = 0,

    [Parameter()]
    [string]$Executable = "",

    [Parameter()]
    [string]$Arguments = "",

    [Parameter()]
    [string]$WorkingDirectory = "",

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

    # Determine mode: launch or attach
    $launchMode = $false
    if ($Executable) {
        if (-not (Test-Path $Executable)) {
            throw "Executable not found: $Executable"
        }
        $launchMode = $true
    } elseif ($ProcessId -gt 0) {
        # Verify target process exists
        $proc = Get-Process -Id $ProcessId -ErrorAction Stop
    } else {
        throw "Must specify either -ProcessId (attach mode) or -Executable (launch mode)"
    }

    # Build argument list
    $cmdArgs = @()

    if ($launchMode) {
        # Launch mode: -g (skip initial break) -G (skip final break)
        $cmdArgs += "-g"
        $cmdArgs += "-G"
    } else {
        # Attach mode
        $cmdArgs += "-p"
        $cmdArgs += $ProcessId.ToString()
    }

    if ($ChildProcesses) {
        $cmdArgs += "-o"
    }

    if ($OutputLog) {
        $logDir = Split-Path -Parent $OutputLog
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $cmdArgs += "-loga"
        $cmdArgs += $OutputLog
    }

    # Build commands to execute
    $cmdString = ""
    if ($CommandFile) {
        if (-not (Test-Path $CommandFile)) {
            throw "Command file not found: $CommandFile"
        }
        if ($launchMode) {
            $cmdString = "`$`$><@`"$CommandFile`";q"
        } else {
            $cmdString = "`$`$><@`"$CommandFile`";.detach;q"
        }
    } elseif ($Commands) {
        $cmdString = "$Commands"
        if ($launchMode) {
            if ($cmdString -notmatch '\bq\b') {
                $cmdString += ";q"
            }
        } else {
            if ($cmdString -notmatch '\.detach' -and $cmdString -notmatch '\bq\b') {
                $cmdString += ";.detach;q"
            }
        }
    } else {
        if ($launchMode) {
            # Default for launch: dump stacks after program finishes, then quit
            $cmdString = "~*k;q"
        } else {
            # Default for attach: dump all thread stacks, detach, quit
            $cmdString = "~*k;.detach;q"
        }
    }

    $cmdArgs += "-c"
    $cmdArgs += "`"$cmdString`""

    # In launch mode, executable and its arguments come last
    if ($launchMode) {
        $cmdArgs += "`"$Executable`""
        if ($Arguments) {
            $cmdArgs += $Arguments
        }
    }

    Write-Verbose "Running: $CdbPath $($cmdArgs -join ' ')"

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $CdbPath
    $psi.Arguments = $cmdArgs -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardInput = $true
    $psi.CreateNoWindow = $true

    if ($launchMode -and $WorkingDirectory) {
        $psi.WorkingDirectory = $WorkingDirectory
    }

    $process = [System.Diagnostics.Process]::Start($psi)

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    $exited = $process.WaitForExit($Timeout * 1000)
    if (-not $exited) {
        try {
            $process.StandardInput.WriteLine(".detach;q")
            $process.StandardInput.Flush()
            $graceful = $process.WaitForExit(5000)
            if (-not $graceful) {
                $process.Kill()
            }
        } catch {
            $process.Kill()
        }
        if ($launchMode) {
            # Clean up the launched process if it's still running
            try {
                $childProcs = Get-Process | Where-Object { $_.Path -eq $Executable } -ErrorAction SilentlyContinue
                foreach ($cp in $childProcs) {
                    try { $cp.Kill() } catch { }
                }
            } catch { }
        }
        throw "cdb session timed out after ${Timeout}s"
    }

    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result

    $output = @{
        success    = ($process.ExitCode -eq 0)
        exitCode   = $process.ExitCode
        mode       = $(if ($launchMode) { "launch" } else { "attach" })
        stdout     = $stdout
        stderr     = $stderr
        cdbPath    = $CdbPath
    }

    if ($launchMode) {
        $output.executable = $Executable
    } else {
        $output.pid = $ProcessId
        $output.processName = $proc.ProcessName
    }

    if ($OutputLog) {
        $output.logFile = $OutputLog
    }

    Write-Output (ConvertTo-Json $output -Depth 3)

} catch {
    Write-Error "WinDbg attach failed: $_"
    exit 1
}
