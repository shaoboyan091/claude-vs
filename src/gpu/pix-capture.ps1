<#
.SYNOPSIS
    Capture GPU frames using PIX (D3D12 only).
.DESCRIPTION
    Uses DLL injection approach: sets environment variable to load WinPixGpuCapturer.dll.
    Requires Windows Developer Mode enabled.
.PARAMETER Executable
    Path to executable to capture.
.PARAMETER OutputPath
    Path for the .wpix capture file.
.PARAMETER CaptureFrames
    Number of frames to capture (default: 1).
.PARAMETER PixInstallDir
    PIX installation directory. Auto-detected if omitted.
.PARAMETER Arguments
    Arguments to pass to the executable.
.EXAMPLE
    .\pix-capture.ps1 -Executable "chrome.exe" -OutputPath "C:\tmp\capture.wpix" -Arguments "--no-sandbox"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Executable,

    [Parameter()]
    [string]$OutputPath = "",

    [Parameter()]
    [int]$CaptureFrames = 1,

    [Parameter()]
    [string]$PixInstallDir = "",

    [Parameter()]
    [string]$Arguments = "",

    [Parameter()]
    [int]$Timeout = 60
)

$ErrorActionPreference = "Stop"

function Test-DeveloperMode {
    try {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
        $val = Get-ItemPropertyValue $regPath -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction Stop
        return $val -eq 1
    } catch {
        return $false
    }
}

function Find-PixDll {
    param([string]$InstallDir)

    if ($InstallDir -and (Test-Path $InstallDir)) {
        $dll = Get-ChildItem $InstallDir -Filter "WinPixGpuCapturer.dll" -Recurse | Select-Object -First 1
        if ($dll) { return $dll.FullName }
    }

    # Search common PIX install locations
    $searchDirs = @(
        "${env:ProgramFiles}\Microsoft PIX"
        "${env:LOCALAPPDATA}\Microsoft\PIX"
    )

    foreach ($dir in $searchDirs) {
        if (Test-Path $dir) {
            # PIX installs by version number, get latest
            $versionDirs = Get-ChildItem $dir -Directory | Sort-Object Name -Descending
            foreach ($vd in $versionDirs) {
                $dll = Join-Path $vd.FullName "WinPixGpuCapturer.dll"
                if (Test-Path $dll) { return $dll }
            }
        }
    }

    throw "WinPixGpuCapturer.dll not found. Install PIX from https://devblogs.microsoft.com/pix/download/"
}

try {
    # Check prerequisites
    if (-not (Test-DeveloperMode)) {
        Write-Warning "Windows Developer Mode may not be enabled. PIX capture might fail."
        Write-Warning "Enable it: Settings > For developers > Developer Mode"
    }

    if (-not (Test-Path $Executable)) {
        throw "Executable not found: $Executable"
    }

    $pixDll = Find-PixDll -InstallDir $PixInstallDir

    if (-not $OutputPath) {
        $OutputPath = Join-Path $env:TEMP "pix_capture_$(Get-Date -Format 'yyyyMMdd_HHmmss').wpix"
    }

    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    # PIX programmatic capture via DLL injection
    # Set environment variables before launching the process
    $env:PIX_CAPTURE_ON_CONNECT = "1"
    $env:PIX_NUMBER_OF_FRAMES = $CaptureFrames.ToString()
    $env:PIX_CAPTURE_FILE = $OutputPath

    # The key mechanism: loading WinPixGpuCapturer.dll into the process
    # This is done by adding the DLL directory to the DLL search path
    $pixDir = Split-Path -Parent $pixDll

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Executable
    # Chrome requires sandbox disabled for DLL injection capture
    $effectiveArgs = $Arguments
    if ($Executable -match 'chrome' -and $effectiveArgs -notmatch 'disable-gpu-sandbox') {
        Write-Warning "Chrome detected: auto-adding --disable-gpu-sandbox --disable-gpu-watchdog for PIX capture"
        $effectiveArgs = "$effectiveArgs --disable-gpu-sandbox --disable-gpu-watchdog".Trim()
    }
    $psi.Arguments = $effectiveArgs
    $psi.UseShellExecute = $false
    $psi.EnvironmentVariables["PIX_CAPTURE_ON_CONNECT"] = "1"
    $psi.EnvironmentVariables["PIX_NUMBER_OF_FRAMES"] = $CaptureFrames.ToString()
    $psi.EnvironmentVariables["PIX_CAPTURE_FILE"] = $OutputPath
    # LoadLibrary injection path
    $psi.EnvironmentVariables["PATH"] = "$pixDir;$($env:PATH)"

    Write-Verbose "Launching with PIX DLL injection: $Executable"
    Write-Verbose "PIX DLL: $pixDll"

    $process = [System.Diagnostics.Process]::Start($psi)

    # Wait for capture
    $exited = $process.WaitForExit($Timeout * 1000)
    if (-not $exited) {
        $process.Kill()
    }

    # Clean up env vars
    Remove-Item env:PIX_CAPTURE_ON_CONNECT -ErrorAction SilentlyContinue
    Remove-Item env:PIX_NUMBER_OF_FRAMES -ErrorAction SilentlyContinue
    Remove-Item env:PIX_CAPTURE_FILE -ErrorAction SilentlyContinue

    $captureExists = Test-Path $OutputPath

    Write-Output (ConvertTo-Json @{
        success      = $captureExists
        executable   = $Executable
        outputPath   = $OutputPath
        captureExists = $captureExists
        pixDll       = $pixDll
        frames       = $CaptureFrames
        note         = if ($captureExists) { "Capture saved" } else { "Capture file not found. Ensure the app uses D3D12 and Developer Mode is enabled." }
    })

} catch {
    Write-Error "PIX capture failed: $_"
    exit 1
}
