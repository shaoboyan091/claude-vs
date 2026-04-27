# devenv.exe Reference (Visual Studio)

## Key Flags

| Flag | Description |
|------|-------------|
| `/build <config>` | Build solution with specified configuration |
| `/rebuild <config>` | Clean and rebuild solution |
| `/clean <config>` | Clean solution |
| `/debugexe <exe>` | Open exe for debugging (no solution required) |
| `/command <cmd>` | Execute a VS command on startup |
| `/edit <file>` | Open file in existing VS instance |
| `/runexit <sln>` | Build and close VS when done |
| `/project <proj>` | Specify project to build/debug |
| `/projectconfig <cfg>` | Override project configuration |
| `/out <logfile>` | Log build output to file |
| `/safemode` | Launch VS in safe mode |

## Configuration Values

Typical format: `"Debug|x64"`, `"Release|x64"`, `"Debug|Win32"`

## Usage Examples

```bat
:: Build solution in Release x64
devenv mysolution.sln /build "Release|x64"

:: Rebuild specific project
devenv mysolution.sln /rebuild "Debug|x64" /project MyProject

:: Debug an executable directly
devenv /debugexe "C:\app\program.exe" --app-args

:: Open file in running VS
devenv /edit "C:\src\main.cpp"

:: Build, log output, and exit
devenv mysolution.sln /build "Release|x64" /out build.log /runexit

:: Run a VS command
devenv mysolution.sln /command "Debug.Start"
```
