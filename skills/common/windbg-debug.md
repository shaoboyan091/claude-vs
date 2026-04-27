# WinDbg Debug

## When to Use

- Need automated stack dumps from a running or crashed process
- Memory inspection, heap analysis, or crash root-cause analysis
- Collecting .dmp files for offline analysis

## Prerequisites

- Windows SDK installed (provides cdb.exe/windbg.exe) OR WinDbg Preview from Microsoft Store
- Symbol server access (internet or local symbol cache)
- Admin privileges if attaching to elevated processes

## Workflow

### 1. Find the target process

```powershell
# By name
.\scripts\find-process.ps1 -Name "chrome"
# By window title
.\scripts\find-process.ps1 -Title "GPU Process"
```

### 2. Attach debugger

```powershell
# Interactive WinDbg
.\src\vs\windbg-attach.ps1 -ProcessId 1234

# Non-interactive dump collection
cdb -p 1234 -c ".dump /ma C:\dumps\crash.dmp; q"
```

### 3. Common command sequences

```
# Stack trace (all threads)
~*k

# Automated crash analysis
!analyze -v

# Heap inspection
!heap -s
!heap -p -a <address>

# Full memory dump
.dump /ma C:\dumps\full.dmp

# List loaded modules
lm

# Exception record
.exr -1
.ecxr
k
```

### 4. Symbol setup

```
.symfix C:\symbols
.sympath+ srv*C:\symbols*https://msdl.microsoft.com/download/symbols
.sympath+ C:\work\chromium\src\out\Debug
.reload /f
```

### 5. Breakpoints for live debug

```
bp module!Function
bu module!Function          # deferred (unloaded module)
bl                          # list breakpoints
g                           # continue
```

## Expected Output

- Stack traces showing call chain to crash/hang point
- .dmp file for offline sharing/analysis
- Module list confirming correct binary versions

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Access denied on attach | Run WinDbg/terminal as Administrator |
| Symbols not loading | Run `.symfix` then `.reload /f`; check internet |
| "Debugger already attached" | Only one debugger per process; detach first |
| Managed (.NET) code in stack | Load SOS: `.loadby sos clr` then `!clrstack` |
| Process exits on attach | Use `-pd` flag (non-invasive attach) |
