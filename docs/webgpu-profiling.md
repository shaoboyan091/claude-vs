# WebGPU Profiling

## Dawn Built-in Timing Queries

```cpp
// Create query set for timestamps
wgpu::QuerySetDescriptor desc;
desc.type = wgpu::QueryType::Timestamp;
desc.count = 2;
auto querySet = device.CreateQuerySet(&desc);

// Write timestamps in pass
pass.WriteTimestamp(querySet, 0); // start
// ... GPU work ...
pass.WriteTimestamp(querySet, 1); // end

// Resolve to buffer
encoder.ResolveQuerySet(querySet, 0, 2, resolveBuffer, 0);
```

Enable in Chrome:
```cmd
chrome.exe --enable-dawn-features=allow_unsafe_apis
```

## Chrome DevTools Performance Panel

1. Open DevTools (F12) > Performance tab
2. Enable "GPU" in timeline settings
3. Record and look for GPU rasterization, compositing, WebGPU command submission

Traces show: command buffer recording, queue submit, buffer mapping latency.

## RenderDoc with Dawn

Dawn compiles to D3D12 or Vulkan natively. RenderDoc captures the underlying API calls.

```cmd
# Launch Chrome under RenderDoc
renderdoccmd capture chrome.exe --disable-gpu-sandbox --gpu-startup-dialog

# Or attach to running Chrome GPU process
renderdoccmd inject --PID=<gpu_process_pid>
```

Requirements:
- `--disable-gpu-sandbox` (RenderDoc needs access to GPU process)
- `--gpu-startup-dialog` (pauses GPU process for attach)
- Dawn Vulkan backend preferred for RenderDoc (D3D12 works but less mature in RenderDoc)

## PIX for Dawn D3D12 Backend

```cmd
# Force D3D12 backend
chrome.exe --use-webgpu-adapter=d3d12 --disable-gpu-sandbox

# Launch under PIX
# Use PIX UI: Launch > select chrome.exe with args above
# Or programmatic capture via PIX markers in Dawn
```

```cmd
# Enable PIX GPU capture for Dawn
chrome.exe --enable-dawn-features=emit_hlsl_debug_symbols,use_dxc --disable-gpu-sandbox
```

## Nsight for Dawn Vulkan Backend

```cmd
# Force Vulkan backend
chrome.exe --use-webgpu-adapter=vulkan --disable-gpu-sandbox

# Launch from Nsight Graphics
# Activity: Frame Debugger or GPU Trace
# Application: chrome.exe
# Arguments: --use-webgpu-adapter=vulkan --disable-gpu-sandbox --url=http://localhost:8080
```

## chrome://gpu for Adapter Info

Displays:
- WebGPU adapter (vendor, architecture, driver version)
- Backend in use (D3D12, Vulkan, Metal)
- Feature flags enabled/disabled
- Dawn toggle states

## Debug Markers via --enable-dawn-features

```cmd
# Enable debug markers (visible in PIX/RenderDoc/Nsight)
chrome.exe --enable-dawn-features=use_user_defined_labels_in_backend

# Combine multiple features
chrome.exe --enable-dawn-features=allow_unsafe_apis,use_user_defined_labels_in_backend,emit_hlsl_debug_symbols
```

In WebGPU code:
```javascript
pass.pushDebugGroup("MyRenderPass");
pass.draw(vertexCount);
pass.popDebugGroup();
```

These labels appear in external profilers when `use_user_defined_labels_in_backend` is active.

## Tool Selection Guide

| Goal | Tool | Backend |
|------|------|---------|
| Frame timing | Dawn timestamp queries | Any |
| JS/GPU correlation | Chrome DevTools | Any |
| Draw call inspection | RenderDoc | Vulkan preferred |
| D3D12 detailed profiling | PIX | D3D12 |
| NVIDIA-specific metrics | Nsight | Vulkan |
| Quick adapter check | chrome://gpu | Any |
