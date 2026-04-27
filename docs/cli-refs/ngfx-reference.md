# ngfx.exe Reference (Nsight Graphics CLI)

## Key Flags

| Flag | Description |
|------|-------------|
| `--activity <type>` | Activity type: `frame-capture`, `gpu-trace`, `system-trace` |
| `--exe <path>` | Executable to launch |
| `--args <args>` | Arguments for the executable |
| `--output <path>` | Output file path |
| `--frame <n>` | Frame number to capture |
| `--pid <pid>` | Attach to running process |
| `--cwd <dir>` | Working directory |
| `--frames <range>` | Frame range for trace |
| `--replay` | Replay a capture |
| `--force-repaint` | Force repaint during capture |

## Activity Types

| Activity | Description |
|----------|-------------|
| `frame-capture` | Single frame GPU state capture |
| `gpu-trace` | Multi-frame GPU performance trace |
| `system-trace` | System-wide activity trace |

## Usage Examples

```bat
:: Capture frame 60
ngfx.exe --activity frame-capture --exe "C:\app\game.exe" --args "--width 1920" --output capture.nrd --frame 60

:: GPU trace for 100 frames
ngfx.exe --activity gpu-trace --exe "C:\app\game.exe" --output trace.nrd --frames 50-150

:: Attach to running process
ngfx.exe --activity frame-capture --pid 1234 --output capture.nrd --frame 1
```
