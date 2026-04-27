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

### BUG-003: `pix-capture.ps1` line 154 — PowerShell 7+ ternary syntax
Inline `if` expression not supported on Windows PowerShell 5.1.

### BUG-004: `screenshot.ps1` missing assembly load
`$FullScreen` path uses `[System.Windows.Forms.Screen]` without `Add-Type -AssemblyName System.Windows.Forms`.

## 🟡 Medium

### BUG-005: All tests use `BeforeAll` — incompatible with Pester 3.4
`BeforeAll` was introduced in Pester 4.x. On 3.4, blocks are silently ignored, `$ScriptPath` becomes `$null`.

### BUG-006: E2E skipped tests report as Passed
Using `return` in `It` blocks without `Should` assertions marks tests as Passed, not Skipped.

### BUG-007: E2E `Stop-Process -Name chrome` kills all Chrome
Not scoped to test-spawned PID — destroys user's browser session.

### BUG-008: `gpa-capture.ps1` stdout deadlock
Line 133 calls `ReadToEnd()` after `Kill()` without async drain. Large output can deadlock.

### BUG-009: `find-process.ps1` WMI wildcard over-match
`"Name LIKE '${ProcessName}%'"` matches `chromedriver`, `chrome_crashpad_handler` etc.

### BUG-010: Mock scope in unit tests won't intercept child script execution
Mocks inside `It` blocks don't propagate to `& $ScriptPath` child scope in Pester 3.4.

## 🔵 Low

### BUG-011: `nsight-capture.ps1` — `Test-Path` fails for PATH-resolved executables
Only full paths pass the validation check on line 83.

### BUG-012: `renderdoc-capture.ps1` error message references `-Pid` not `-ProcessId`
Parameter was renamed but error text wasn't updated.

### BUG-013: `chromium-debug.ps1` relative path fragility
`"..\util\find-process.ps1"` depends on `$ScriptDir` being set correctly.

### BUG-014: Tests are "grep tests" — regex on source code, not behavioral
screenshot, renderdoc, windbg tests verify string patterns in source, not actual behavior.
