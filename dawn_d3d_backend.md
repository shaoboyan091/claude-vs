# Dawn D3D12 Backend and Tint HLSL Analysis

## Observed Facts

### Module Architecture

**ComputeBoids.exe** uses a DLL-based architecture:
- `ComputeBoids_exe` — the sample application (753 KB, 0x89db0000-0x89e67000)
- `dawn_native.dll` — Dawn's implementation library (33.4 MB, 0xac690000-0xae6fc000)
- `dawn_proc.dll` — WebGPU proc table dispatch (148 KB)
- `dawn_platform.dll` — platform abstractions (124 KB)

**dawn_end2end_tests.exe** is statically linked:
- `dawn_end2end_tests_exe` — single monolithic binary (55.4 MB, 0x05580000-0x08c9e000)

Both load system D3D12 modules: `d3d12.dll`, `d3d11.dll`, `dxgi.dll`, `D3D12Core.dll`, `d3dcompiler_47.dll`, `dxilconv.dll`

Additional GPU components: `dxil.dll`, `dxcompiler.dll` (Dawn's bundled HLSL compiler)

### System GPU Configuration

From dawn_end2end_tests adapter enumeration:
- **Intel Arc Graphics** (xe-lpg, vendorId 0x8086, deviceId 0x7D55) — D3D12, Vulkan, D3D11
- **NVIDIA RTX 2000 Ada Generation Laptop GPU** (lovelace, vendorId 0x10DE, deviceId 0x28B8) — D3D12, Vulkan, D3D11
- **Microsoft Basic Render Driver** (WARP, vendorId 0x1414, deviceId 0x008C) — D3D12, D3D11
- **SwiftShader Device (Subzero)** (vendorId 0x1AE0, deviceId 0xC0DE) — Vulkan only

### D3D12 Backend Symbol Discovery

Key classes found in `dawn::native::d3d12` namespace:

**Queue** (command submission):
- `Queue::SubmitImpl` — main submission entry point
- `Queue::SubmitPendingCommandsImpl` — flushes pending work
- `Queue::CheckAndUpdateCompletedSerials` — GPU fence monitoring
- `Queue::NextSerial`, `Queue::SetEventOnCompletion` — serial tracking
- `Queue::GetPendingCommandContext`, `Queue::OpenPendingCommands` — command list management
- `Queue::RecycleLastCommandListAfter`, `Queue::RecycleUnusedCommandLists` — command list pooling

**Buffer**:
- `Buffer::Create`, `Buffer::Initialize` — main creation path
- `Buffer::InitializeHostMapped`, `Buffer::InitializeAsExternalBuffer` — alternative init paths
- `Buffer::InitializeToZero`, `Buffer::EnsureDataInitialized` — lazy initialization
- `Buffer::MapAsyncImpl`, `Buffer::MapAtCreationImpl`, `Buffer::MapInternal` — mapping
- `Buffer::TrackUsageAndGetResourceBarrier`, `Buffer::TrackUsageAndTransitionNow` — state tracking
- `Buffer::SynchronizeBufferBeforeMapping`, `Buffer::SynchronizeBufferBeforeUseOnGPU`

**Device**:
- `Device::Create`, `Device::CreateBufferImpl`, `Device::CreateTextureImpl`
- `Device::CreateShaderModuleImpl`, `Device::CreateCommandBuffer`
- `Device::CreateUninitializedComputePipelineImpl`, `Device::CreateUninitializedRenderPipelineImpl`
- `Device::CreateZeroBuffer`, `Device::ClearBufferToZero`
- `Device::GetOrCreateD3D11On12Device` — D3D11-on-12 interop

**CommandBuffer**:
- `CommandBuffer::Create`, `CommandBuffer::RecordCommands`
- `CommandBuffer::RecordComputePass`, `CommandBuffer::RecordRenderPass`
- `CommandBuffer::EmulateBeginRenderPass`, `CommandBuffer::SetupRenderPass`

### Stack Trace: Buffer::Initialize (during Device creation)

```
dawn::native::d3d12::Buffer::Initialize
dawn::native::d3d12::Buffer::Create+0x1da
dawn::native::d3d12::Device::CreateBufferImpl+0x43
dawn::native::DeviceBase::CreateBuffer+0x3a5
dawn::native::d3d12::Device::CreateZeroBuffer+0x161
dawn::native::d3d12::Device::Initialize+0x1059
dawn::native::d3d12::Device::Create+0xc7
dawn::native::d3d12::PhysicalDevice::CreateDeviceImpl+0x6d
dawn::native::PhysicalDeviceBase::CreateDevice+0x5f
dawn::native::AdapterBase::CreateDeviceInternal+0xb0d
dawn::native::AdapterBase::CreateDevice+0xcd
dawn::native::AdapterBase::APICreateDevice+0x76
dawn::native::Adapter::CreateDevice+0x32
  ... (test framework) ...
```

**Observation**: Buffer::Initialize is called during Device initialization to create the "zero buffer" — a utility buffer used for clear operations.

### Stack Trace: Queue::SubmitImpl (from end2end test)

```
dawn::native::d3d12::Queue::SubmitImpl
dawn::native::QueueBase::SubmitInternal+0x470
dawn::native::QueueBase::APISubmit+0x51
dawn::native::NativeQueueSubmit+0x94
dawn_proc!wgpuQueueSubmit+0x2b
wgpu::Queue::Submit+0x44
dawn::DawnTestBase::AddBufferExpectation+0x185
dawn::`anonymous namespace'::BasicTests_QueueWriteBuffer_Test::TestBody+0x131
  ... (gtest framework) ...
```

**Call path**: Test → wgpu C++ wrapper → dawn_proc dispatch → native impl → QueueBase::SubmitInternal → D3D12 Queue::SubmitImpl

### Stack Trace: Queue::SubmitImpl (from ComputeBoids)

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

**Observation**: ComputeBoids submits GPU work every frame via `ComputeBoidsSample::FrameImpl`. The call path goes through the same proc table dispatch layer.

### Tint HLSL Compiler Symbol Discovery

Key symbols in `tint::hlsl` namespace:
- `tint::hlsl::writer::Generate` — top-level HLSL code generation entry point
- `tint::hlsl::writer::Print` — HLSL text output
- `tint::hlsl::writer::raise` — IR raising/transformation for HLSL
- `tint::hlsl::writer::Options` — compiler configuration
- `tint::hlsl::writer::Output` — generation result container
- `tint::hlsl::writer::ValidateBindingOptions` — binding validation
- `tint::hlsl::writer::PopulateBindingRelatedOptions` — binding setup

HLSL-specific IR nodes:
- `tint::hlsl::ir::BuiltinCall`, `tint::hlsl::ir::MemberBuiltinCall`, `tint::hlsl::ir::Ternary`

HLSL-specific types:
- `tint::hlsl::type::ByteAddressBuffer`, `tint::hlsl::type::RasterizerOrderedTexture2D`
- `tint::hlsl::type::Int8T4Packed`, `tint::hlsl::type::Uint8T4Packed`

HLSL intrinsic matchers:
- `tint::hlsl::intrinsic::MatchByteAddressBuffer`, `MatchRasterizerOrderedTexture2D`
- `tint::hlsl::intrinsic::BuildByteAddressBuffer`, `BuildRasterizerOrderedTexture2D`

### Stack Trace: tint::hlsl::writer::Generate

```
tint::hlsl::writer::Generate
dawn::native::d3d::`anonymous namespace'::TranslateToHLSL+0x501
dawn::native::d3d::CompileShader+0xf8
dawn::native::LoadOrRun<...>+0x3dd
dawn::native::d3d12::ShaderModule::Compile+0x1341
dawn::native::d3d12::ComputePipeline::InitializeImpl+0x2f9
dawn::native::ComputePipelineBase::InitializeWithShaders+0x6f
dawn::native::PipelineBase::Initialize+0xf5
dawn::native::DeviceBase::CreateComputePipeline+0x2b9
dawn::native::DeviceBase::APICreateComputePipeline+0x232
dawn::native::NativeDeviceCreateComputePipeline+0x36
dawn_proc!wgpuDeviceCreateComputePipeline+0x21
wgpu::Device::CreateComputePipeline+0x42
dawn::`anonymous namespace'::StorageTextureTests::CreateComputePipeline+0xcd
```

**HLSL compilation path**:
1. `DeviceBase::CreateComputePipeline` → `ComputePipeline::InitializeImpl`
2. `ShaderModule::Compile` — orchestrates compilation (large function, +0x1341 offset)
3. `LoadOrRun<...>` — shader cache lookup or compile
4. `d3d::CompileShader` — backend-agnostic D3D shader compilation
5. `TranslateToHLSL` — converts Tint IR to HLSL text
6. `tint::hlsl::writer::Generate` — the actual Tint HLSL writer

**Parameters observed**: `tint::core::ir::Module* ir`, `tint::hlsl::writer::Options* options`

Additional modules loaded during HLSL compilation: `dxil.dll`, `dxcompiler.dll` (for DXIL bytecode generation after HLSL text is produced)

## Inferences

1. **Shader compilation is lazy**: HLSL generation happens at pipeline creation time, not at shader module creation. The `ShaderModule::Compile` function (+0x1341 offset) suggests substantial logic for cache management.

2. **Two-stage compilation**: First Tint generates HLSL text (`TranslateToHLSL` → `tint::hlsl::writer::Generate`), then DXC compiles HLSL to DXIL bytecode (evidenced by `dxcompiler.dll` loading).

3. **The `LoadOrRun` template function** indicates a shader caching layer — it either loads a cached result or runs the compilation function.

4. **Buffer state tracking** (TrackUsageAndGetResourceBarrier) shows Dawn manages D3D12 resource barriers internally rather than exposing them to the application.

5. **D3D11-on-12 interop** (GetOrCreateD3D11On12Device) exists for features that require D3D11 APIs while running on a D3D12 backend.

6. **Command list pooling** (RecycleLastCommandListAfter, RecycleUnusedCommandLists) reduces allocation overhead for repeated submissions.

## Unresolved Questions

1. **Local variables were unavailable** at all breakpoints (`<value unavailable>`). This is likely because the debug build still optimizes some register-allocated variables, or frame pointer information is incomplete in the PDB.

2. **How does the shader cache key work?** The `LoadOrRun` template suggests caching, but we couldn't observe the cache hit/miss logic without stepping deeper.

3. **What triggers D3D12 resource barrier transitions?** We observed `TrackUsageAndGetResourceBarrier` exists but didn't capture it being called with specific transition parameters.

4. **Thread synchronization model**: Queue::SubmitImpl was always called from the main thread. It's unclear if Dawn uses worker threads for D3D12 command recording in production scenarios.
