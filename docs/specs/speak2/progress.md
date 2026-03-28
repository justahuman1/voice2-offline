# Progress

## Current Task
Task 2: App bootstrap + menu bar

## Status
Not started

## Context
- Task 1 scaffold is complete. `swift build` succeeds.
- FluidAudio URL is `https://github.com/FluidInference/FluidAudio.git` (from: 0.13.2), NOT the design doc's `AIDingDing449` URL.
- Package.swift has Speak2 (executable), Speak2Kit (library), Speak2KitTests (test) targets.
- `Sources/Speak2/App/main.swift` exists with a placeholder comment — needs to be replaced with NSApplication bootstrap.
- `Sources/Speak2Kit/Models/Placeholder.swift` exists — will be replaced with real models.
- Directory structure created: App, Overlay, Audio, Transcription, Services, Persistence, Views, Resources under Sources/Speak2; Models, TextProcessing under Sources/Speak2Kit.
- Plan is to execute remaining tasks in parallel waves using agent teams with git worktrees. See `/Users/svallabh/.claude/plans/toasty-wishing-coral.md` for the full wave plan.
- Files are NOT yet committed — need to `git add` and commit before starting Wave 1.

## Lessons
- [Task 1] FluidAudio repo is at `https://github.com/FluidInference/FluidAudio.git`, not `AIDingDing449`. Design doc has wrong URL.
- [Task 1] FluidAudio latest version resolves to 0.13.2 (tag v0.13.2.6). The design doc's `from: 0.7.9` is very outdated. Use `from: "0.13.2"`.
- [Task 1] `.build` directory can get permission-locked; `swift package reset` may fail. If needed, use `sudo rm -rf .build` or just run `swift package resolve` + `swift build` instead.

## Done
- Task 1: Project scaffold
