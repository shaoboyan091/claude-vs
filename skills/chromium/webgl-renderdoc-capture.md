# WebGL RenderDoc Capture

## When to Use

- Need to capture ANGLE's D3D11 calls from Chrome WebGL content
- Debugging WebGL rendering artifacts at the D3D11 level
- Inspecting shader translations (GLSL -> HLSL via ANGLE)

## Prerequisites

- RenderDoc installed
- Chrome (Debug or Release)
- Understanding: WebGL -> ANGLE -> D3D11 -> GPU

## Architecture

```
JavaScript WebGL API
    -> ANGLE (translates GL to D3D11)
        -> D3D11 Runtime
            -> GPU Driver
```

RenderDoc captures at the D3D11 level.

## Workflow

### 1. Launch Chrome with required flags

```powershell
chrome.exe --disable-gpu-sandbox ^
  --disable-gpu-watchdog ^
  --use-angle=d3d11 ^
  --enable-logging=stderr ^
  --no-sandbox
```

### 2. Inject RenderDoc

#### Option A: Launch through RenderDoc

1. Open RenderDoc
2. Launch Application tab:
   - Executable: `C:\path\to\chrome.exe`
   - Args: `--disable-gpu-sandbox --use-angle=d3d11 --no-sandbox`
   - Working Dir: Chrome's directory
3. Launch
4. RenderDoc hooks into all child processes (including GPU process)

#### Option B: Inject into running GPU process

1. Launch Chrome with `--gpu-startup-dialog --disable-gpu-sandbox`
2. Note GPU process PID
3. In RenderDoc: File > Inject into Process > select GPU process PID
4. Click OK in Chrome dialog

### 3. Navigate to WebGL content

Open WebGL page (e.g., `https://webglsamples.org/aquarium/aquarium.html`)

### 4. Capture frame

- Press **F12** (RenderDoc hotkey) or **PrintScreen**
- RenderDoc shows thumbnail of captured frame

### 5. Analyze capture

- Draw calls show ANGLE's translated D3D11 commands
- Shaders show HLSL (ANGLE-compiled from GLSL)
- Textures/buffers show WebGL resources
- Check for redundant state changes or expensive clears

## Key Inspection Points

- **Shader tab**: See ANGLE's GLSL-to-HLSL translation
- **Texture viewer**: Inspect framebuffers, verify attachments
- **Pipeline state**: Check blend, depth, stencil configuration
- **Draw call count**: Identify batching opportunities

## Expected Output

- `.rdc` capture with all D3D11 calls from ANGLE
- HLSL shader source (ANGLE translated)
- Full framebuffer and texture state

## Troubleshooting

| Issue | Fix |
|-------|-----|
| RenderDoc sees no API calls | GPU process not hooked; use `--disable-gpu-sandbox` |
| ANGLE uses D3D9 instead | Force with `--use-angle=d3d11` |
| Child process not captured | In RenderDoc settings, enable "Hook Into Children" |
| Chrome crashes on inject | Disable other hooks (Steam, Discord overlay) |
| Only see compositor calls | Need to hook GPU process specifically, not browser |
| Black frames in capture | Use `--opt-ref-all-resources` in RenderDoc settings |
