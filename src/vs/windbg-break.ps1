<#
.SYNOPSIS
    Set breakpoints in cdb.exe and capture state at each hit.
.DESCRIPTION
    Wraps cdb.exe for scripted breakpoint debugging: set breakpoints, run the
    target, capture stack/locals/registers at each hit, optionally step through
    code. Two modes:
      Attach mode: -ProcessId <pid> attaches to an existing process.
      Launch mode:  -Executable <path> starts the program under the debugger.
    Output is structured JSON with per-breakpoint hit data.
.PARAMETER Executable
    Path to executable to launch under the debugger (launch mode).
.PARAMETER ProcessId
    Process ID to attach to (attach mode).
.PARAMETER Arguments
    Arguments to pass to the executable (launch mode only).
.PARAMETER WorkingDirectory
    Working directory for the launched process (launch mode only).
.PARAMETER Breakpoints
    Breakpoint locations as string array (e.g. "module!Function", "module!Class::Method").
.PARAMETER BreakOnEntry
    If set, do not skip the initial debugger breakpoint.
.PARAMETER MaxHits
    Maximum breakpoint hits before quitting (default: 1).
.PARAMETER OnHit
    Action at each breakpoint hit: stack, locals, full, step (default: full).
.PARAMETER StepCount
    Number of steps when OnHit=step (default: 10).
.PARAMETER StepMode
    Step mode: over (p command) or into (t command) (default: over).
.PARAMETER OutputLog
    Path to write cdb session log.
.PARAMETER CdbPath
    Path to cdb.exe. Auto-detected if omitted.
.PARAMETER Timeout
    Max seconds to wait for cdb session (default: 120).
.EXAMPLE
    .\windbg-break.ps1 -Executable "C:\tests\test.exe" -Breakpoints "test!main" -OnHit full
    .\windbg-break.ps1 -ProcessId 1234 -Breakpoints "module!Func","module!Other" -MaxHits 3
    .\windbg-break.ps1 -Executable "C:\tests\test.exe" -Breakpoints "test!Render" -OnHit step -StepCount 20 -StepMode into
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$Executable = "",

    [Parameter()]
    [int]$ProcessId = 0,

    [Parameter()]
    [string]$Arguments = "",

    [Parameter()]
    [string]$WorkingDirectory = "",

    [Parameter(Mandatory=$true)]
    [string[]]$Breakpoints,

    [Parameter()]
    [switch]$BreakOnEntry,

    [Parameter()]
    [int]$MaxHits = 1,

    [Parameter()]
    [ValidateSet("stack", "locals", "full", "step")]
    [string]$OnHit = "full",

    [Parameter()]
    [int]$StepCount = 10,

    [Parameter()]
    [ValidateSet("over", "into")]
    [string]$StepMode = "over",

    [Parameter()]
    [string]$OutputLog = "",

    [Parameter()]
    [string]$CdbPath = "",

    [Parameter()]
    [int]$Timeout = 120
)

$ErrorActionPreference = "Stop"

function Find-CdbExe {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\Debuggers\x64\cdb.exe"
        "${env:ProgramFiles}\Windows Kits\10\Debuggers\x64\cdb.exe"
        "${env:LOCALAPPDATA}\Microsoft\WindowsApps\cdb.exe"
    )

    $inPath = Get-Command cdb.exe -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }

    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }

    $windbgDirs = Get-ChildItem "${env:LOCALAPPDATA}\Microsoft\WinDbg*" -Directory -ErrorAction SilentlyContinue
    foreach ($dir in $windbgDirs) {
        $exe = Join-Path $dir.FullName "cdb.exe"
        if (Test-Path $exe) { return $exe }
    }

    throw "cdb.exe not found. Install Windows SDK or WinDbg Preview."
}

function Build-BreakpointAction {
    param(
        [string]$Location,
        [string]$Action,
        [int]$Steps,
        [string]$StepCmd
    )

    $marker = ".echo ==BP_HIT==${Location}=="

    switch ($Action) {
        "stack"  { return "${marker};k" }
        "locals" { return "${marker};k;dv /t" }
        "full"   { return "${marker};k;dv /t;r" }
        "step"   {
            $cmds = "${marker};k;dv /t"
            for ($i = 1; $i -le $Steps; $i++) {
                $cmds += ";${StepCmd};.echo ==STEP==${i}==;k;dv /t"
            }
            return $cmds
        }
    }
}

function Parse-BreakpointOutput {
    param([string]$RawOutput, [string[]]$Locations)

    $results = @()
    foreach ($loc in $Locations) {
        $entry = @{
            location = $loc
            hitCount = 0
            hits     = @()
        }

        $pattern = [regex]::Escape("==BP_HIT==${loc}==")
        $segments = [regex]::Split($RawOutput, $pattern)

        for ($i = 1; $i -lt $segments.Count; $i++) {
            $entry.hitCount++
            $segment = $segments[$i]

            $hit = @{
                stack     = ""
                locals    = ""
                registers = ""
                steps     = @()
            }

            $stepParts = [regex]::Split($segment, '==STEP==(\d+)==')
            $mainPart = $stepParts[0]

            $lines = $mainPart -split "`n"
            $stackLines = @()
            $localLines = @()
            $regLines = @()
            $section = "stack"
            foreach ($line in $lines) {
                $trimmed = $line.Trim()
                if ($trimmed -match '^\s*\w+\s+=') {
                    $section = "locals"
                }
                if ($trimmed -match '^[a-z]{2,3}=') {
                    $section = "registers"
                }
                switch ($section) {
                    "stack"     { $stackLines += $line }
                    "locals"    { $localLines += $line }
                    "registers" { $regLines += $line }
                }
            }
            $hit.stack = ($stackLines -join "`n").Trim()
            $hit.locals = ($localLines -join "`n").Trim()
            $hit.registers = ($regLines -join "`n").Trim()

            for ($s = 1; $s -lt $stepParts.Count; $s += 2) {
                $stepNum = [int]$stepParts[$s]
                $stepContent = if (($s + 1) -lt $stepParts.Count) { $stepParts[$s + 1] } else { "" }
                $hit.steps += @{
                    step    = $stepNum
                    instruction = ($stepContent -split "`n")[0].Trim()
                    stack   = ""
                    locals  = ""
                }
            }

            $entry.hits += $hit
        }
        $results += $entry
    }
    return $results
}

try {
    if (-not $CdbPath) {
        $CdbPath = Find-CdbExe
    }
    if (-not (Test-Path $CdbPath)) {
        throw "cdb.exe not found at: $CdbPath"
    }

    $launchMode = $false
    if ($Executable) {
        if (-not (Test-Path $Executable)) {
            throw "Executable not found: $Executable"
        }
        $launchMode = $true
    } elseif ($ProcessId -gt 0) {
        $proc = Get-Process -Id $ProcessId -ErrorAction Stop
    } else {
        throw "Must specify either -ProcessId (attach mode) or -Executable (launch mode)"
    }

    if ($Breakpoints.Count -eq 0) {
        throw "At least one breakpoint location is required"
    }

    $stepCmd = if ($StepMode -eq "into") { "t" } else { "p" }

    $buCommands = @()
    foreach ($bp in $Breakpoints) {
        $action = Build-BreakpointAction -Location $bp -Action $OnHit -Steps $StepCount -StepCmd $stepCmd
        $buCommands += "bu $bp `"${action};gc`""
    }

    $cmdString = ($buCommands -join ";") + ";g"

    $cmdArgs = @()

    if ($launchMode) {
        if (-not $BreakOnEntry) {
            $cmdArgs += "-g"
        }
    } else {
        $cmdArgs += "-p"
        $cmdArgs += $ProcessId.ToString()
    }

    if ($OutputLog) {
        $logDir = Split-Path -Parent $OutputLog
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $cmdArgs += "-loga"
        $cmdArgs += $OutputLog
    }

    $cmdArgs += "-c"
    $cmdArgs += "`"$cmdString`""

    if ($launchMode) {
        $cmdArgs += $Executable
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
    $psi.CreateNoWindow = $true

    if ($launchMode -and $WorkingDirectory) {
        $psi.WorkingDirectory = $WorkingDirectory
    }

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

    $bpResults = Parse-BreakpointOutput -RawOutput $stdout -Locations $Breakpoints

    $output = @{
        success     = ($process.ExitCode -eq 0)
        mode        = $(if ($launchMode) { "launch" } else { "attach" })
        breakpoints = $bpResults
        stdout      = $stdout
        stderr      = $stderr
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

    Write-Output (ConvertTo-Json $output -Depth 5)

} catch {
    Write-Error "WinDbg breakpoint debug failed: $_"
    exit 1
}
