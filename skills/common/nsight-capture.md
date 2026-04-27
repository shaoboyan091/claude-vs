# Nsight Graphics Capture

## When to Use

- Need NVIDIA GPU trace, frame debug, or shader profiling
- Analyzing GPU performance counters (SM occupancy, memory throughput)
- Debugging ray tracing or mesh shader workloads

## Prerequisites

- NVIDIA Nsight Graphics installed
- NVIDIA GPU with recent driver (Game Ready or Studio)
- `ngfx.exe` CLI on PATH (default: `C:\Program Files\NVIDIA Corporation\Nsight Graphics\`)

## Workflow

### 1. Launch with ngfx CLI

```powershell
# Frame capture
ngfx.exe --activity "Frame Debugger" --exe "C:\path\to\app.exe" --args "--arg1"

# GPU trace (performance)
ngfx.exe --activity "GPU Trace" --exe "C:\path\to\app.exe"

# Capture specific frame
ngfx.exe --activity "Frame Debugger" --exe "app.exe" --frame 200
```

### 2. Activity types

| Activity | Purpose |
|----------|---------|
| Frame Debugger | Inspect draw calls, shaders, resources |
| GPU Trace | Performance profiling (SM, memory, L2) |
| Shader Profiler | Per-warp shader performance |
| Ray Tracing | BVH visualization, ray stats |

### 3. Attach to running process

```powershell
ngfx.exe --activity "Frame Debugger" --attach --pid 1234
```

### 4. Automated capture (headless)

```powershell
# Capture frame 50, save report
ngfx.exe --activity "Frame Debugger" ^
  --exe "app.exe" ^
  --frame 50 ^
  --output "C:\captures\frame50.ngfx" ^
  --headless
```

### 5. Analyze in UI

- Scrubber: navigate draw calls/dispatches
- Shader view: HLSL/SPIRV source with perf annotations
- Resource inspector: textures, buffers, acceleration structures
- GPU Trace timeline: SM warps, memory transactions, stalls

## Limitations

- **NVIDIA GPUs only**
- Requires recent NVIDIA driver (check Nsight release notes for minimum)
- Some features require specific GPU architecture (e.g., ray tracing needs Turing+)
- May conflict with other GPU hooks (RenderDoc, Steam overlay)

## Expected Output

- `.ngfx` capture file
- GPU Trace report with per-unit metrics
- Shader profiling data with hotspot identification

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "No compatible GPU found" | Update NVIDIA driver; verify NVIDIA GPU is primary |
| Connection timeout on attach | Disable other GPU overlays; run as Admin |
| Missing perf counters in trace | Ensure no other profiler is attached |
| App crashes on launch | Try `--force-repaint off`; check driver compatibility |
| Vulkan layers conflict | Set `VK_INSTANCE_LAYERS` to empty before launch |
