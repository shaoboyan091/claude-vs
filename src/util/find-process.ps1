<#
.SYNOPSIS
    Find Chrome/Chromium child processes by type.
.DESCRIPTION
    Uses Win32_Process WMI to discover Chrome processes and parse --type= from command line.
    Returns JSON with pid, type, and cmdline for each matching process.
.PARAMETER ProcessName
    Base process name without extension (default: chrome).
.PARAMETER Type
    Filter by Chrome process type: browser, gpu, renderer, utility, crashpad, etc.
    If omitted, returns all Chrome processes.
.PARAMETER ChromePath
    Optional full path to chrome.exe for disambiguation when multiple installs exist.
.EXAMPLE
    .\find-process.ps1 -ProcessName chrome -Type gpu
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$ProcessName = "chrome",

    [Parameter()]
    [ValidateSet("browser", "gpu", "gpu-process", "renderer", "utility", "crashpad", "crashpad-handler", "zygote", "")]
    [string]$Type = "",

    [Parameter()]
    [string]$ChromePath = ""
)

$ErrorActionPreference = "Stop"

function Get-ChromeProcessType {
    param([string]$CommandLine)

    if ([string]::IsNullOrWhiteSpace($CommandLine)) {
        return "browser"
    }

    if ($CommandLine -match '--type=(\S+)') {
        $rawType = $Matches[1]
        # Normalize common type names for convenience
        $typeMap = @{
            "gpu-process"     = "gpu"
            "crashpad-handler" = "crashpad"
        }
        if ($typeMap.ContainsKey($rawType)) {
            return $typeMap[$rawType]
        }
        return $rawType
    }

    # No --type= flag means this is the browser (main) process
    return "browser"
}

try {
    # Normalize Type parameter the same way Get-ChromeProcessType does
    $typeMap = @{
        "gpu-process"     = "gpu"
        "crashpad-handler" = "crashpad"
    }
    if ($Type -and $typeMap.ContainsKey($Type)) {
        $Type = $typeMap[$Type]
    }

    $safeProcessName = $ProcessName -replace "'", "''"
    $filter = "Name = '${safeProcessName}.exe' OR Name = '${safeProcessName}'"
    $processes = Get-CimInstance Win32_Process -Filter $filter -ErrorAction Stop

    if (-not $processes) {
        Write-Output (ConvertTo-Json @{
            error = "No processes found matching '$ProcessName'"
            results = @()
        })
        exit 1
    }

    $results = @()
    foreach ($proc in $processes) {
        $procType = Get-ChromeProcessType -CommandLine $proc.CommandLine

        # Filter by ChromePath if specified
        if ($ChromePath -and $proc.ExecutablePath) {
            $normalizedExe = $proc.ExecutablePath.Replace('/', '\').TrimEnd('\')
            $normalizedTarget = $ChromePath.Replace('/', '\').TrimEnd('\')
            if ($normalizedExe -ine $normalizedTarget) {
                continue
            }
        }

        # Filter by Type if specified
        if ($Type -and $procType -ne $Type) {
            continue
        }

        $results += @{
            pid     = $proc.ProcessId
            type    = $procType
            cmdline = $proc.CommandLine
            exe     = $proc.ExecutablePath
            parentPid = $proc.ParentProcessId
        }
    }

    if ($results.Count -eq 0) {
        $msg = "No '$ProcessName' processes"
        if ($Type) { $msg += " of type '$Type'" }
        $msg += " found"
        Write-Output (ConvertTo-Json @{ error = $msg; results = @() })
        exit 1
    }

    Write-Output (ConvertTo-Json @{
        count   = $results.Count
        results = $results
    } -Depth 4)

} catch {
    Write-Error "Failed to query processes: $_"
    exit 1
}
