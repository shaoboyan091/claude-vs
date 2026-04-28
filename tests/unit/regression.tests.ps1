Describe "Regression tests for bug fixes" {

    Context "BUG-001: No PowerShell automatic variable conflicts" {
        $scripts = @(
            "$PSScriptRoot/../../src/gpu/nsight-capture.ps1",
            "$PSScriptRoot/../../src/gpu/gpa-capture.ps1",
            "$PSScriptRoot/../../src/gpu/socwatch-run.ps1",
            "$PSScriptRoot/../../src/vs/windbg-attach.ps1"
        )

        foreach ($script in $scripts) {
            $name = Split-Path $script -Leaf
            It "$name does not assign to `$args" {
                $content = Get-Content $script -Raw
                $content | Should Not Match '\$args\s*='
                $content | Should Not Match '\$args\s*\+='
            }
        }

        It "No script uses `$Pid as parameter" {
            $allScripts = Get-ChildItem "$PSScriptRoot/../../src" -Filter *.ps1 -Recurse
            foreach ($f in $allScripts) {
                $content = Get-Content $f.FullName -Raw
                # Should not have [int]$Pid or [string]$Pid as param
                ($content -match '\[int\]\$Pid[,\)]') | Should Be $false
            }
        }
    }

    Context "BUG-002: chromium-debug uses ProcessId not Pid" {
        It "Splatted hash uses ProcessId key" {
            $content = Get-Content "$PSScriptRoot/../../src/vs/chromium-debug.ps1" -Raw
            $content | Should Match 'ProcessId\s*=\s*\$targetPid'
            $content | Should Not Match '[^a-zA-Z]Pid\s*=\s*\$targetPid'
        }
    }

    Context "BUG-003: pix-capture uses subexpression for if" {
        It "Does not use bare if in hashtable value" {
            $content = Get-Content "$PSScriptRoot/../../src/gpu/pix-capture.ps1" -Raw
            # Should use $(if ...) not bare if
            ($content -match 'note\s*=\s*if\s') | Should Be $false
        }
    }

    Context "BUG-004: screenshot loads System.Windows.Forms" {
        It "Has Add-Type for System.Windows.Forms" {
            $content = Get-Content "$PSScriptRoot/../../src/util/screenshot.ps1" -Raw
            $content | Should Match 'System\.Windows\.Forms'
        }
    }

    Context "BUG-005/006: Async stdout/stderr reads" {
        It "gpa-capture uses ReadToEndAsync" {
            $content = Get-Content "$PSScriptRoot/../../src/gpu/gpa-capture.ps1" -Raw
            $content | Should Match 'ReadToEndAsync'
        }

        It "socwatch-run uses ReadToEndAsync" {
            $content = Get-Content "$PSScriptRoot/../../src/gpu/socwatch-run.ps1" -Raw
            $content | Should Match 'ReadToEndAsync'
        }
    }

    Context "BUG-011: find-process escapes single quotes" {
        It "Escapes single quotes in ProcessName" {
            $content = Get-Content "$PSScriptRoot/../../src/util/find-process.ps1" -Raw
            $content | Should Match "replace.*'.*''"
        }
    }

    Context "BUG-030: find-process normalizes Type input before comparison" {
        It "Normalizes gpu-process to gpu in the type filter" {
            $content = Get-Content "$PSScriptRoot/../../src/util/find-process.ps1" -Raw
            $content | Should Match "if \(\`$Type -and \`$typeMap\.ContainsKey\(\`$Type\)\)"
            $content | Should Match "\`$Type = \`$typeMap\[\`$Type\]"
        }
    }

    Context "BUG-031: chromium-debug only kills Chrome on failure" {
        It "Tracks debugSuccess flag" {
            $content = Get-Content "$PSScriptRoot/../../src/vs/chromium-debug.ps1" -Raw
            $content | Should Match '\$debugSuccess = \$false'
            $content | Should Match '\$debugSuccess = \$true'
        }

        It "Finally block checks debugSuccess before killing" {
            $content = Get-Content "$PSScriptRoot/../../src/vs/chromium-debug.ps1" -Raw
            $content | Should Match 'if \(-not \$debugSuccess'
        }
    }

    Context "BUG-033: renderdoc-capture uses correct CLI syntax" {
        It "Does not use nonexistent -e flag" {
            $content = Get-Content "$PSScriptRoot/../../src/gpu/renderdoc-capture.ps1" -Raw
            $content | Should Not Match '\$argList \+= "-e"'
        }

        It "Does not use nonexistent --capture-frame flag" {
            $content = Get-Content "$PSScriptRoot/../../src/gpu/renderdoc-capture.ps1" -Raw
            $content | Should Not Match '--capture-frame'
        }

        It "Executable is positional arg after options" {
            $content = Get-Content "$PSScriptRoot/../../src/gpu/renderdoc-capture.ps1" -Raw
            # -c OutputPath comes before executable, executable is last before Arguments
            $content | Should Match '\$argList \+= "`"\$Executable`""'
        }
    }

    Context "BUG-034: windbg-break uses bu and BP_HIT markers" {
        It "Uses bu for deferred breakpoints" {
            $content = Get-Content "$PSScriptRoot/../../src/vs/windbg-break.ps1" -Raw
            $content | Should Match '\bbu\b'
        }

        It "Uses ==BP_HIT== markers for output parsing" {
            $content = Get-Content "$PSScriptRoot/../../src/vs/windbg-break.ps1" -Raw
            $content | Should Match '==BP_HIT=='
        }

        It "Uses ReadToEndAsync for async reads" {
            $content = Get-Content "$PSScriptRoot/../../src/vs/windbg-break.ps1" -Raw
            $content | Should Match 'ReadToEndAsync'
        }

        It "Uses $$><@ for quoted command file with space-safe paths" {
            $content = Get-Content "$PSScriptRoot/../../src/vs/windbg-break.ps1" -Raw
            $content | Should Match '\$\$><@'
            $content | Should Match 'ShortPath'
        }

        It "Uses -G flag in launch mode" {
            $content = Get-Content "$PSScriptRoot/../../src/vs/windbg-break.ps1" -Raw
            $content | Should Match '"-G"'
        }

        It "Uses .detach in attach mode" {
            $content = Get-Content "$PSScriptRoot/../../src/vs/windbg-break.ps1" -Raw
            $content | Should Match '\.detach;q'
        }

        It "Uses per-breakpoint pseudo-register counters" {
            $content = Get-Content "$PSScriptRoot/../../src/vs/windbg-break.ps1" -Raw
            $content | Should Match '\$t\$i'
        }

        It "Re-enables critical exceptions after sxd *" {
            $content = Get-Content "$PSScriptRoot/../../src/vs/windbg-break.ps1" -Raw
            $content | Should Match 'sxd \*'
            $content | Should Match 'sxe av'
            $content | Should Match 'sxe sov'
        }
    }

    Context "All scripts parse without errors" {
        $allScripts = Get-ChildItem "$PSScriptRoot/../../src" -Filter *.ps1 -Recurse

        foreach ($f in $allScripts) {
            It "$($f.Name) parses successfully" {
                { [scriptblock]::Create((Get-Content $f.FullName -Raw)) } | Should Not Throw
            }
        }
    }
}
