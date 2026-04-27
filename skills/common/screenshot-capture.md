# Screenshot Capture

## When to Use

- Need visual evidence of window state (pass/fail, rendering artifacts)
- Capturing UI state for bug reports
- Automated visual comparison testing

## Prerequisites

- Windows (uses built-in APIs)
- PowerShell 5.1+ or scripts from `.\scripts\`

## Workflow

### 1. Capture by PID

```powershell
.\scripts\screenshot-capture.ps1 -PID 1234 -Output "C:\captures\window.png"
```

### 2. Capture by window title

```powershell
.\scripts\screenshot-capture.ps1 -Title "WebGL Aquarium" -Output "C:\captures\aquarium.png"
```

### 3. Capture fullscreen (entire display)

```powershell
.\scripts\screenshot-capture.ps1 -Fullscreen -Output "C:\captures\desktop.png"

# Specific monitor
.\scripts\screenshot-capture.ps1 -Fullscreen -Monitor 1 -Output "C:\captures\monitor1.png"
```

### 4. Inline PowerShell (no script dependency)

```powershell
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Full screen
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
$bmp.Save("C:\captures\screen.png")
$gfx.Dispose(); $bmp.Dispose()
```

### 5. Capture with delay (wait for render)

```powershell
.\scripts\screenshot-capture.ps1 -Title "Chrome" -Delay 3 -Output "C:\captures\chrome.png"
```

### 6. Batch capture (multiple windows)

```powershell
Get-Process chrome | Where-Object { $_.MainWindowTitle } | ForEach-Object {
    .\scripts\screenshot-capture.ps1 -PID $_.Id -Output "C:\captures\chrome_$($_.Id).png"
}
```

## Expected Output

- PNG file of the target window or full screen
- Exit code 0 on success, non-zero if window not found

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Window not found" | Verify PID/title; window may be minimized |
| Black screenshot | Window may be occluded or using DWM composition; try `-Fullscreen` |
| DPI scaling issues | Add `-DpiAware` flag or set process DPI awareness |
| Minimized window | Restore window first: `Show-Window -PID 1234` |
