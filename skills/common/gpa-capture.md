# Intel GPA Capture

## When to Use

- Need Intel GPU frame analysis (integrated or discrete Arc GPUs)
- Profiling D3D11/D3D12 workloads on Intel hardware
- Analyzing Chrome/browser GPU workloads on Intel platforms

## Prerequisites

- Intel Graphics Performance Analyzers (GPA) installed
- Intel GPU (integrated UHD/Iris or discrete Arc)
- `gpa-injector.exe` and Graphics Monitor available

## Workflow

### 1. CLI injection with gpa-injector

```powershell
# Inject into application at launch
gpa-injector.exe --app "C:\path\to\app.exe" --args "--arg1" --layer FrameAnalyzer

# Inject into running process
gpa-injector.exe --pid 1234 --layer FrameAnalyzer
```

### 2. Graphics Monitor (UI approach)

1. Launch Intel Graphics Monitor
2. Add target application
3. Select analysis type (Frame Analyzer, System Analyzer)
4. Launch application through monitor
5. Press **Ctrl+Shift+C** to capture frame

### 3. Chrome-specific flags

Chrome requires sandbox disabling for GPA hooks:

```powershell
chrome.exe --disable-gpu-sandbox --disable-gpu-watchdog --no-sandbox ^
  --gpu-startup-dialog
```

Then inject GPA into the GPU process after it pauses.

### 4. D3D11 vs D3D12 hooks

```powershell
# Force D3D11 analysis layer
gpa-injector.exe --app "app.exe" --layer D3D11FrameAnalyzer

# Force D3D12 analysis layer
gpa-injector.exe --app "app.exe" --layer D3D12FrameAnalyzer
```

### 5. System-level metrics

```powershell
# Collect GPU/CPU metrics over time
gpa-injector.exe --app "app.exe" --layer SystemAnalyzer --duration 30
```

## Key Analysis Features

- Draw call list with GPU duration
- Shader source view (HLSL)
- Render target and texture inspection
- GPU EU utilization and stall reasons
- Overdraw visualization

## Expected Output

- `.gpa-trace` capture file
- Per-draw GPU timing
- EU occupancy and memory bandwidth data

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "No Intel GPU detected" | Ensure Intel GPU is active (not disabled in Device Manager) |
| Hooks not attaching | Disable other overlays; run as Admin |
| Chrome GPU process not captured | Must use `--disable-gpu-sandbox` and inject into GPU process |
| D3D12 not supported | Update GPA; older versions lack D3D12 support |
| Capture is empty | Verify correct layer (D3D11 vs D3D12) matches app API |
