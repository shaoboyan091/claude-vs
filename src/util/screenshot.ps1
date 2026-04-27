<#
.SYNOPSIS
    Capture a window screenshot by PID or window title.
.DESCRIPTION
    Uses Win32 API (PrintWindow / BitBlt) via Add-Type to capture a specific window to PNG.
.PARAMETER Pid
    Process ID whose main window to capture.
.PARAMETER Title
    Window title substring to match (alternative to Pid).
.PARAMETER OutputPath
    Path for the output PNG file.
.PARAMETER FullScreen
    Capture the entire screen instead of a specific window.
.EXAMPLE
    .\screenshot.ps1 -Pid 1234 -OutputPath "C:\tmp\capture.png"
    .\screenshot.ps1 -Title "Google Chrome" -OutputPath "C:\tmp\chrome.png"
#>
[CmdletBinding()]
param(
    [Parameter(ParameterSetName = "ByPid")]
    [int]$ProcessId = 0,

    [Parameter(ParameterSetName = "ByTitle")]
    [string]$Title = "",

    [Parameter(ParameterSetName = "FullScreen")]
    [switch]$FullScreen,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$win32 = Add-Type -MemberDefinition @'
[DllImport("user32.dll")]
public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

[DllImport("user32.dll")]
public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);

[DllImport("user32.dll")]
public static extern IntPtr GetForegroundWindow();

[DllImport("user32.dll")]
public static extern bool SetForegroundWindow(IntPtr hWnd);

[DllImport("user32.dll")]
public static extern bool IsWindow(IntPtr hWnd);

[DllImport("user32.dll")]
public static extern bool IsWindowVisible(IntPtr hWnd);

[StructLayout(LayoutKind.Sequential)]
public struct RECT {
    public int Left, Top, Right, Bottom;
}
'@ -Name "Win32" -Namespace "Screenshot" -PassThru

function Find-WindowHandle {
    param([int]$ProcessId, [string]$WindowTitle)

    if ($ProcessId -gt 0) {
        $proc = Get-Process -Id $ProcessId -ErrorAction Stop
        if ($proc.MainWindowHandle -eq [IntPtr]::Zero) {
            throw "Process $ProcessId has no visible main window"
        }
        return $proc.MainWindowHandle
    }

    if ($WindowTitle) {
        $procs = Get-Process | Where-Object {
            $_.MainWindowTitle -like "*$WindowTitle*" -and $_.MainWindowHandle -ne [IntPtr]::Zero
        }
        if (-not $procs) {
            throw "No window found matching title '*$WindowTitle*'"
        }
        return ($procs | Select-Object -First 1).MainWindowHandle
    }

    throw "Must specify -Pid or -Title"
}

try {
    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    if ($FullScreen) {
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen
        $bounds = $screen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
        $graphics.Dispose()
        $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()

        Write-Output (ConvertTo-Json @{
            success = $true
            path    = $OutputPath
            width   = $bounds.Width
            height  = $bounds.Height
            method  = "fullscreen"
        })
        exit 0
    }

    $hwnd = Find-WindowHandle -ProcessId $ProcessId -WindowTitle $Title

    $rect = New-Object Screenshot.Win32+RECT
    [void][Screenshot.Win32]::GetWindowRect($hwnd, [ref]$rect)

    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top

    if ($width -le 0 -or $height -le 0) {
        throw "Window has invalid dimensions: ${width}x${height}"
    }

    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $hdc = $graphics.GetHdc()

    # PrintWindow with PW_RENDERFULLCONTENT (0x2) for better DWM capture
    $result = [Screenshot.Win32]::PrintWindow($hwnd, $hdc, 0x2)

    $graphics.ReleaseHdc($hdc)
    $graphics.Dispose()

    if (-not $result) {
        $bitmap.Dispose()
        throw "PrintWindow failed for handle $hwnd"
    }

    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()

    Write-Output (ConvertTo-Json @{
        success = $true
        path    = $OutputPath
        width   = $width
        height  = $height
        method  = "PrintWindow"
    })

} catch {
    Write-Error "Screenshot capture failed: $_"
    exit 1
}
