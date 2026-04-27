# Bug Report — Round 1

## 🔴 Critical

### BUG-001: `$args` automatic variable conflict (4 scripts)
PowerShell's `$args` is read-only in `[CmdletBinding()]` functions. Scripts assign `$args = @(...)` causing immediate crash.

| Script | Line |
|--------|------|
| `src/gpu/nsight-capture.ps1` | 102 |
| `src/gpu/gpa-capture.ps1` | 80 |
| `src/gpu/socwatch-run.ps1` | ~138 |
| `src/vs/windbg-attach.ps1` | ~91 |

**Error:** `"The variable '$args' is a ReadOnly or Constant variable and cannot be assigned to."`

### BUG-002: `chromium-debug.ps1` passes `-Pid` but `windbg-attach.ps1` expects `-ProcessId`
Line 124 builds `$attachArgs.Pid = $targetPid` but windbg-attach parameter was renamed to `$ProcessId`. Splatted call fails.

### BUG-003: `pix-capture.ps1` line 154 — PowerShell 5.1 parse error
Inline `if` expression used as hashtable value: `note = if ($captureExists) { ... } else { ... }`. In PS 5.1, `if` is a statement, not an expression — this is a **parse error**, the script won't even load.

### BUG-004: `screenshot.ps1` missing assembly load
`$FullScreen` path uses `[System.Windows.Forms.Screen]` without `Add-Type -AssemblyName System.Windows.Forms`.

## 🟡 Medium — Script Logic

### BUG-005: `gpa-capture.ps1` — Race: `Kill()` then `ReadToEnd()`
Line 131-133: After `$process.Kill()`, calling `$process.StandardOutput.ReadToEnd()` can throw `InvalidOperationException` if streams are already closed. No async read started before Kill.

### BUG-006: `socwatch-run.ps1` — Deadlock: `WaitForExit()` before `ReadToEnd()`
Lines 163-164: synchronous `ReadToEnd()` called AFTER `WaitForExit()`. If output buffer fills, child blocks waiting for drain, but parent is waiting for exit. Classic deadlock. Other scripts correctly use `ReadToEndAsync()`.

### BUG-007: `pix-capture.ps1` — Env var pollution + leak on error
Lines 105-107 set `$env:PIX_*` in current process BEFORE `ProcessStartInfo` launch. Redundant (already set on `$psi.EnvironmentVariables` lines 123-125) AND cleanup at lines 141-143 is skipped if error occurs between.

### BUG-008: `gpa-capture.ps1` — `success = $true` hardcoded
Line 139: `success` is always `$true` regardless of `$process.ExitCode`. Other scripts check exit code.

### BUG-009: `chromium-debug.ps1` — Chrome process orphaned on error
If debugger attach fails, `$chromeProc` launched at line 106 continues running. No `finally` block for cleanup.

### BUG-010: `pix-capture.ps1` — No stdout/stderr capture
`$psi.RedirectStandardOutput/Error` never set to `$true`. No diagnostic output on failure.

### BUG-011: `find-process.ps1` — WQL injection
Line 57: `$ProcessName` directly interpolated into WQL filter without escaping single quotes. Input like `chrome' OR Name LIKE '` alters the query.

### BUG-012: `find-process.ps1` — Wildcard over-match
`"Name LIKE '${ProcessName}%'"` matches `chromedriver`, `chrome_crashpad_handler` etc.

## 🟡 Medium — API Schema Mismatches

### BUG-013: `docs/api/windbg-attach.schema.json` — Says `Pid`, script expects `ProcessId`

### BUG-014: `docs/api/chromium-debug.schema.json` — Debugger enum: schema has `"cdb"/"windbg"`, script has `"windbg"/"vs"`

### BUG-015: `docs/api/chromium-debug.schema.json` — `ExtraArgs` type: schema says `string`, script is `string[]`

### BUG-016: `docs/api/find-process.schema.json` — Enum includes `"all"` which script rejects; missing `"gpu-process"`, `"crashpad-handler"`

### BUG-017: `docs/api/socwatch-run.schema.json` — `Features` type: schema says `array`, script is `string`

### BUG-018: `docs/api/pix-capture.schema.json` — `CaptureFrames`: schema says `string` range, script is `int` count. Missing `Timeout` param.

## 🟡 Medium — Skill Doc Mismatches

### BUG-019: `skills/common/windbg-debug.md` — Uses `-PID` (actual: `-ProcessId`), wrong script path

### BUG-020: `skills/common/screenshot-capture.md` — Multiple wrong params: `-PID`, `-Output`, `-Delay`, `-Monitor`, `-DpiAware` (none exist). Wrong script path.

### BUG-021: `skills/chromium/gpu-process-debug.md` — `find-process.ps1 -Name` (actual: `-ProcessName`), case-sensitive `-Type "GPU"` should be `"gpu"`

## 🟡 Medium — Test Issues

### BUG-022: All tests use `BeforeAll` — incompatible with Pester 3.4
`BeforeAll` introduced in Pester 4.x. On 3.4, blocks silently ignored, `$ScriptPath` becomes `$null`.

### BUG-023: E2E skipped tests report as Passed
Using `return` in `It` blocks without `Should` marks them Passed, not Skipped.

### BUG-024: E2E `Stop-Process -Name chrome` kills all Chrome on machine
Not scoped to test-spawned PID.

### BUG-025: Mock scope — Mocks inside `It` blocks don't propagate to `& $ScriptPath` child scope

### BUG-026: Tests are "grep tests" — regex on source code, not behavioral
screenshot, renderdoc, windbg tests verify string patterns in source, not actual behavior.

## 🔵 Low

### BUG-027: `nsight-capture.ps1` — `Test-Path` fails for PATH-resolved executables

### BUG-028: `renderdoc-capture.ps1` — Error message references `-Pid` not `-ProcessId`

### BUG-029: `chromium-debug.ps1` — Relative path with `..` not resolved, fragile across working dirs

---

**Summary: 4 critical, 18 medium, 3 low — 25 unique bugs total across 2 rounds.**

| Category | Count |
|----------|-------|
| Script crashes (won't run at all) | 5 (BUG-001 x4, BUG-003) |
| Cross-script wiring bugs | 2 (BUG-002, BUG-009) |
| Race conditions / deadlocks | 2 (BUG-005, BUG-006) |
| API schema vs reality mismatches | 6 (BUG-013 to BUG-018) |
| Skill doc vs reality mismatches | 3 (BUG-019 to BUG-021) |
| Test framework issues | 5 (BUG-022 to BUG-026) |
| Other logic/security | 6 |
