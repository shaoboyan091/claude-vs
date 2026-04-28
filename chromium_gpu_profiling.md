# Chromium GPU Process Profiling

## Environment
- Chrome debug build: `C:\work\cr\src\out\debug_full_x64\chrome.exe`
- Launch flags: `--enable-unsafe-webgpu --no-sandbox`
- GPU Process PID: 14848
- OS: Windows 10.0.26200.7985 (MINGW64/x64)
- Debugger: cdb.exe 10.0.26100.3323

## Observed Facts

### Process Resource Usage (idle, no WebGPU content active)

| Metric | Value |
|--------|-------|
| Working Set | 252-264 MB |
| Private Memory | 115-121 MB |
| Virtual Memory | ~7.3 GB |
| CPU Time (accumulated) | 2.19s |
| Handle Count | 435-437 |
| Thread Count | 43-48 |
| Start Time | 2026-04-28 14:03:00 |

### Loaded Modules (Chromium, from debug build)

Key GPU-related modules loaded in the GPU process:

| Module | Size (approx) |
|--------|---------------|
| gpu_gles2.dll | 16 MB |
| components_viz_service.dll | 26 MB |
| gpu.dll | 2 MB |
| gpu_config.dll | 2 MB |
| gpu_ipc_service.dll | 1.2 MB |
| gpu_command_buffer_service.dll | 0.7 MB |
| gpu_command_buffer_client.dll | 0.5 MB |
| gpu_webgpu.dll | 0.2 MB |
| media_gpu.dll | 18 MB |
| content.dll | (loaded for process init) |
| base.dll | 13 MB |
| vk_swiftshader.dll | 11 MB |
| dxcompiler.dll | 54 MB |
| dxil.dll | 1.5 MB |
| D3DCompiler_47.dll | 4.5 MB |

Key system/driver modules:

| Module | Description |
|--------|-------------|
| igc64.dll | Intel GPU Compiler (83 MB) |
| igdgmm64.dll | Intel GMM |
| igd11dxva64.dll | Intel D3D11 DXVA |
| d3d11.dll | D3D11 Runtime |
| dxgi.dll | DXGI |

### Thread Structure (from `~*k` stack dump)

**Thread 0 - "CrGpuMain"**: Main GPU process thread
```
ntdll!NtWaitForSingleObject
KERNELBASE!WaitForSingleObjectEx
base!base::WaitableEvent::TimedWaitImpl
base!base::WaitableEvent::TimedWait
base!base::MessagePumpDefault::Run
base!base::sequence_manager::internal::ThreadControllerWithMessagePumpImpl::Run
base!base::RunLoop::Run
content!content::GpuMain
content!content::RunOtherNamedProcessTypeMain
content!content::ContentMainRunnerImpl::Run
content!content::RunContentProcess
content!content::ContentMain
chrome!ChromeMain
chrome_exe!MainDllLoader::Launch
chrome_exe!wWinMain
```

**Thread 19 - "VizCompositorThread"**: Viz compositor
```
ntdll!NtRemoveIoCompletion
KERNELBASE!GetQueuedCompletionStatus
base!base::MessagePumpForIO::GetIOItem
base!base::MessagePumpForIO::WaitForIOCompletion
base!base::MessagePumpForIO::WaitForWork
base!base::MessagePumpForIO::DoRunLoop
base!base::MessagePumpWin::Run
base!base::sequence_manager::internal::ThreadControllerWithMessagePumpImpl::Run
base!base::RunLoop::Run
base!base::Thread::Run
base!base::Thread::ThreadMain
base!base::`anonymous namespace'::ThreadFunc
KERNEL32!BaseThreadInitThunk
```

**Thread 20 - "Window owner thread"**: Windows message pump
```
win32u!NtUserMsgWaitForMultipleObjectsEx
base!base::MessagePumpForUI::WaitForWork
```

**Thread 21 - "GpuVSyncThread"**: VSync signal handling

### Intel GPU Driver Stack

The system has Intel integrated GPU drivers loaded:
- igc64.dll (compiler, 83MB)
- igdgmm64.dll (memory manager)
- igd11dxva64.dll (video acceleration)
- igddxvacommon64.dll (common DXVA)
- media_bin_64.dll (media kernels, 33MB)
- igdml64.dll (machine learning)
- IntelControlLib.dll
- igdext64.dll
- igdgmm2_64.dll
- igdinfo64.dll

## Inferences

1. **Idle state profile**: At idle (no WebGPU/rendering), the GPU process uses 252MB working set. The 7.3GB virtual address space is largely due to DLL mappings (igc64 alone is 83MB, components_viz_service is 26MB, dxcompiler is 54MB).

2. **IO completion port architecture**: VizCompositorThread uses an IO completion port (`GetQueuedCompletionStatus`) for async IPC, consistent with Chromium's mojo infrastructure.

3. **Message pump hierarchy**: CrGpuMain uses `MessagePumpDefault` (waitable event based), while VizCompositorThread uses `MessagePumpForIO` (IOCP based), and window thread uses `MessagePumpForUI` (Win32 message loop).

4. **Swiftshader loaded as fallback**: `vk_swiftshader.dll` is loaded alongside real Intel GPU drivers, likely as a Vulkan software fallback.

5. **DXC compiler loaded**: Both `dxcompiler.dll` (54MB) and `D3DCompiler_47.dll` (4.5MB) are loaded, suggesting both DXIL and legacy DXBC shader compilation paths are available.

## Unresolved Questions

1. **No active GPU workload captured**: Without WebGPU content running, GPU utilization was near zero. Power/thermal profiling would require sustained rendering.

2. **WPR/ETW profiling not attempted**: `wpr.exe` (Windows Performance Recorder) was not used due to the already long debug session times and because meaningful profiling requires an active workload.

3. **GPU hardware counters**: Intel GPU performance counters (via Intel GPA or similar) were not accessed through this debugging approach.

4. **Thread purpose for remaining 40+ threads**: Only 4 named threads were identified. The remaining threads may be driver threads, thread pool workers, or IPC threads.
