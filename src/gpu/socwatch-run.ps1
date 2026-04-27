<#
.SYNOPSIS
    Run Intel SoC Watch for power and performance measurement.
.DESCRIPTION
    Wraps socwatch CLI to collect CPU/GPU C-states, frequencies, and power data.
    Parses CSV output into a summary JSON.
.PARAMETER Duration
    Collection duration in seconds.
.PARAMETER OutputPath
    Base path for output files (socwatch appends extensions).
.PARAMETER Features
    Comma-separated list of features to collect.
    Common: cpu-cstate, gpu-cstate, freq, power, thermal.
    Default: cpu-cstate,gpu-cstate,freq
.PARAMETER SocWatchPath
    Path to socwatch.exe. Auto-detected if omitted.
.PARAMETER RunElevated
    If set, attempts to relaunch as admin (socwatch requires admin).
.EXAMPLE
    .\socwatch-run.ps1 -Duration 30 -OutputPath "C:\tmp\power_test"
    .\socwatch-run.ps1 -Duration 10 -Features "cpu-cstate,gpu-cstate,freq,power" -OutputPath "C:\tmp\full_test"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [int]$Duration,

    [Parameter()]
    [string]$OutputPath = "",

    [Parameter()]
    [string]$Features = "cpu-cstate,gpu-cstate,freq",

    [Parameter()]
    [string]$SocWatchPath = "",

    [Parameter()]
    [switch]$RunElevated
)

$ErrorActionPreference = "Stop"

function Find-SocWatch {
    $inPath = Get-Command socwatch.exe -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }

    $candidates = @(
        "${env:ProgramFiles}\Intel\SoC Watch\socwatch.exe"
        "${env:ProgramFiles(x86)}\Intel\SoC Watch\socwatch.exe"
        "C:\Program Files\Intel\socwatch\socwatch.exe"
    )

    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }

    throw "socwatch.exe not found. Install Intel SoC Watch from Intel developer tools."
}

function Test-IsAdmin {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Parse-SocWatchCsv {
    param([string]$CsvPath)

    if (-not (Test-Path $CsvPath)) {
        return @{ error = "CSV file not found: $CsvPath" }
    }

    $lines = Get-Content $CsvPath
    $summary = @{
        file       = $CsvPath
        lineCount  = $lines.Count
        sections   = @()
    }

    $currentSection = $null
    foreach ($line in $lines) {
        if ($line -match '^#\s*(.+)') {
            if ($currentSection) {
                $summary.sections += $currentSection
            }
            $currentSection = @{
                header = $Matches[1].Trim()
                data   = @()
            }
        }
        elseif ($currentSection -and $line.Trim() -and $line -notmatch '^#') {
            $currentSection.data += $line
        }
    }
    if ($currentSection) {
        $summary.sections += $currentSection
    }

    return $summary
}

try {
    if (-not (Test-IsAdmin)) {
        if ($RunElevated) {
            Write-Warning "Relaunching as administrator..."
            $argString = "-Duration $Duration"
            if ($OutputPath) { $argString += " -OutputPath `"$OutputPath`"" }
            $argString += " -Features `"$Features`""
            if ($SocWatchPath) { $argString += " -SocWatchPath `"$SocWatchPath`"" }

            Start-Process powershell -Verb RunAs -ArgumentList "-File `"$($MyInvocation.MyCommand.Path)`" $argString" -Wait
            exit 0
        } else {
            Write-Warning "SoC Watch requires administrator privileges. Use -RunElevated or run from an elevated shell."
        }
    }

    if (-not $SocWatchPath) {
        $SocWatchPath = Find-SocWatch
    }

    if (-not $OutputPath) {
        $OutputPath = Join-Path $env:TEMP "socwatch_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }

    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    # Build feature flags
    $featureArgs = @()
    foreach ($f in ($Features -split ',')) {
        $featureArgs += "-f"
        $featureArgs += $f.Trim()
    }

    $cmdArgs = @(
        "-t", $Duration.ToString()
        "-o", "`"$OutputPath`""
    ) + $featureArgs

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $SocWatchPath
    $psi.Arguments = $cmdArgs -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    Write-Verbose "Running: $SocWatchPath $($cmdArgs -join ' ')"
    Write-Host "Collecting for ${Duration}s..."

    $process = [System.Diagnostics.Process]::Start($psi)

    # Start async reads before WaitForExit to avoid deadlock
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    $timeoutMs = ($Duration + 30) * 1000
    $exited = $process.WaitForExit($timeoutMs)
    if (-not $exited) {
        $process.Kill()
        throw "socwatch timed out"
    }

    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result

    # Find output CSV
    $csvFiles = Get-ChildItem "$OutputPath*" -Filter "*.csv" -ErrorAction SilentlyContinue
    $csvSummary = $null
    if ($csvFiles) {
        $csvSummary = Parse-SocWatchCsv -CsvPath $csvFiles[0].FullName
    }

    # Find all output files
    $allOutputs = @(Get-ChildItem "$OutputPath*" -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })

    $result = @{
        success    = ($process.ExitCode -eq 0)
        duration   = $Duration
        features   = $Features
        outputPath = $OutputPath
        files      = $allOutputs
        stdout     = $stdout
        stderr     = $stderr
    }

    if ($csvSummary) {
        $result.csvSummary = $csvSummary
    }

    # Save summary JSON alongside CSV
    $jsonPath = "${OutputPath}_summary.json"
    $result | ConvertTo-Json -Depth 5 | Out-File $jsonPath -Encoding UTF8
    $result.summaryJson = $jsonPath

    Write-Output (ConvertTo-Json $result -Depth 5)

} catch {
    Write-Error "SoC Watch run failed: $_"
    exit 1
}
