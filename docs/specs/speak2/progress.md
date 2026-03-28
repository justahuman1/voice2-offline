# Progress

## Current Task
Task 9: Wire recording → transcription flow (Session 2, Wave 3)

## Status
Waves 1+2 complete. Ready for Session 2 (Waves 3+4).

## Context
- Tasks 1-8, 10-12, 14 are DONE. All committed on main, `swift build` passes.
- 15 source files in Sources/. Placeholder.swift deleted.
- AppState.swift has placeholder ParakeetVersion/GlowColor enums (local to Speak2 target). Speak2Kit has the real ParakeetVersion with full metadata. These coexist in different modules — will be unified in Task 20.
- GlowOverlay uses its own `OverlayState` enum (not RecordingState). Wiring happens in Task 9.
- ParakeetEngine uses FluidAudio API: `AsrModels.downloadAndLoad(version:)`, `AsrManager`, `AsrModelVersion`.
- EngineManager uses `AsrModels.modelsExist(at:version:)` for isModelDownloaded check.
- SettingsWindow wired to AppDelegate openSettings/openHistory with NSApp.activate.
- PasteService has `onProblematicApp` callback property.

## Lessons
- [Task 1] FluidAudio repo is at `https://github.com/FluidInference/FluidAudio.git`, not `AIDingDing449`. Design doc has wrong URL.
- [Task 1] FluidAudio latest version resolves to 0.13.2 (tag v0.13.2.6). The design doc's `from: 0.7.9` is very outdated. Use `from: "0.13.2"`.
- [Task 1] `.build` directory can get permission-locked; `swift package reset` may fail. If needed, use `sudo rm -rf .build` or just run `swift package resolve` + `swift build` instead.
- [Wave 1] AudioRecorder uses a thread-safe `AudioBuffer` class (NSLock-based) for tap callback access, with `nonisolated(unsafe)` for the level callback.
- [Wave 1] Worktree agents commit directly to main (linear history). No merge conflicts when files don't overlap.
- [Wave 2] FluidAudio API: `AsrModels.downloadAndLoad(version:)` (not `AsrModels.load`), `AsrModelVersion` enum maps from ParakeetVersion.

## Done
- Task 1: Project scaffold
- Task 2: App bootstrap + menu bar (main.swift, AppDelegate, AppState)
- Task 3: AudioRecorder actor
- Task 4: HotkeyManager
- Task 5: GlowOverlay
- Task 6: TranscriptionEngine protocol + ParakeetVersion
- Task 7: ParakeetEngine
- Task 8: EngineManager
- Task 10: PasteService
- Task 11: NotificationService
- Task 12: TextReplacements + TextReplacementEngine
- Task 14: SettingsWindow shell
