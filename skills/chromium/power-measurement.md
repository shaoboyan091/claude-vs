# Chrome Power Measurement

## When to Use

- Measuring Chrome's power impact for GPU/rendering workloads
- Comparing power between WebGL/WebGPU implementations
- Validating power optimizations (idle tab, offscreen throttling)
- Benchmarking against competing browsers

## Prerequisites

- Intel SoC Watch installed, admin privileges
- Intel platform (for MSR-based power readings)
- Stable thermal environment (consistent ambient temperature)
- Environment setup: run `C:\work\EnvStartUp` bat files first

## Workflow

### 1. Prepare system

```powershell
# Close unnecessary apps
Stop-Process -Name "Teams","Slack","Discord" -ErrorAction SilentlyContinue

# Disable background updates
Set-Service -Name wuauserv -StartupType Disabled

# Wait for system to stabilize
Start-Sleep -Seconds 30
```

### 2. Collect idle baseline

```powershell
socwatch.exe -m -f power -f gpu-freq -f cpu-cstate -t 60 -o C:\data\chrome_idle_baseline
```

### 3. Launch Chrome with workload

```powershell
# Standard Chrome launch for measurement
chrome.exe --disable-background-timer-throttling ^
  --disable-renderer-backgrounding ^
  --disable-backgrounding-occluded-windows

Start-Sleep -Seconds 10  # Wait for page load
```

### 4. Common workloads

| Workload | URL | Measures |
|----------|-----|----------|
| WebGL Aquarium | `https://webglsamples.org/aquarium/aquarium.html` | GPU rendering power |
| MotionMark | `https://browserbench.org/MotionMark1.1/` | Compositor + rendering |
| WebGPU Samples | `https://webgpu.github.io/webgpu-samples/` | Dawn D3D12 power |
| Idle tab | `about:blank` | Baseline Chrome idle |
| Video playback | YouTube 4K | Media decode power |

### 5. Measure workload power

```powershell
# Run measurement during active workload
socwatch.exe -m -f power -f gpu-freq -f thermal -t 60 -o C:\data\chrome_workload
```

### 6. Compare results

Compare results manually using the CSV summaries:

```powershell
$idle = Import-Csv "C:\data\chrome_idle_baseline_power.csv"
$work = Import-Csv "C:\data\chrome_workload_power.csv"

$idlePkg = ($idle | Measure-Object -Property "Package Power (W)" -Average).Average
$workPkg = ($work | Measure-Object -Property "Package Power (W)" -Average).Average
$idleGpu = ($idle | Measure-Object -Property "GT Power (W)" -Average).Average
$workGpu = ($work | Measure-Object -Property "GT Power (W)" -Average).Average

Write-Host "Package delta: $([math]::Round($workPkg - $idlePkg, 2))W"
Write-Host "GPU delta: $([math]::Round($workGpu - $idleGpu, 2))W"
```

### 7. SoC Watch features for Chrome

- GPU C-state residency: shows if Chrome keeps GPU awake unnecessarily
- GPU frequency: shows if workload triggers max freq
- Package power: total SoC impact including memory controller

## Expected Output

- Per-second power CSV data
- Average/peak package and GPU power
- Delta from idle baseline in Watts
- GPU frequency distribution during workload

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Noisy data (high variance) | Increase duration; close all other apps; disable Wi-Fi |
| GPU power shows 0 | Intel GPU may not be active (check discrete GPU isn't primary) |
| Thermal throttling | Cool system; reduce ambient temp; shorter runs |
| Chrome not at full power | Disable `--disable-background-timer-throttling` prevents throttle |
| Results vary between runs | Average 3+ runs; ensure same thermal starting state |
