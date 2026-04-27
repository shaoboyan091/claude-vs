# VS License/Login Persistence

## What Works

### License storage locations

- **Registry**: `HKCU\Software\Microsoft\VisualStudio\Licenses`
- **Identity cache**: `%LocalAppData%\Microsoft\VisualStudio\17.0_<hash>\AccountSettings\`
- **ServiceHub tokens**: `%LocalAppData%\Microsoft\VisualStudio\17.0_<hash>\ServiceHub\`
- **Credential store**: Windows Credential Manager (`Generic:VSCredentials_*`)

### Volume license key (offline activation)

```cmd
# Enter product key (Professional/Enterprise)
"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\StorePID.exe" XXXXX-XXXXX-XXXXX-XXXXX-XXXXX 09660

# Product ID codes:
# 09660 = Enterprise
# 09662 = Professional
```

### Enterprise pre-provisioned scenarios

Deployed via Group Policy or SCCM:
- Pre-configure with `--productKey` in layout install
- Use `--passive` for unattended install with embedded key

```cmd
# Create offline layout with key
vs_enterprise.exe --layout C:\VSLayout --productKey XXXXX-XXXXX-XXXXX-XXXXX-XXXXX

# Install from layout (pre-activated)
C:\VSLayout\vs_enterprise.exe --passive --productKey XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
```

### Registry export/import workaround

```cmd
# Export license state from working machine
reg export "HKCU\Software\Microsoft\VisualStudio\Licenses" vs_license.reg /y

# Import on target machine
reg import vs_license.reg
```

Note: This only works for product-key activations. Sign-in tokens are machine-bound.

## What Doesn't Work

- **No CLI for interactive sign-in**: Cannot script `devenv /login user@domain.com`.
- **OAuth tokens are machine-specific**: Cannot copy ServiceHub tokens between machines.
- **Token refresh** requires UI interaction after expiry (typically 90 days).
- **Registry export of sign-in auth** does not work across machines (DPAPI-encrypted).

## Workarounds

| Scenario | Approach |
|----------|----------|
| CI/build machines | Volume license key via StorePID.exe |
| Developer fleet | Group Policy + pre-provisioned key |
| Token expired | Delete `%LocalAppData%\Microsoft\VisualStudio\17.0_*\AccountSettings` and re-sign-in |
| Credential issues | `cmdkey /delete:Generic:VSCredentials_*` then relaunch |

## Checking license status

```cmd
# Check installed product keys
reg query "HKCU\Software\Microsoft\VisualStudio\Licenses" /s

# List VS credentials in Windows Credential Manager
cmdkey /list | findstr "Visual"
```
