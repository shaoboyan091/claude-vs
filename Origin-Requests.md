# Project: Claude Code use IDE or GPU profling tools

## Goal
The project is tend to add ability for Claude code to invoke IDE CLI or GPU profling tools CLI to do debugging or profling. And use these information as a ground truth to continue tunning the project or root cause bugs.

## Scope
- Platform: Windows
- Candidate IDE tools: Visual Studio, including debbuging, multi process attachment , profiling
- Candidate GPU profling tools: PIX(for D3D11), RendererDoc (for D3D12), GPU vendor specific tools/VS plugins (Nvidia GPU: Nsight, Intel GPU: Intel GPA, AMD: unknown)

## Unclear part
- How to use Visual Studio CLI?
- If a extension/plugin needed by Visual Studio CLI to do some work, how to install it?
- Login in: I have account for Visual Studio, but how could let claude code to login in and keeping login status to avoid too many manually work?
- GPU profiling tools: Any other recommaneded tools?
- Web GPU profling tools: Unclear which one is the good candidate. Needs some investigation.
- GPU profling including pixel works and screenshot works. Not clear how to do these work, need a deep research to summarize current solutions and pick recommanded way.

Note: For this unclear part, pls do investigation and document the result. One item maps to one result with proper file name to reflect the question.

## Ref project and docs
- Chromium is a good ref project. It is a complex multi-process project with gpu using. It has lots docs to summarize some experience already.
- Chromium docs/ folder is a good candidate. We have chromium code in C:\work\cr\src and pls find docs folder and go to docs/gpu. The recommanded docs for GPU are:
debugging_chrome_gpu_with_pix.md
debugging_chrome_gpu_with_renderdoc.md
debugging_chrome_gpu_with_xcode.md
debugging_gpu_related_code.md
power-measurement-with-intel-socwatch.md
profiling_chromium_with_Intel_GPA.md

And you can find more debugging related tips in this docs/ folder.

My suggestion: Do a full investigation and reading among docs. Summarize IDE using/ gpu profling / power mesurement related docs into skills in two levels:
- Common experience: Not only restricted in chromium but a common use expeirence, pls use a common name for these skills. You could put these skills in cluade_vs/skills/common
- Chromium specific experience: Tight related to chromium code structure/product structure. Pls use a chromium specific name and put these skills in claude_vs/skills/chromium


## Rough guidance about the whole project structure
- **Document and maintain health context** : Anything need a deep investigation and deep research, pls record all your findings in claude_vs/docs and clear or compact (Decide by whether you need summary to continue work) context and continue work.
- **Always check origin goal**: Always look back to this doc when you finished any milestone. Check with parts related to your milestone work to ensure you really fit the requirement or on the way to achive the real goal.
- **Summarize Skills from doc**: Based on docs to create skills if you think the process will be used in future multiple times.
- **Review after skill creation, prefer scripts in Skill**: When creating skill, pls review after creation to ensure the process is align with ground truth(Docs). And replace any part with scripts if possible.
- **Always check ground truth** : When finishing a milestone, which means some function is ready to test, pls ensure a step to run a real complex case to test the function. I recommanded used C:\work\cr project to check.

## Check results:
- Using chromium project as the check project when claim any milestone/funciton done. The check result should be used as the ground truth to decide whether the function/milestone is done or needs more iteration.
- Chromium project path: C:\work\cr\src. And the enviroment to run the chromium related codes in all patched in C:\work\EnvStartUp\Chromium C__work_cr. It will start some service and configure any required environment path. When this bash finished run, you should use the configured command window to do chromium related commands (Or you will hit environment problem)
- Pls ensure the project could debugging chromium browser process, gpu process by attach to the process. And provide the success evidence with log and screenshot.
- Pls ensure the project could profling chromium gpu process. Provide the success evidence with log and screenshot.
- Pls ensure the project could measure chromium power consumption, require not use chromium specific existing tools. Prvoide the success evidence with log and screenshot
