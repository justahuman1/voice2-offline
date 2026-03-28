# Progress

## Current Task
Task 20: Speak2Kit library extraction (Session 3, Wave 5)

## Status
Waves 1-4 complete. Ready for Session 3 (Wave 5).

## Context
- Tasks 1-19 are DONE. All committed on main, `swift build` passes.
- 21 source files in Sources/. Full app flow wired end-to-end.
- AppDelegate owns: AudioRecorder, EngineManager, GlowOverlay, HotkeyManager, transient timer.
- Recording state machine in AppDelegate: idle → recording → processing → done/error, with escape → cancelled.
- TextReplacements.processText() applied before paste. TranscriptionHistory.addEntry() called on success.
- PasteService.onProblematicApp wired to show history window.
- SettingsWindow now takes appState + engineManager, passes to SettingsView.
- SettingsContentView uses real views: SettingsView, HistoryView, StatsView, AudioDevicesView.
- GlowColor.swiftUIColor extension in SettingsView.swift for color picker.
- ShortcutRecorder NSViewRepresentable wraps KeyboardShortcuts.RecorderCocoa.
- TranscriptionHistory and TranscriptionStats are @Observable @MainActor singletons with JSON persistence.
- AudioDeviceManager enumerates CoreAudio HAL devices, persists selection to UserDefaults.
- AppState.swift still has local placeholder ParakeetVersion/GlowColor enums — unify in Task 20.

## Lessons
- [Task 1] FluidAudio repo is at `https://github.com/FluidInference/FluidAudio.git`, not `AIDingDing449`. Design doc has wrong URL.
- [Task 1] FluidAudio latest version resolves to 0.13.2 (tag v0.13.2.6). The design doc's `from: 0.7.9` is very outdated. Use `from: "0.13.2"`.
- [Task 1] `.build` directory can get permission-locked; `swift package reset` may fail. If needed, use `sudo rm -rf .build` or just run `swift package resolve` + `swift build` instead.
- [Wave 1] AudioRecorder uses a thread-safe `AudioBuffer` class (NSLock-based) for tap callback access, with `nonisolated(unsafe)` for the level callback.
- [Wave 1] Worktree agents commit directly to main (linear history). No merge conflicts when files don't overlap.
- [Wave 2] FluidAudio API: `AsrModels.downloadAndLoad(version:)` (not `AsrModels.load`), `AsrModelVersion` enum maps from ParakeetVersion.
- [Wave 3] All 3 parallel agents completed without conflicts. File sets were fully disjoint.
- [Wave 4] SettingsWindow updated to accept appState + engineManager constructor params for dependency injection.

## Done
- Task 1: Project scaffold
- Task 2: App bootstrap + menu bar (main.swift, AppDelegate, AppState)
- Task 3: AudioRecorder actor
- Task 4: HotkeyManager
- Task 5: GlowOverlay
- Task 6: TranscriptionEngine protocol + ParakeetVersion
- Task 7: ParakeetEngine
- Task 8: EngineManager
- Task 9: Wire recording → transcription flow
- Task 10: PasteService
- Task 11: NotificationService
- Task 12: TextReplacements + TextReplacementEngine
- Task 13: End-to-end integration
- Task 14: SettingsWindow shell
- Task 15: SettingsView (model selection)
- Task 16: Glow color picker + hotkey customization
- Task 17: HistoryView
- Task 18: StatsView
- Task 19: AudioDevicesView + AudioDeviceManager + TranscriptionHistory + TranscriptionStats
