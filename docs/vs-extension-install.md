# VS Extension Installation via CLI

## What Works

### VSIXInstaller.exe

Located at: `C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\VSIXInstaller.exe`

```cmd
# Install silently
VSIXInstaller.exe /quiet /admin MyExtension.vsix

# Uninstall by extension ID
VSIXInstaller.exe /quiet /uninstall:MyCompany.MyExtension.abc123

# Install to specific VS instance (by installPath)
VSIXInstaller.exe /quiet /instanceIds:12345678 MyExtension.vsix
```

#### Flags

| Flag | Description |
|------|-------------|
| `/quiet` | No UI, no prompts |
| `/admin` | Install for all users (requires elevation) |
| `/uninstall:<id>` | Remove extension by identifier |
| `/instanceIds:<id>` | Target specific VS instance |
| `/force` | Force install even if version conflict |

### .vsext manifest files (VS 2022 17.4+)

Create `.vsconfig` or use extensions in a `.vsext` JSON:

```json
{
  "extensions": [
    "ms-vscode.csharp",
    "MadsKristensen.EditorConfig"
  ]
}
```

Import with:
```cmd
devenv /updateConfiguration MyExtensions.vsconfig
```

### Direct download from Marketplace

No official CLI exists. Workaround:

```powershell
# Download VSIX directly (URL pattern)
$publisher = "MadsKristensen"
$extension = "EditorConfig"
$url = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/$publisher/vsextensions/$extension/latest/vspackage"
Invoke-WebRequest -Uri $url -OutFile "$extension.vsix"

# Then install
VSIXInstaller.exe /quiet "$extension.vsix"
```

## What Doesn't Work

- **`/quiet` mode** sometimes hangs if VS is running; always close VS first.
- **`/quiet` mode** returns exit code 0 even on some failures (check `%TEMP%\VSIXInstaller*.log`).
- **No native marketplace CLI** like `code --install-extension` for VS Code.
- **Extension dependencies** are not auto-resolved in quiet mode.
- **Per-user vs admin installs** can conflict; mixing both causes extension load failures.

## Workarounds

```cmd
# Kill VS before install
taskkill /IM devenv.exe /F 2>nul
VSIXInstaller.exe /quiet MyExtension.vsix

# Check install log for errors
type "%TEMP%\VSIXInstaller_*.log" | findstr /i "error"
```

## Extension directory locations

- Per-user: `%LocalAppData%\Microsoft\VisualStudio\17.0_<hash>\Extensions\`
- Admin: `C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\Extensions\`
