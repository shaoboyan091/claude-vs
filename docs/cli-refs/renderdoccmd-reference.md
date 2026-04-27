# renderdoccmd Reference

## Subcommands

| Subcommand | Description |
|------------|-------------|
| `capture` | Launch executable and capture frames |
| `inject` | Inject into running process by PID |
| `replay` | Replay a .rdc capture file |
| `convert` | Convert capture to another format |

## Capture Flags

| Flag | Description |
|------|-------------|
| `--wait-for-exit` | Wait for application to exit |
| `--capture-frame <n>` | Capture specific frame number |
| `--capture-delay <s>` | Delay in seconds before capturing |
| `-w <dir>` | Working directory |
| `-c <file>` | Output capture file path |

## Inject Flags

| Flag | Description |
|------|-------------|
| `--pid <pid>` | Target process ID |

## Replay Flags

| Flag | Description |
|------|-------------|
| `--out <path>` | Output directory for exports |
| `--export-textures` | Export all textures |
| `--export-shaders` | Export all shaders |

## Convert Flags

| Flag | Description |
|------|-------------|
| `--input <file>` | Input .rdc file |
| `--output <file>` | Output file path |
| `--format <fmt>` | Target format (png, exr, csv) |

## Usage Examples

```bat
:: Capture frame 5 from an exe
renderdoccmd capture -w "C:\app" -c out.rdc --capture-frame 5 -- app.exe --args

:: Inject into running process
renderdoccmd inject --pid 1234

:: Replay and export textures
renderdoccmd replay --out exports --export-textures capture.rdc
```
