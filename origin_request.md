# Origin Request: Chromium D3DImageBacking Investigation & GPU Profiling

## Task Description

Use the `windbg-break.ps1` tool as a real user to:

1. Launch Chromium debug build, attach to the GPU process
2. Set breakpoints on `D3DImageBacking` methods, step through code
3. Document how `D3DImageBacking` works when rendering WebGPU sample pages
4. Profile the WebGPU sample: performance, GPU memory usage, power consumption
5. Write findings in `chromium_d3d_image_backing.md` and `chromium_gpu_profiling.md`

## Review & Issue Workflow

After generating the documents, an independent review agent reads Chromium source code to verify document content. The issue lifecycle follows this process:

### Raising Issues

All issues are created on **https://github.com/shaoboyan091/claude-vs**.

When the reviewer finds a wrong conclusion or factual error in the documents:

1. Create a GitHub issue via `gh issue create` on https://github.com/shaoboyan091/claude-vs
2. Label severity: `P1` for factual errors that contradict source code, `P2` for missing context or incomplete analysis
3. Issue body must include:
   - What the document claims (quote the specific text)
   - What the source code actually shows (with file path and function reference)
   - Why this matters (impact on document reliability)

### Fixing Issues

After an issue is confirmed (human-reviewed or auto-confirmed for clear misfinding):

1. Fix the relevant document (`chromium_d3d_image_backing.md` or `chromium_gpu_profiling.md`)
2. Run verification to confirm the fix is correct (re-run tool commands or re-check source)
3. Leave a comment on the GitHub issue with:
   - **Root cause**: why the original text was wrong
   - **Fix method**: what was changed and why
   - **Test coverage**: how to verify the fix holds (tool command, source reference)
4. Close the issue

### Iterative Loop

After all issues from a review round are fixed, start another review round. Repeat until:
- No new issues are raised in a round
- All previously raised issues are closed

## Constraints

- The debugging agent must NOT read Chromium source code (acts as pure tool user)
- The review agent CAN and SHOULD read Chromium source code to validate findings
- If a tool cannot resolve information, report the failure reason; never guess
