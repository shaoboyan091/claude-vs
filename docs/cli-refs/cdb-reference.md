# cdb.exe Reference

## Launch Flags

| Flag | Description |
|------|-------------|
| `-p <pid>` | Attach to process by PID |
| `-pn <name>` | Attach to process by name |
| `-c "<cmds>"` | Run commands on attach (semicolon-separated) |
| `-o` | Debug child processes |
| `-loga <file>` | Append output to log file |
| `-logo <file>` | Overwrite output to log file |
| `-z <dmpfile>` | Open crash dump file |
| `-y <sympath>` | Set symbol path |
| `-i <imgpath>` | Set image path |
| `-lines` | Enable source line support |

## Common Commands

| Command | Description |
|---------|-------------|
| `k` | Display call stack |
| `~*k` | Display call stacks for all threads |
| `~*e !clrstack` | Managed stacks for all threads |
| `!analyze -v` | Analyze exception/bugcheck |
| `.dump /ma <path>` | Write full memory dump |
| `.symfix` | Set default Microsoft symbol server |
| `.sympath+ <path>` | Append to symbol path |
| `.reload` | Reload symbols |
| `lm` | List loaded modules |
| `bp <addr>` | Set breakpoint |
| `g` | Go (continue execution) |
| `.detach` | Detach from process |
| `q` | Quit debugger (terminates target) |
| `qd` | Quit debugger (detaches first) |

## Usage Examples

```bat
:: Attach and get stacks
cdb -p 1234 -c "~*k;.detach;q"

:: Attach with logging
cdb -p 1234 -loga output.txt -c "!analyze -v;~*k;.dump /ma crash.dmp;qd"

:: Debug child processes
cdb -o -p 1234 -c ".childdbg 1;g"
```
