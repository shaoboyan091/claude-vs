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

    Commands are written to a temp script file and executed via cdb's $$><@"file"
    command to avoid nested quoting issues and support paths with spaces.

    MaxHits is per-breakpoint: each breakpoint has its own hit counter using
    pseudo-registers $t0..$t19. Maximum 20 breakpoints per session.
.PARAMETER Executable
    Path to executable to launch under the debugger (launch mode).
    Mutually exclusive with ProcessId.
.PARAMETER ProcessId
    Process ID to attach to (attach mode).
    Mutually exclusive with Executable.
.PARAMETER Arguments
    Arguments to pass to the executable (launch mode only).
.PARAMETER WorkingDirectory
    Working directory for the launched process (launch mode only).
.PARAMETER Breakpoints
    Breakpoint locations as string array (e.g. "module!Function", "module!Class::Method").
    Maximum 20 breakpoints per session.
.PARAMETER BreakOnEntry
    If set, do not skip the initial debugger breakpoint. Pre-commands and symbol
    setup run at the initial break before continuing. Only effective in launch mode.
.PARAMETER MaxHits
    Maximum breakpoint hits per breakpoint before quitting (default: 1).
.PARAMETER OnHit
    Action at each breakpoint hit: stack, locals, full, step (default: full).
.PARAMETER StepCount
    Number of steps when OnHit=step (default: 10).
.PARAMETER StepMode
    Step mode: over (p command) or into (t command) (default: over).
.PARAMETER SymbolPath
    Additional symbol path to add (e.g. build output directory).
.PARAMETER PreCommands
    Extra cdb commands to run before setting breakpoints (semicolon-separated).
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

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$Breakpoints = @(),

    [Parameter()]
    [string[]]$SymbolModules = @(),

    [Parameter()]
    [switch]$DiscoverSymbols,

    [Parameter()]
    [switch]$ListModules,

    [Parameter()]
    [switch]$BreakOnEntry,

    [Parameter()]
    [ValidateRange(1, 10000)]
    [int]$MaxHits = 1,

    [Parameter()]
    [ValidateSet("stack", "locals", "full", "step")]
    [string]$OnHit = "full",

    [Parameter()]
    [ValidateRange(1, 1000)]
    [int]$StepCount = 10,

    [Parameter()]
    [ValidateSet("over", "into")]
    [string]$StepMode = "over",

    [Parameter()]
    [string]$SymbolPath = "",

    [Parameter()]
    [string]$PreCommands = "",

    [Parameter()]
    [string]$OutputLog = "",

    [Parameter()]
    [string]$CdbPath = "",

    [Parameter()]
    [ValidateRange(1, 3600)]
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

function Build-CommandFile {
    param(
        [string]$TempPath,
        [string[]]$BpLocations,
        [string]$Action,
        [int]$Steps,
        [string]$StepCmd,
        [int]$MaxHitCount,
        [bool]$IsAttachMode,
        [string]$SymPath,
        [string]$PreCmds,
        [string[]]$SymModules = @()
    )

    $lines = @()

    $lines += "sxd *"
    $lines += "sxe av"
    $lines += "sxe sov"
    if ($IsAttachMode) {
        $lines += "sxe -c `".echo ==PROCESS_EXITED==;.detach;q`" ep"
    } else {
        $lines += "sxe -c `".echo ==PROCESS_EXITED==;q`" ep"
    }

    if ($SymPath) {
        $lines += ".sympath+ $SymPath"
        if ($SymModules.Count -eq 0) {
            $lines += ".reload"
        }
    }

    if ($SymModules.Count -gt 0) {
        foreach ($mod in $SymModules) {
            $lines += "ld $mod"
            $lines += ".echo ==LD_RESULT==${mod}=="
        }
        $lines += ".echo ==SYMBOLS_LOADED=="
    }

    if ($PreCmds) {
        $lines += $PreCmds
    }

    $bpCount = $BpLocations.Count
    for ($i = 0; $i -lt $bpCount; $i++) {
        $lines += "r `$t$i = 0"
    }

    for ($i = 0; $i -lt $bpCount; $i++) {
        $bp = $BpLocations[$i]
        $actionCmds = Build-BreakpointAction -Location $bp -Action $Action -Steps $Steps -StepCmd $StepCmd

        if ($IsAttachMode) {
            $quitCmd = ".detach;q"
        } else {
            $quitCmd = "q"
        }

        $buBody = "r `$t$i = @`$t$i + 1; .if (@`$t$i >= $MaxHitCount) { $actionCmds;$quitCmd } .else { $actionCmds;gc }"
        $lines += "bu $bp `"$buBody`""
        $lines += ".echo ==BP_SET==${bp}=="
    }

    $lines += "g"

    $lines | Out-File -FilePath $TempPath -Encoding ascii
}

function Build-DiscoveryCommandFile {
    param(
        [string]$TempPath,
        [string[]]$Patterns,
        [bool]$IsAttachMode,
        [string]$SymPath,
        [string[]]$SymModules = @()
    )

    $lines = @()
    $lines += "sxd *"

    if ($SymPath) {
        $lines += ".sympath+ $SymPath"
    }

    foreach ($mod in $SymModules) {
        $lines += "ld $mod"
        $lines += ".echo ==LD_RESULT==${mod}=="
    }
    $lines += ".echo ==SYMBOLS_LOADED=="

    foreach ($pat in $Patterns) {
        $lines += ".echo ==DISCOVER==${pat}=="
        $lines += "x $pat"
        $lines += ".echo ==DISCOVER_END==${pat}=="
    }

    $lines += ".echo ==DISCOVER_DONE=="
    if ($IsAttachMode) {
        $lines += ".detach;q"
    } else {
        $lines += "q"
    }

    $lines | Out-File -FilePath $TempPath -Encoding ascii
}

function Build-ListModulesCommandFile {
    param(
        [string]$TempPath,
        [bool]$IsAttachMode,
        [string]$SymPath
    )

    $lines = @()
    $lines += "sxd *"

    if ($SymPath) {
        $lines += ".sympath+ $SymPath"
    }

    $lines += ".echo ==MODULE_LIST_START=="
    $lines += "lm"
    $lines += ".echo ==MODULE_LIST_END=="

    if ($IsAttachMode) {
        $lines += ".detach;q"
    } else {
        $lines += "q"
    }

    $lines | Out-File -FilePath $TempPath -Encoding ascii
}

function Parse-SymbolDiscovery {
    param([string]$RawOutput, [string[]]$Patterns)

    $results = @{}
    foreach ($pat in $Patterns) {
        $results[$pat] = @()
    }

    $discoverPattern = '==DISCOVER==(.+?)=='
    $endPattern = '==DISCOVER_END==(.+?)=='
    $allStarts = [regex]::Matches($RawOutput, $discoverPattern)
    $allEnds = [regex]::Matches($RawOutput, $endPattern)

    for ($m = 0; $m -lt $allStarts.Count; $m++) {
        $match = $allStarts[$m]
        $pat = $match.Groups[1].Value
        $startIdx = $match.Index + $match.Length

        $endIdx = $RawOutput.Length
        foreach ($em in $allEnds) {
            if ($em.Groups[1].Value -eq $pat -and $em.Index -gt $startIdx) {
                $endIdx = $em.Index
                break
            }
        }
        if ($endIdx -eq $RawOutput.Length) {
            $doneIdx = $RawOutput.IndexOf('==DISCOVER_DONE==', $startIdx)
            if ($doneIdx -ge 0) { $endIdx = $doneIdx }
        }

        $segment = $RawOutput.Substring($startIdx, $endIdx - $startIdx)
        $symbols = @()

        foreach ($line in ($segment -split "`n")) {
            $trimmed = $line.Trim()
            if ($trimmed -match '^[0-9a-f`]+\s+(.+)$') {
                $symbols += $Matches[1].Trim()
            }
        }

        if ($results.ContainsKey($pat)) {
            $results[$pat] = $symbols
        }
    }

    return $results
}

function Parse-ModuleList {
    param([string]$RawOutput)

    $modules = @()
    $startMarker = '==MODULE_LIST_START=='
    $endMarker = '==MODULE_LIST_END=='

    $startIdx = $RawOutput.IndexOf($startMarker)
    $endIdx = $RawOutput.IndexOf($endMarker)

    if ($startIdx -lt 0 -or $endIdx -lt 0) {
        return @{ modules = $modules }
    }

    $segment = $RawOutput.Substring($startIdx + $startMarker.Length, $endIdx - $startIdx - $startMarker.Length)

    foreach ($line in ($segment -split "`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^([0-9a-f`]+)\s+([0-9a-f`]+)\s+(\S+)\s*(.*)$') {
            $startAddr = $Matches[1]
            $endAddr = $Matches[2]
            $name = $Matches[3]
            $path = $Matches[4].Trim()

            $cleanStart = $startAddr -replace '`', ''
            $cleanEnd = $endAddr -replace '`', ''
            $size = 0
            try {
                $size = [Convert]::ToInt64($cleanEnd, 16) - [Convert]::ToInt64($cleanStart, 16)
            } catch {}

            $modules += @{
                name  = $name
                start = $startAddr
                end   = $endAddr
                size  = $size
                path  = $path
            }
        }
    }

    return @{ modules = $modules }
}

function Parse-Diagnostics {
    param([string]$RawOutput)

    $diagnostics = @()

    $ldPattern = '==LD_RESULT==(.+?)=='
    $ldMatches = [regex]::Matches($RawOutput, $ldPattern)
    foreach ($m in $ldMatches) {
        $mod = $m.Groups[1].Value
        $preceding = $RawOutput.Substring([Math]::Max(0, $m.Index - 500), [Math]::Min(500, $m.Index))

        $status = "ok"
        $message = "symbols loaded"
        if ($preceding -match "Unable to (add|load) module\b") {
            $status = "error"
            $message = "module not found in process - verify module name with -ListModules"
        } elseif ($preceding -match "Symbols already loaded for\b") {
            $status = "ok"
            $message = "symbols already loaded"
        } elseif ($preceding -match "No matching modules found\b") {
            $status = "error"
            $message = "no matching module found in process - verify module name with -ListModules"
        } elseif ($preceding -match "not a valid module\b") {
            $status = "error"
            $message = "invalid module name"
        } elseif ($preceding -match "DBGHELP: .+ - noass?ociated PDB") {
            $status = "error"
            $message = "module loaded but no PDB found - check SymbolPath includes the PDB directory"
        }

        $diagnostics += @{
            operation = "ld"
            target    = $mod
            status    = $status
            message   = $message
        }
    }

    $bpSetPattern = '==BP_SET==(.+?)=='
    $bpSetMatches = [regex]::Matches($RawOutput, $bpSetPattern)
    foreach ($m in $bpSetMatches) {
        $bp = $m.Groups[1].Value
        $preceding = $RawOutput.Substring([Math]::Max(0, $m.Index - 500), [Math]::Min(500, $m.Index))

        $status = "ok"
        $message = "breakpoint set"
        if ($preceding -match "Couldn.t resolve error at\b") {
            $status = "error"
            $message = "symbol not found - use -DiscoverSymbols to search for correct symbol name"
        } elseif ($preceding -match "Bp expression .+ could not be resolved") {
            $status = "error"
            $message = "symbol could not be resolved - module may not be loaded, use -SymbolModules to load it first"
        } elseif ($preceding -match "WARNING: Unable to verify") {
            $status = "warning"
            $message = "breakpoint set as deferred (unverified) - symbol may resolve when module loads at runtime"
        }

        $diagnostics += @{
            operation = "bu"
            target    = $bp
            status    = $status
            message   = $message
        }
    }

    return $diagnostics
}

function Parse-BreakpointOutput {
    param([string]$RawOutput, [string[]]$Locations)

    $results = @()
    $markerPattern = '==BP_HIT==(.+?)=='
    $allMatches = [regex]::Matches($RawOutput, $markerPattern)

    $hitsByLocation = @{}
    foreach ($loc in $Locations) {
        $hitsByLocation[$loc] = @{
            location = $loc
            hitCount = 0
            hits     = @()
        }
    }

    for ($m = 0; $m -lt $allMatches.Count; $m++) {
        $match = $allMatches[$m]
        $loc = $match.Groups[1].Value
        $startIdx = $match.Index + $match.Length

        if (($m + 1) -lt $allMatches.Count) {
            $endIdx = $allMatches[$m + 1].Index
        } else {
            $endIdx = $RawOutput.Length
        }

        $segment = $RawOutput.Substring($startIdx, $endIdx - $startIdx)

        if (-not $hitsByLocation.ContainsKey($loc)) {
            continue
        }

        $entry = $hitsByLocation[$loc]
        $entry.hitCount++

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
            if ($trimmed -match '\w+\s+=\s+' -and $trimmed -notmatch '^(Child-SP|RetAddr|Call Site|[0-9a-f]{2,} )') {
                $section = "locals"
            }
            if ($trimmed -match '^[a-z]{2,3}=[0-9a-f]') {
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
            $stepLines = $stepContent -split "`n"
            $sStack = @()
            $sLocals = @()
            $sSec = "stack"
            foreach ($sl in $stepLines) {
                $st = $sl.Trim()
                if ($st -match '\w+\s+=\s+' -and $st -notmatch '^(Child-SP|RetAddr|Call Site|[0-9a-f]{2,} )') { $sSec = "locals" }
                switch ($sSec) {
                    "stack"  { $sStack += $sl }
                    "locals" { $sLocals += $sl }
                }
            }
            $hit.steps += @{
                step        = $stepNum
                instruction = ($stepLines | Where-Object { $_.Trim() } | Select-Object -First 1).Trim()
                stack       = ($sStack -join "`n").Trim()
                locals      = ($sLocals -join "`n").Trim()
            }
        }

        $entry.hits += $hit
    }

    foreach ($loc in $Locations) {
        $results += $hitsByLocation[$loc]
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

    if ($ListModules -and $DiscoverSymbols) {
        throw "Cannot specify both -ListModules and -DiscoverSymbols."
    }
    if ($ListModules -and $Breakpoints.Count -gt 0) {
        throw "Cannot specify -Breakpoints with -ListModules."
    }
    if (-not $ListModules -and -not $DiscoverSymbols -and $Breakpoints.Count -eq 0) {
        throw "At least one breakpoint location is required (or use -ListModules / -DiscoverSymbols)"
    }

    $launchMode = $false
    if ($Executable -and $ProcessId -gt 0) {
        throw "Cannot specify both -Executable and -ProcessId. Use one or the other."
    }
    if ($Executable) {
        if (-not (Test-Path $Executable)) {
            throw "Executable not found: $Executable"
        }
        $launchMode = $true
    } elseif ($ProcessId -gt 0) {
        $proc = Get-Process -Id $ProcessId -ErrorAction Stop
        if ($BreakOnEntry) {
            Write-Warning "-BreakOnEntry has no effect in attach mode (ignored)"
        }
    } else {
        throw "Must specify either -ProcessId (attach mode) or -Executable (launch mode)"
    }

    if ($Breakpoints.Count -gt 20) {
        throw "Maximum 20 breakpoints per session (limited by cdb pseudo-registers `$t0..`$t19)"
    }

    $stepCmd = if ($StepMode -eq "into") { "t" } else { "p" }
    $isAttachMode = (-not $launchMode)

    $tempFile = [System.IO.Path]::GetTempFileName()
    $shortTempFile = (New-Object -ComObject Scripting.FileSystemObject).GetFile($tempFile).ShortPath
    try {
        if ($ListModules) {
            Build-ListModulesCommandFile -TempPath $tempFile `
                -IsAttachMode $isAttachMode `
                -SymPath $SymbolPath
        } elseif ($DiscoverSymbols) {
            Build-DiscoveryCommandFile -TempPath $tempFile `
                -Patterns $Breakpoints `
                -IsAttachMode $isAttachMode `
                -SymPath $SymbolPath `
                -SymModules $SymbolModules
        } else {
            Build-CommandFile -TempPath $tempFile `
                -BpLocations $Breakpoints `
                -Action $OnHit `
                -Steps $StepCount `
                -StepCmd $stepCmd `
                -MaxHitCount $MaxHits `
                -IsAttachMode $isAttachMode `
                -SymPath $SymbolPath `
                -PreCmds $PreCommands `
                -SymModules $SymbolModules
        }

        $cmdArgs = @()

        if ($launchMode) {
            if (-not $BreakOnEntry) {
                $cmdArgs += "-g"
            }
            $cmdArgs += "-G"
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
        $cdbCmd = "`$`$><@$shortTempFile"
        $cmdArgs += $cdbCmd

        if ($launchMode) {
            $cmdArgs += "`"$Executable`""
            if ($Arguments) {
                $cmdArgs += $Arguments
            }
        }

        Write-Verbose "Running: $CdbPath $($cmdArgs -join ' ')"
        Write-Verbose "Command file: $tempFile (short: $shortTempFile)"

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
            $partialOutput = $stdoutTask.Result
            $hasSymbolsLoaded = $partialOutput -match '==SYMBOLS_LOADED=='
            if ($SymbolModules.Count -gt 0 -and -not $hasSymbolsLoaded) {
                throw "cdb session timed out after ${Timeout}s during symbol loading - try targeting fewer/smaller modules"
            }
            throw "cdb session timed out after ${Timeout}s"
        }

        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result
        $diag = Parse-Diagnostics -RawOutput $stdout

        if ($ListModules) {
            $moduleResult = Parse-ModuleList -RawOutput $stdout
            $output = @{
                success     = ($process.ExitCode -eq 0)
                mode        = $(if ($launchMode) { "launch" } else { "attach" })
                modules     = $moduleResult.modules
                diagnostics = $diag
                stdout      = $stdout
                stderr      = $stderr
            }
        } elseif ($DiscoverSymbols) {
            $discoveryResult = Parse-SymbolDiscovery -RawOutput $stdout -Patterns $Breakpoints
            $output = @{
                success     = ($process.ExitCode -eq 0)
                mode        = $(if ($launchMode) { "launch" } else { "attach" })
                symbols     = $discoveryResult
                diagnostics = $diag
                stdout      = $stdout
                stderr      = $stderr
            }
        } else {
            $bpResults = Parse-BreakpointOutput -RawOutput $stdout -Locations $Breakpoints

            $output = @{
                success     = ($process.ExitCode -eq 0)
                mode        = $(if ($launchMode) { "launch" } else { "attach" })
                breakpoints = $bpResults
                diagnostics = $diag
                stdout      = $stdout
                stderr      = $stderr
            }
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

    } finally {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

} catch {
    Write-Error "WinDbg breakpoint debug failed: $_"
    exit 1
}
