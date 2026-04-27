# VS CLI Automation

## What Works

### devenv.exe flags

```cmd
# Open solution
devenv MySolution.sln

# Build from CLI
devenv MySolution.sln /build "Debug|x64"

# Rebuild
devenv MySolution.sln /rebuild "Release|x64"

# Run a VS command after launch
devenv MySolution.sln /command "File.OpenFile MyFile.cpp"

# Launch and debug an exe
devenv /debugexe MyApp.exe arg1 arg2

# Build and exit (useful for CI-like local builds)
devenv MySolution.sln /build "Debug|x64" /runexit

# Open a file for editing
devenv /edit MyFile.cpp
```

### MSBuild CLI (preferred for builds)

```cmd
# Build solution
msbuild MySolution.sln /p:Configuration=Debug /p:Platform=x64

# Build specific project
msbuild MyProject.vcxproj /t:Build /p:Configuration=Release

# Clean + rebuild
msbuild MySolution.sln /t:Rebuild

# Parallel build
msbuild MySolution.sln /m /p:Configuration=Debug
```

### cdb.exe for automated debugging

```cmd
# Launch and break on entry
cdb -g -G MyApp.exe

# Set breakpoint and go
cdb -c "bp MyModule!MyFunction; g" MyApp.exe

# Run script of commands
cdb -cf commands.txt MyApp.exe

# Attach to running process
cdb -p <pid>
```

## What Doesn't Work

- **No headless debug-attach via devenv**: Cannot script "attach to process and set breakpoints" without UI interaction.
- **No automated breakpoint setting via devenv CLI**: `/command` can run VS commands but breakpoint commands require an open solution context and are unreliable in automation.
- **devenv /runexit** does not return useful exit codes for test pass/fail.
- **devenv /command** runs before the solution is fully loaded; timing-sensitive commands may silently fail.

## Recommendations

| Task | Tool |
|------|------|
| Automated builds | MSBuild |
| Automated debugging | cdb.exe / WinDbg Preview |
| Opening projects for human use | devenv.exe |
| CI pipelines | MSBuild + vstest.console.exe |
