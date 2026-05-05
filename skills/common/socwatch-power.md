# SoC Watch Power Measurement

## When to Use

- Need CPU/GPU/SoC power consumption data
- Measuring thermal impact of workloads
- Comparing power baselines before/after changes
- Validating power efficiency optimizations

## Prerequisites

- Intel SoC Watch installed (part of Intel VTune or standalone)
- Administrator privileges (kernel-level counters)
- Intel platform (SoC Watch reads Intel MSRs)

## Workflow

### 1. Run power collection

```powershell
# Basic power collection (30 seconds)
socwatch.exe -m -f cpu-cstate -f gpu-cstate -f power -t 30 -o C:\data\baseline

# Comprehensive collection
socwatch.exe -m ^
  -f cpu-pstate -f cpu-cstate ^
  -f gpu-cstate -f gpu-freq ^
  -f power -f thermal ^
  -t 60 ^
  -o C:\data\full_run
```

### 2. Common feature flags

| Flag | Collects |
|------|----------|
| `-f power` | Package/core/GPU power (Watts) |
| `-f thermal` | Temperature readings |
| `-f cpu-cstate` | CPU idle state residency |
| `-f cpu-pstate` | CPU frequency states |
| `-f gpu-cstate` | GPU idle states |
| `-f gpu-freq` | GPU frequency over time |

### 3. Collect baseline (idle)

```powershell
# Close all apps, wait 10s, measure idle
Start-Sleep -Seconds 10
socwatch.exe -m -f power -f thermal -t 30 -o C:\data\idle_baseline
```

### 4. Collect workload measurement

```powershell
# Start workload, then measure
Start-Process "chrome.exe" -ArgumentList "https://webglsamples.org/aquarium/aquarium.html"
Start-Sleep -Seconds 5
socwatch.exe -m -f power -f thermal -f gpu-freq -t 60 -o C:\data\workload
```

### 5. Parse and compare CSV results

```powershell
# SoC Watch outputs CSV files
$baseline = Import-Csv "C:\data\idle_baseline_power.csv"
$workload = Import-Csv "C:\data\workload_power.csv"

# Compare average package power
$baseAvg = ($baseline | Measure-Object -Property "Package Power (W)" -Average).Average
$workAvg = ($workload | Measure-Object -Property "Package Power (W)" -Average).Average
Write-Host "Delta: $([math]::Round($workAvg - $baseAvg, 2))W"
```

## Expected Output

- CSV files with per-second power/thermal/frequency readings
- Summary report with averages, peaks, and residency percentages
- Delta comparison between baseline and test runs

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Access denied" or no data | Run PowerShell/terminal as Administrator |
| "No supported platform" | SoC Watch requires Intel CPU; check compatibility list |
| Noisy power data | Increase duration; close background apps; disable Wi-Fi |
| GPU power shows 0 | Ensure Intel GPU is active and not in D0i3 |
| Thermal throttling skews results | Cool system before test; use consistent ambient temp |
