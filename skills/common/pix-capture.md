# PIX Capture

## When to Use

- Need D3D12 frame analysis (GPU timing, resource state, shader debug)
- Profiling D3D12 draw call performance
- Debugging D3D12 validation errors or GPU hangs

## Prerequisites

- PIX installed (https://devblogs.microsoft.com/pix/download/)
- Windows Developer Mode enabled (Settings > For Developers)
- Application uses D3D12
- `WinPixEventRuntime.dll` or `WinPixGpuCapturer.dll` available

## Workflow

### 1. DLL injection approach (programmatic capture)

The app loads PIX's capture DLL at startup:

```cpp
// In app code or via environment variable
#include <pix3.h>
PIXLoadLatestWinPixGpuCapturerLibrary();
```

Or set environment variable before launch:

```powershell
$env:PIX_CAPTURE_DLL = "C:\Program Files\Microsoft PIX\WinPixGpuCapturer.dll"
```

### 2. Launch from PIX UI

1. Open PIX
2. Select "Launch Win32" or "Attach"
3. Set executable path and arguments
4. Click "GPU Capture" to start session
5. Press **PrintScreen** or click capture button for a frame

### 3. Environment variables for headless capture

```powershell
# Force PIX capture on specific frames
$env:PIX_CAPTURE_ON_FRAME = "100"
$env:PIX_CAPTURE_OUTPUT = "C:\captures\"
```

### 4. Timing capture (profiling)

1. In PIX, select "Timing Capture"
2. Run workload
3. Stop capture
4. Analyze GPU/CPU timelines, queue utilization

### 5. Analyze capture

- Event list: walk D3D12 commands
- Pipeline state at each draw/dispatch
- Resource viewer: textures, buffers, descriptors
- Shader debugger: step through HLSL

## Limitations

- **D3D12 only** (no D3D11, Vulkan, or OpenGL)
- No full CLI for automated capture (UI-driven workflow)
- Requires Developer Mode or PIX DLL injection
- Some anti-cheat software blocks PIX hooks

## Expected Output

- `.wpix` capture file
- GPU timing data per draw/dispatch
- Full D3D12 pipeline state inspection

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Developer Mode not enabled" | Settings > For Developers > toggle on |
| DLL injection fails | Verify DLL path; run app as same user as PIX |
| No GPU data in timing | Update GPU driver; ensure D3D12 device created |
| Capture is empty | App may not present frames; check swapchain |
| PIX crashes on replay | Update PIX; try on different driver version |
