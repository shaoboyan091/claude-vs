# GPU Profiling Tools Survey

## GPUView (ETW-based)

Part of Windows SDK (Windows Performance Toolkit).

```cmd
# Record GPU trace
gpuview.exe  # Launch UI to start/stop recording

# Or use log.cmd from Windows SDK
cd "C:\Program Files (x86)\Windows Kits\10\Windows Performance Toolkit\gpuview"
log.cmd      # Start recording
log.cmd      # Run again to stop, opens GPUView

# Alternative: xperf-based collection
xperf -start -on DX -f gpu_trace.etl
xperf -stop
gpuview gpu_trace.etl
```

Shows: GPU queue packets, DMA buffers, present queue, Vsync timing, hardware queue depth.

## Windows Performance Recorder/Analyzer (WPR/WPA)

```cmd
# Record with GPU profile
wpr -start GPU -start GeneralProfile
# ... reproduce issue ...
wpr -stop output.etl

# Open in WPA
wpa output.etl
```

WPA GPU graphs: GPU Utilization, Video Memory, DMA Packet Duration, Display Vsync.

## DirectX Diagnostic (dxdiag)

```cmd
# Launch UI
dxdiag

# Save report to file (no UI)
dxdiag /t dxinfo.txt
dxdiag /x dxinfo.xml
```

Reports: adapter info, driver version, feature levels, display modes, DirectX runtime version.

## D3D12 Debug Layer

Enable programmatically or via environment:

```cmd
# Enable via DXGI debug (requires Windows Graphics Tools optional feature)
# Settings > Apps > Optional Features > Graphics Tools

# In code: ID3D12Debug::EnableDebugLayer()
# Environment variable for some apps:
set D3D_DEBUG=1
```

Validates: resource states, descriptor heaps, command list usage, GPU-based validation (GBV).

## Vulkan Validation Layers

```cmd
# Enable via environment
set VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation
set VK_LAYER_ENABLES=VK_VALIDATION_FEATURE_ENABLE_DEBUG_PRINTF_EXT

# Or configure via vkconfig (Vulkan Configurator from LunarG SDK)
vkconfig
```

Layer locations: `%VULKAN_SDK%\Bin\VkLayer_khronos_validation.dll`

## Chrome GPU diagnostics

```
chrome://gpu          # Adapter info, feature status, driver bugs applied
chrome://tracing      # Record trace categories: gpu, viz, cc, skia
chrome://flags        # Override GPU features
```

```cmd
# Launch Chrome with specific GPU tracing
chrome.exe --enable-tracing=gpu,viz --trace-startup-duration=5
```

## ANGLE Renderer Info

```
chrome://gpu    # Shows ANGLE backend (D3D11, Vulkan, OpenGL)
                # "GL_RENDERER" field shows active ANGLE path
```

```cmd
# Force ANGLE backend
chrome.exe --use-angle=d3d11
chrome.exe --use-angle=vulkan
chrome.exe --use-angle=gl
```

## Tool Comparison

| Tool | Platform | GPU API | Live/Post | Install |
|------|----------|---------|-----------|---------|
| GPUView | Windows | All (kernel-level) | Post | Windows SDK |
| WPR/WPA | Windows | All (kernel-level) | Post | Windows SDK |
| dxdiag | Windows | DirectX | N/A (info only) | Built-in |
| D3D12 Debug Layer | Windows | D3D12 | Live | Graphics Tools feature |
| Vulkan Validation | Cross-platform | Vulkan | Live | LunarG SDK |
| chrome://tracing | Cross-platform | Chrome's GPU stack | Post | Built into Chrome |
