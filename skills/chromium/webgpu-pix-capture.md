# WebGPU PIX Capture

## When to Use

- Need to capture D3D12 calls from Chrome's WebGPU (Dawn) backend
- Debugging WebGPU rendering issues at the D3D12 level
- Profiling Dawn's D3D12 command submission

## Prerequisites

- PIX installed with Developer Mode enabled
- Chrome build with Dawn D3D12 backend
- Understanding: WebGPU -> Dawn -> D3D12 -> GPU

## Architecture

```
JavaScript WebGPU API
    -> Dawn (Chrome's WebGPU implementation)
        -> D3D12 backend (dawn_native_d3d12)
            -> D3D12 Runtime
                -> GPU Driver
```

PIX captures at the D3D12 Runtime level.

## Workflow

### 1. Launch Chrome with required flags

```powershell
chrome.exe --enable-unsafe-webgpu ^
  --disable-gpu-sandbox ^
  --disable-gpu-watchdog ^
  --enable-features=Vulkan,UseSkiaRenderer ^
  --use-webgpu-adapter=d3d12 ^
  --disable-dawn-features=disallow_unsafe_apis
```

### 2. PIX DLL injection approach

#### Option A: Environment variable (before Chrome launch)

```powershell
$env:DAWN_PIX_PATH = "C:\Program Files\Microsoft PIX\WinPixGpuCapturer.dll"
chrome.exe --enable-unsafe-webgpu --disable-gpu-sandbox
```

Dawn will load the PIX DLL automatically if `DAWN_PIX_PATH` is set.

#### Option B: Launch GPU process from PIX

1. Launch Chrome with `--gpu-startup-dialog`
2. Note GPU process PID from dialog
3. In PIX, attach to that PID
4. Click OK in Chrome dialog to resume

### 3. Navigate to WebGPU content

Open the WebGPU page (e.g., `https://webgpusamples.org/`).

### 4. Capture frame

- In PIX: click GPU Capture button or press **PrintScreen**
- Frame captures all D3D12 calls from Dawn for that frame

### 5. Analyze capture

- Event list shows Dawn's D3D12 commands (CreateCommittedResource, ExecuteCommandLists, etc.)
- Look for Dawn's label annotations (render pass names)
- Check resource states and barriers
- Profile GPU timing per render pass

## Key Dawn-PIX Integration

Dawn emits PIX markers for render/compute passes:
- `BeginRenderPass` / `EndRenderPass`
- `BeginComputePass` / `EndComputePass`
- Label annotations from `GPURenderPassDescriptor.label`

## Expected Output

- `.wpix` capture with D3D12 commands from Dawn
- Per-pass GPU timing breakdown
- Resource state and barrier analysis

## Troubleshooting

| Issue | Fix |
|-------|-----|
| PIX DLL not loaded | Verify `DAWN_PIX_PATH`; check Dawn build has PIX support |
| No D3D12 calls in capture | Ensure `--use-webgpu-adapter=d3d12` (not Vulkan) |
| Sandbox blocks PIX | Must use `--disable-gpu-sandbox` |
| Empty capture | WebGPU page may not be rendering; check console for errors |
| Dawn falls back to Vulkan | Force D3D12: `--enable-features=SkiaGraphite --use-webgpu-adapter=d3d12` |
| GPU watchdog kills process | Add `--disable-gpu-watchdog` |
