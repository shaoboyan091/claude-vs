# Pixel-Level Screenshot Capture Methods

## PrintWindow Win32 API

Used in screenshot.ps1. Captures window content even if partially occluded.

```powershell
# PowerShell using PrintWindow
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
public struct RECT { public int Left, Top, Right, Bottom; }
"@
# flags: 0 = client area, 2 = PW_RENDERFULLCONTENT (composited/DX content)
```

- Works with: standard Win32 windows, WPF
- Fails with: some DX12 exclusive fullscreen, UWP apps (may return black)

## BitBlt Alternative

Captures from screen DC (window must be visible and unoccluded).

```powershell
Add-Type -AssemblyName System.Drawing
$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0, 0, 0, 0, $bounds.Size)
$bmp.Save("screenshot.png")
```

- Faster than PrintWindow
- Cannot capture occluded windows

## DWM Thumbnail API

Registers a live thumbnail of another window (read-only rendered copy).

- API: `DwmRegisterThumbnail`, `DwmUpdateThumbnailProperties`
- Use case: live preview without capturing to file
- Cannot directly save to bitmap without additional rendering step

## Windows.Graphics.Capture API (Modern)

Most capable method. Captures DX content, UWP apps, works with HDR.

```powershell
# Requires Windows 10 1903+, UWP capability, or Win32 with GraphicsCaptureItem interop
# PowerShell wrapper not native; use C# or C++/WinRT

# Minimal C# usage:
# var item = CaptureHelper.CreateItemForWindow(hwnd);
# var pool = Direct3D11CaptureFramePool.Create(device, format, 1, size);
# var session = pool.CreateCaptureSession(item);
# session.StartCapture();
```

- Requires user consent (yellow border indicator on Win10, removable on Win11)
- Works with all window types including DX12 and UWP

## Chrome Headless Screenshot

```cmd
# Capture page screenshot
chrome.exe --headless --screenshot="output.png" --window-size=1920,1080 https://example.com

# Specific element or full page
chrome.exe --headless --screenshot --full-page-screenshot https://example.com
```

## Puppeteer / CDP Screenshot Protocol

```javascript
const browser = await puppeteer.launch();
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080 });
await page.goto('http://localhost:8080');
await page.screenshot({ path: 'output.png', fullPage: true });

// Specific element
const el = await page.$('#canvas');
await el.screenshot({ path: 'canvas.png' });
```

CDP command directly:
```json
{"method": "Page.captureScreenshot", "params": {"format": "png", "clip": {"x":0,"y":0,"width":800,"height":600,"scale":1}}}
```

## Comparison Table

| Method | Occluded Windows | DX/GPU Content | UWP Apps | Headless | Pixel Accuracy |
|--------|:---:|:---:|:---:|:---:|:---:|
| PrintWindow (PW_RENDERFULLCONTENT) | Yes | Partial | No | Yes | High |
| BitBlt | No | No | No | No | High |
| DWM Thumbnail | Yes | Yes | Yes | No | High |
| Windows.Graphics.Capture | Yes | Yes | Yes | Yes* | Exact |
| Chrome --screenshot | N/A | N/A | N/A | Yes | Exact |
| Puppeteer/CDP | N/A | N/A | N/A | Yes | Exact |

*Requires programmatic consent bypass or Win11 borderless mode.

## Recommendations

- **Automating browser screenshots**: Puppeteer/CDP (most reliable, pixel-perfect)
- **Capturing native app windows**: Windows.Graphics.Capture (most capable) or PrintWindow (simpler, no UWP dependency)
- **Quick full-screen grab**: BitBlt (fast, simple, but window must be visible)
