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
.\src\util\screenshot.ps1 -ProcessId 1234 -OutputPath "C:\captures\window.png"
```

### 2. Capture by window title

```powershell
.\src\util\screenshot.ps1 -Title "WebGL Aquarium" -OutputPath "C:\captures\aquarium.png"
```

### 3. Capture fullscreen (entire display)

```powershell
.\src\util\screenshot.ps1 -Fullscreen -OutputPath "C:\captures\desktop.png"
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

### 5. Batch capture (multiple windows)

```powershell
Get-Process chrome | Where-Object { $_.MainWindowTitle } | ForEach-Object {
    .\src\util\screenshot.ps1 -ProcessId $_.Id -OutputPath "C:\captures\chrome_$($_.Id).png"
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
| DPI scaling issues | Set process DPI awareness before capture |
| Minimized window | Restore window first: `Show-Window -PID 1234` |
