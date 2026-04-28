# Dawn ComputeBoids GPU Profiling

## Observed Facts

### Process Metrics

**Sample 1** (5 seconds after launch, two instances running):

| PID   | Working Set | Private Memory | CPU Time | Threads |
|-------|-------------|----------------|----------|---------|
| 25616 | 269 MB      | 309 MB         | 2.48 s   | 37      |
| 26568 | 263 MB      | 306 MB         | 150.98 s | 32      |

**Sample 2** (15 seconds after launch):

| PID   | Working Set | Private Memory | CPU Time | Threads |
|-------|-------------|----------------|----------|---------|
| 25616 | 257 MB      | 295 MB         | 3.23 s   | 36      |
| 26568 | 250 MB      | 291 MB         | 151.73 s | 32      |

**Note**: PID 26568 had accumulated 151s of CPU time — this was a previously launched instance that had been running for a while.

**Sample 3** (fresh launch, 8 seconds):

| PID  | Working Set | Private Memory | CPU Time | Threads | Handles |
|------|-------------|----------------|----------|---------|---------|
| N/A  | 86 MB       | 63 MB          | 0.52 s   | 19      | —       |

### Memory Profile

- Working set stabilizes around 250-270 MB for a running instance
- Private memory is slightly higher at 290-310 MB (committed virtual memory including GPU-visible allocations)
- Fresh instance starts at ~86 MB working set, growing as GPU resources are allocated
- The ~14 MB gap between working set and private memory suggests some pages are shared (DLLs) or paged out

### Thread Count

- Mature instance: 32-37 threads
- Fresh instance: 19 threads (additional threads spawned during GPU initialization)

### CPU Usage Pattern

Between samples 1 and 2 (10 second gap):
- PID 25616: CPU went from 2.48s to 3.23s → **0.075s CPU per second** (7.5% of one core)
- PID 26568: CPU went from 150.98s to 151.73s → **0.075s CPU per second** (7.5% of one core)

Both instances show identical per-second CPU usage, indicating the render loop has consistent CPU overhead regardless of total runtime.

### Module Footprint

From ComputeBoids module list:
- `dawn_native.dll`: 33.4 MB (largest Dawn module, contains all backend implementations)
- `ComputeBoids_exe`: 753 KB (the sample itself is tiny)
- GPU driver modules loaded:
  - Intel igc64.dll: ~83 MB (shader compiler)
  - Intel igd10umt64xe.DLL: ~25 MB (user-mode driver)
  - NVIDIA nvwgf2umx.dll: ~83 MB (user-mode driver)
  - NVIDIA nvgpucomp64.dll: ~147 MB (GPU compute library)
  - Vulkan: `vk_swiftshader.dll` (8 MB), `vulkan-1.dll`, `igvk64.dll`

### ComputeBoids Execution Stack

From breakpoint on Queue::SubmitImpl:
```
dawn_native!dawn::native::d3d12::Queue::SubmitImpl
dawn_native!dawn::native::QueueBase::SubmitInternal+0x470
dawn_native!dawn::native::QueueBase::APISubmit+0x51
dawn_native!dawn::native::NativeQueueSubmit+0x94
dawn_proc!wgpuQueueSubmit+0x2b
ComputeBoids_exe!wgpu::Queue::Submit+0x43
ComputeBoids_exe!ComputeBoidsSample::FrameImpl+0xc9
ComputeBoids_exe!SampleBase::Run+0x997
ComputeBoids_exe!main+0x6e
```

The render loop is: `main` → `SampleBase::Run` (event loop, +0x997 suggests message pump) → `ComputeBoidsSample::FrameImpl` (per-frame work) → queue submit.

### GPU Backend Selection

ComputeBoids uses D3D12 backend by default (first available backend). The system has:
- Intel Arc (integrated, xe-lpg architecture)
- NVIDIA RTX 2000 Ada (discrete, lovelace architecture)

Both D3D12 and Vulkan backends are available. Dawn likely selects the discrete GPU by default for standalone samples.

## Inferences

1. **CPU-light, GPU-heavy workload**: At 7.5% single-core CPU usage per frame loop, the application spends most of its time waiting for GPU work to complete or vsync. The compute boids simulation runs primarily on the GPU.

2. **Memory dominated by GPU drivers**: The process's 250+ MB working set is largely GPU driver memory (Intel igc + NVIDIA drivers alone account for ~330 MB of loaded module space). Dawn's own memory footprint is modest.

3. **Thread proliferation**: 32-37 threads for a simple particle simulation suggests driver thread pools, D3D12 background work (shader compilation, memory management), and Dawn's internal threading.

4. **Single-submission frame model**: ComputeBoids submits one command buffer per frame via `FrameImpl`. This is a simple frame structure without multi-queue or async compute overlap.

5. **Working set reduction over time** (269→257 MB) suggests the OS is trimming unused pages as the steady-state allocation pattern stabilizes.

## Unresolved Questions

1. **GPU utilization**: Without GPU-specific profiling tools (PIX, NSight), we cannot measure actual GPU occupancy, shader execution time, or memory bandwidth usage.

2. **Frame timing**: We observed CPU time per second but couldn't measure frame-to-frame timing or vsync behavior without instrumenting the render loop or using ETW tracing.

3. **Compute vs render split**: ComputeBoids runs a compute shader for particle simulation and a render pass for visualization. We couldn't measure the relative GPU cost of each without GPU timeline profiling.

4. **VRAM allocation**: Private memory (291-309 MB) includes committed virtual pages but doesn't directly reveal dedicated GPU memory usage. D3D12 budget/residency information would require DXGI query APIs.

5. **Thread stack profiling**: The attach-mode stack capture caught the process during initialization rather than steady-state execution, so we couldn't observe thread roles during active rendering.
