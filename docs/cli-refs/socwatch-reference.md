# socwatch Reference

## Key Flags

| Flag | Description |
|------|-------------|
| `-t <seconds>` | Collection duration in seconds |
| `-f <feature>` | Feature to collect (repeatable) |
| `-o <path>` | Output file base path |
| `-m` | Marker support (insert markers) |
| `-r` | Run with real-time priority |
| `--max-detail` | Maximum collection detail level |
| `--csv` | Also output CSV summary |

## Feature Names

| Feature | Description |
|---------|-------------|
| `cpu-cstate` | CPU C-state residency |
| `gpu-cstate` | GPU C/RC state residency |
| `freq` | CPU/GPU frequency transitions |
| `power` | Package/core/GPU power draw |
| `thermal` | Temperature readings |
| `wake` | Wake reason analysis |
| `ltr` | Latency tolerance reporting |
| `pci` | PCI device power states |

## Usage Examples

```bat
:: Basic power collection for 30 seconds
socwatch -t 30 -f cpu-cstate -f gpu-cstate -f power -o results

:: Full collection with CSV
socwatch -t 60 -f cpu-cstate -f gpu-cstate -f freq -f power --csv -o full_trace

:: Quick frequency check
socwatch -t 10 -f freq -o freq_check
```

## Output Files

- `<output>.csv` — Tabular summary data
- `<output>.sw1` — Binary data (open in SoC Watch Viewer)
- `<output>_summary.txt` — Human-readable summary
