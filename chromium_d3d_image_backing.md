# D3DImageBacking Analysis

## Environment
- Chrome debug build: `C:\work\cr\src\out\debug_full_x64\chrome.exe`
- Launch flags: `--enable-unsafe-webgpu --no-sandbox`
- GPU Process PID: 14848 (final session)
- Debugger: cdb.exe 10.0.26100.3323
- Symbol path: `C:\work\cr\src\out\debug_full_x64`

## Observed Facts

### Module Location

`D3DImageBacking` resides in **`gpu_gles2.dll`** (loaded at `00007ff8'f2fa0000 - 00007ff8'f3f03000`, ~16MB).

A thunk for `D3DImageBackingFactory::IsD3DSharedImageSupported` also exists in `components_viz_service.dll` as an import, but all implementations live in `gpu_gles2.dll`.

Evidence (raw cdb output):
```
00007ff8`f3dd1e98 gpu_gles2!gpu::`anonymous namespace'::kD3DImageBackingLabel = "D3DImageBacking"
00007ff8`f3bab080 gpu_gles2!gpu::D3DImageBacking::`vftable'
```

### Symbol Discovery

89 unique method symbols found for `gpu::D3DImageBacking::*` (excluding templates/lambdas).
20 unique method symbols found for `gpu::D3DImageBackingFactory::*`.

### Class Public Interface (from symbol enumeration)

**Core lifecycle:**
- `~D3DImageBacking`
- `GetType`
- `Update(unique_ptr<gfx::GpuFence>*)`
- `CreateFromSwapChainBuffers` (static, takes Mailbox, format, size, color space, textures, swap chain, format caps)
- `CreateGLTexture(GLFormatDesc*, ComPtr<ID3D11Texture2D>*, uint, uint, uint)`

**D3D11 access control:**
- `BeginAccessD3D11(ComPtr<ID3D11Device>*, bool, bool)`
- `EndAccessD3D11(ComPtr<ID3D11Device>*, bool)`
- `BeginAccessCommon(bool)`
- `ValidateBeginAccess(bool)`

**Dawn/WebGPU integration:**
- `BeginAccessDawnBuffer(wgpu::Device*, wgpu::BackendType, wgpu::BufferUsage)`
- `EndAccessDawnBuffer(wgpu::Device*, wgpu::BackendType, wgpu::Buffer*)`
- `EndAccessDawn(wgpu::Device*, wgpu::Texture*)`
- `TrackBeginAccessToWGPUTexture(wgpu::Texture*)`
- `TrackEndAccessToWGPUTexture(wgpu::Texture*)`
- `GetSharedTextureMemory(wgpu::Device*)`
- `CheckForDawnDeviceLoss(wgpu::Device*, wgpu::SharedTextureMemory*)`

**DComp/Overlay/SwapChain:**
- `BeginDCompTextureAccess`
- `EndDCompTextureAccess`
- `PresentSwapChain`
- `ProduceOverlay(SharedImageManager*, MemoryTypeTracker*)`
- `GetDCLayerOverlayImage`

**Skia integration:**
- `ProduceSkiaGanesh(SharedImageManager*, MemoryTypeTracker*, scoped_refptr<SharedContextState>)`
- `ProduceSkiaGraphite(SharedImageManager*, MemoryTypeTracker*, scoped_refptr<SharedContextState>)`
- `SupportsDeferredGraphiteSubmit`
- `FlushGraphiteCommandsIfNeeded`
- `InvalidatePersistentGraphiteDawnAccess`
- `NotifyGraphiteAboutInitializedStatus`

**GL integration:**
- `ProduceGLTexturePassthrough(SharedImageManager*, MemoryTypeTracker*)`
- `GetEGLImage`
- Inner class `GLTextureHolder` with `BindEGLImageToTexture`, `MarkContextLost`, `egl_image`, `texture_passthrough`, `set_needs_rebind`

**Graphite persistent Dawn access (inner class `PersistentGraphiteDawnAccess`):**
- `BeginAccess(bool, scoped_refptr<gfx::D3DSharedFence>)`
- `FlushCommandsIfNeeded`
- `WaitForDCompBeforeWrite(scoped_refptr<gfx::D3DSharedFence>)`
- `Invalidate`
- `SetCleared(bool)`
- `SetNeedFlushCommands(bool)`
- `IsGraphiteDevice(wgpu::Device*)`
- `IsGraphiteD3D11Device(ComPtr<ID3D11Device>*)`
- `texture()`, `shared_texture_memory()`

**Staging/readback:**
- `CopyToStagingTexture`
- `GetOrCreateStagingTexture`
- `HasStagingTextureForTesting`

**Fence synchronization:**
- `use_cross_device_fence_synchronization`
- `UpdateExternalFence(scoped_refptr<gfx::D3DSharedFence>)`
- `GetPendingWaitFences(ComPtr<ID3D11Device>*, wgpu::Device*, bool)`
- `has_keyed_mutex`

**WebNN/D3D12:**
- `BeginAccessWebNN`
- `EndAccessWebNN(scoped_refptr<gfx::D3DSharedFence>)`
- `ProduceDawnBuffer(SharedImageManager*, MemoryTypeTracker*, wgpu::Device*, wgpu::BackendType, scoped_refptr<SharedContextState>)`
- `ProduceWebNNTensor(SharedImageManager*, MemoryTypeTracker*)`
- `GetD3D12Buffer`
- `SupportsAccess(SharedImageAccessStream, AccessParams*)`

**Other inner class `GraphiteTextureHolder`:**
- Constructor takes `scoped_refptr<DawnSharedTextureCache>`, `scoped_refptr<PersistentGraphiteDawnAccess>`, `skgpu::graphite::BackendTexture*`

### D3DImageBackingFactory Methods

- Constructor: `(ComPtr<ID3D11Device>, scoped_refptr<DXGISharedHandleManager>, GLFormatCaps*, GpuDriverBugWorkarounds*, bool)`
- `IsD3DSharedImageSupported(ID3D11Device*, GpuPreferences*)`
- `IsSwapChainSupported(GpuPreferences*, DawnContextProvider*)`
- `IsSupported(SharedImageUsageSet, SharedImageFormat, gfx::Size*, bool, GpuMemoryBufferType, GrContextType, span<const uint8_t>*)`
- `IsSupportedForAccessStream(SharedImageAccessStream, AccessParams*)`
- `SupportsBGRA8UnormStorage`
- `GetBackingType`
- `CreateSwapChainInternal(ComPtr<IDXGISwapChain1>*, ComPtr<ID3D11Texture2D>*, ComPtr<ID3D11Texture2D>*, SharedImageFormat, gfx::Size*)`
- `CreateGpuMemoryBufferHandle(scoped_refptr<SingleThreadTaskRunner>, gfx::Size*, SharedImageFormat, BufferUsage)`
- `CreateGpuMemoryBufferHandleOnIO(...)`
- `CopyNativeBufferToSharedMemoryAsync(GpuMemoryBufferHandle*, UnsafeSharedMemoryRegion*)`
- `ClearBackBufferToColor(IDXGISwapChain1*, SkRGBA4f<3>*)`
- vtable at `00007ff8'f3bac330`

## Inferences

1. **Multi-backend shared image hub**: D3DImageBacking is the central Windows backing for shared images, providing interop across D3D11, Dawn/WebGPU, GL (EGL), Skia Ganesh, Skia Graphite, DComp overlays, WebNN, and D3D12 buffers.

2. **Fence-based cross-device sync**: Uses `D3DSharedFence` for cross-device synchronization with keyed mutex as fallback (`has_keyed_mutex` property). The `GetPendingWaitFences` method suggests deferred fence waiting.

3. **Graphite holds persistent Dawn handles**: `PersistentGraphiteDawnAccess` inner class maintains long-lived Dawn texture/shared-texture-memory handles, avoiding per-frame acquire/release overhead.

4. **Lazy staging texture allocation**: `GetOrCreateStagingTexture` pattern indicates staging textures for CPU readback are allocated on demand.

5. **Module placement reflects real dependencies**: D3DImageBacking lives in `gpu_gles2.dll` because it directly depends on GLES2 types — the inner class `GLTextureHolder` wraps `gles2::TexturePassthrough` and EGL images. The `GPU_GLES2_EXPORT` macro is the component's export macro. While D3DImageBacking serves many backends beyond GLES2, its GL interop path makes the module placement architecturally meaningful.

## Unresolved Questions

1. **No live breakpoint captures**: No WebGPU workload was active during this session. `BeginAccessDawnBuffer`, `TrackBeginAccessToWGPUTexture` and related methods were never hit.

2. **Constructors are private (factory pattern)**: Two private constructors exist in `d3d_image_backing.h` (lines ~255 and ~273). They are not visible in cdb symbol enumeration because they are private and not exported. Object creation goes through static factory methods: `Create()`, `CreateFromD3D12Buffer()`, and `CreateFromSwapChainBuffers()`. This is standard C++ factory pattern, not a missing constructor.

3. **D3D12 buffer usage conditions**: `GetD3D12Buffer` and `ProduceDawnBuffer` exist but their trigger conditions are unknown without live execution data.

4. **Access validation logic**: `ValidateBeginAccess(bool)` and `BeginAccessCommon(bool)` exist but their boolean parameter semantics (likely write vs read) are unconfirmed.
