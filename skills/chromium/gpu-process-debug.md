# Chrome GPU Process Debug

## When to Use

- Chrome GPU process crashes or hangs
- Need to inspect GPU command buffer state
- Debugging Dawn/ANGLE rendering issues in Chrome
- Investigating TDR (Timeout Detection and Recovery) events

## Prerequisites

- Chrome Debug build (or official with symbols)
- WinDbg or cdb.exe installed
- Chrome source symbols available
- Environment setup: run `C:\work\EnvStartUp` bat files first

## Environment Setup

```powershell
# Initialize build environment
& "C:\work\EnvStartUp\env_chromium.bat"
# Or for component build:
& "C:\work\EnvStartUp\env_chromium_component.bat"
```

## Workflow

### 1. Launch Chrome with GPU startup dialog

```powershell
chrome.exe --gpu-startup-dialog --enable-logging=stderr --v=1
```

Chrome will display a dialog: "GPU process has pid XXXX, waiting for debugger."

### 2. Find the GPU process PID

The dialog shows the PID directly. Alternatively:

```powershell
.\scripts\find-process.ps1 -Name "chrome" -Type "GPU"
# Or: look for chrome.exe with --type=gpu-process in command line
Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" |
  Where-Object { $_.CommandLine -match "--type=gpu-process" } |
  Select-Object ProcessId
```

### 3. Attach WinDbg

```powershell
.\scripts\windbg-attach.ps1 -PID <gpu_pid>

# Or manually:
windbg -p <gpu_pid> -srcpath C:\work\chromium\src -y "srv*C:\symbols*https://msdl.microsoft.com/download/symbols;C:\work\chromium\src\out\Debug"
```

### 4. Set symbols and continue

```
.sympath+ C:\work\chromium\src\out\Debug
.srcpath C:\work\chromium\src
.reload /f
g
```

Click OK on the startup dialog to resume the GPU process.

### 5. Common GPU crash signatures

```
# D3D device lost
bp d3d11!CDevice::RemoveDevice
bp dxgi!CDXGISwapChain::Present

# Dawn/WebGPU crashes
bp dawn_native!dawn::native::d3d12::Device::HandleError
bp dawn_native!dawn::native::Device::ConsumedError

# ANGLE crashes
bp libGLESv2!rx::Renderer11::handleDeviceLost
bp libEGL!egl::Display::handleDeviceLost

# Command buffer errors
bp gpu!gpu::CommandBufferHelper::Flush
```

### 6. Useful debug commands at break

```
# Full stack
k 50
# All threads
~*k
# GPU command buffer state
dt gpu::CommandBufferProxyImpl <addr>
# Check HRESULT
? <register_with_hr>
!error <hr_value>
```

## Expected Output

- Stack trace showing GPU crash root cause
- HRESULT error code identifying D3D failure mode
- Memory dump for offline analysis if needed

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Startup dialog doesn't appear | Ensure `--gpu-startup-dialog` flag is first GPU flag |
| GPU process restarts before attach | Add `--disable-gpu-watchdog` to prevent kill |
| Symbols not loading | Verify out/Debug directory; run `.reload /f` |
| Multiple GPU processes | Use `--single-process` for simpler debugging (not representative) |
| "Access denied" on attach | Run WinDbg as Administrator |
| Sandbox blocks debugging | Add `--no-sandbox` or `--disable-gpu-sandbox` |
