# RenderDoc Capture

## When to Use

- Need GPU frame capture for D3D11, D3D12, Vulkan, or OpenGL applications
- Inspecting draw calls, shader state, textures, or render targets
- Vendor-agnostic GPU debugging (works on NVIDIA, AMD, Intel)

## Prerequisites

- RenderDoc installed (https://renderdoc.org)
- `renderdoccmd.exe` on PATH or known location (default: `C:\Program Files\RenderDoc\`)
- Target app uses a supported API (D3D11, D3D12, Vulkan, OpenGL)

## Workflow

### 1. Launch with capture enabled

```powershell
# Launch app through RenderDoc
renderdoccmd capture -w "C:\path\to\app.exe" --capture-args "--arg1 --arg2"

# Or inject into running process
renderdoccmd inject --PID 1234
```

### 2. Trigger capture

- Default hotkey: **F12** (or **PrintScreen**)
- Programmatic: `renderdoccmd capture --capture-frame 100` (capture frame 100)

### 3. Replay and inspect

```powershell
# Open capture file in UI
renderdocui.exe "C:\captures\app_frame123.rdc"
```

In the UI:
- Event Browser: walk draw calls
- Texture Viewer: inspect render targets, depth buffers
- Pipeline State: view bound resources, shaders
- Mesh Viewer: see vertex data

### 4. Export textures

```powershell
# Export all textures from a capture (CLI)
renderdoccmd cap2img -c "capture.rdc" -o "C:\export\tex_{index}.png"
```

### Key Flags

| Flag | Purpose |
|------|---------|
| `--opt-api-validation` | Enable API validation layer |
| `--opt-ref-all-resources` | Capture all resources (not just used) |
| `--opt-capture-callstacks` | Record CPU callstacks per API call |
| `--opt-delay-for-debugger` | Pause app start for debugger attach |

## Expected Output

- `.rdc` capture file containing full frame state
- Exported textures as PNG/EXR
- Full pipeline state at any draw call

## Troubleshooting

| Issue | Fix |
|-------|-----|
| No API calls captured | App may use unsupported API; check RenderDoc log |
| DXGI hooking fails | Disable overlays (Steam, Discord) that also hook DXGI |
| Black textures in replay | Use `--opt-ref-all-resources` to capture all |
| "Failed to inject" | Run as Admin; disable anti-cheat/DRM if present |
| Vulkan not detected | Ensure Vulkan layer is registered: check `VK_LAYER_PATH` |
| Crash on capture | Update GPU drivers; try `--opt-api-validation` to find bad calls |
