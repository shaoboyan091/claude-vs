# gpa-injector.exe Reference

## Key Flags

| Flag | Description |
|------|-------------|
| `--injection-mode <mode>` | Injection mode: `attach`, `launch` |
| `-t <pid>` | Target process ID for attach |
| `-L <path>` | Launch executable path |
| `--hook-d3d11on12` | Hook D3D11on12 layer |
| `--hook-d3d12` | Hook D3D12 API |
| `--hook-vulkan` | Hook Vulkan API |
| `--output-dir <dir>` | Output directory for captures |
| `--capture-frame <n>` | Capture specific frame |
| `--capture-frames <range>` | Capture frame range (e.g. 1-5) |
| `--layer <name>` | Enable specific layer |
| `--force-capture` | Force capture on next present |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `GPA_LOG_LEVEL` | Log verbosity (0-5) |
| `GPA_LAYER_PATH` | Custom layer search path |

## Usage Examples

```bat
:: Attach to running process
gpa-injector.exe --injection-mode attach -t 1234 --hook-d3d12

:: Launch and capture
gpa-injector.exe --injection-mode launch -L "C:\app\game.exe" --hook-d3d12 --output-dir captures --capture-frame 100

:: Hook D3D11on12 for Chrome
gpa-injector.exe --injection-mode attach -t 5678 --hook-d3d11on12 --output-dir captures
```
