# claude-vs

PowerShell toolkit for automated debugging and GPU profiling on Windows. Designed for use with Claude Code to attach debuggers, capture GPU frames, and investigate Chromium internals.

## Tools

### Debugger (`src/vs/`)

| Script | Purpose |
|--------|---------|
| `windbg-attach.ps1` | Attach cdb.exe to a process, run commands, capture stack traces |
| `vs-attach.ps1` | Launch Visual Studio attached to a process (interactive) |
| `chromium-debug.ps1` | Launch Chromium with startup dialogs, auto-attach debugger to gpu/renderer/browser process |

### GPU Profiling (`src/gpu/`)

| Script | Purpose |
|--------|---------|
| `renderdoc-capture.ps1` | RenderDoc GPU frame capture, injection, and replay |
| `pix-capture.ps1` | PIX GPU capture via DLL injection (D3D12, requires Developer Mode) |
| `gpa-capture.ps1` | Intel GPA frame capture for D3D11/D3D12 |
| `nsight-capture.ps1` | NVIDIA Nsight Graphics frame debugger and GPU trace |
| `socwatch-run.ps1` | Intel SoC Watch power and frequency measurement |

### Utilities (`src/util/`)

| Script | Purpose |
|--------|---------|
| `find-process.ps1` | Discover Chrome child processes by type (gpu, renderer, browser, utility) |
| `screenshot.ps1` | Capture window screenshot by PID or fullscreen |

## Quick Start

```powershell
# Find Chrome's GPU process
.\src\util\find-process.ps1 -ProcessName chrome -Type gpu

# Attach WinDbg, dump all thread stacks, detach
.\src\vs\windbg-attach.ps1 -ProcessId <pid>

# Launch a test under the debugger (no race condition)
.\src\vs\windbg-attach.ps1 -Executable "C:\dawn\out\Debug\dawn_end2end_tests.exe" -Arguments "--gtest_filter=*Buffer*" -WorkingDirectory "C:\dawn\out\Debug"

# Capture a screenshot of a window
.\src\util\screenshot.ps1 -ProcessId <pid> -OutputPath capture.png

# Launch Chromium and attach debugger to GPU process
.\src\vs\chromium-debug.ps1 -ChromePath "C:\path\to\chrome.exe" -Target gpu

# RenderDoc capture
.\src\gpu\renderdoc-capture.ps1 -Executable "C:\path\to\app.exe" -OutputPath capture.rdc

# PIX capture (requires D3D12 app + Developer Mode)
.\src\gpu\pix-capture.ps1 -Executable "C:\path\to\app.exe" -OutputPath capture.wpix
```

## Chromium Debugging

For GPU process debugging, launch Chrome with sandbox disabled:

```powershell
chrome.exe --disable-gpu-sandbox --disable-gpu-watchdog
```

The `chromium-debug.ps1` script automates the full workflow: launch with `--gpu-startup-dialog`, discover the target process via `find-process.ps1`, and attach the debugger.

## Skills

Pre-written guides for Claude Code live in `skills/`. Each skill documents when to use a tool, prerequisites, step-by-step commands, and troubleshooting.

- `skills/common/` -- General tool usage (WinDbg, RenderDoc, PIX, GPA, Nsight, screenshot, SoC Watch)
- `skills/chromium/` -- Chromium-specific workflows (GPU process debug, WebGL capture, WebGPU profiling, power measurement)

## API Schemas

JSON schemas for each script's inputs and outputs are in `docs/api/`. These define parameter types, enums, and expected output shapes.

## Tests

```powershell
# Run all unit tests (Pester 3.4+)
Invoke-Pester tests/unit/

# Run regression tests
Invoke-Pester tests/unit/regression.tests.ps1
```

## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- Windows SDK (for cdb.exe / WinDbg)
- GPU tools installed as needed: RenderDoc, PIX, Intel GPA, NVIDIA Nsight, Intel SoC Watch
