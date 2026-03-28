# Speak2 — Tasks

## Phase 1: Foundation

- [x] 1. Project scaffold
  - [x] 1.1 Create `~/code/side/speak2/` directory
  - [x] 1.2 Write `Package.swift` with Speak2 executable target, Speak2Kit library target, KeyboardShortcuts (exact: 1.8.0) and FluidAudio (from: 0.13.2) dependencies
  - [x] 1.3 Create all directory structure under `Sources/Speak2/` (App, Overlay, Audio, Transcription, Services, Persistence, Views, Resources) and `Sources/Speak2Kit/` (Models, TextProcessing)
  - [x] 1.4 Create `Tests/Speak2KitTests/` directory
  - [x] 1.5 Write MIT `LICENSE` file
  - [x] 1.6 Write placeholder `README.md`
    - _Acceptance: `swift build` succeeds with empty main.swift_

- [x] 2. App bootstrap + menu bar
  - [x] 2.1 Write `main.swift`: `NSApplication.shared`, create AppDelegate, `setActivationPolicy(.accessory)`, `app.run()`
  - [x] 2.2 Write `AppDelegate.swift`: `NSStatusItem` with waveform icon, menu with "Settings...", "View History...", separator, "Auto-Paste" toggle (checkmark menu item, persisted to UserDefaults "autoPasteEnabled", default true), separator, "Quit Speak2"
  - [x] 2.3 Write `AppState.swift`: `@Observable @MainActor` class with `recordingState` (.idle), `audioLevel` (0.0), `selectedVersion` (.v2), `engineLoadingState` (.notDownloaded)
  - [x] 2.4 Verify no dock icon appears, menu bar icon shows, menu opens
    - _Acceptance: app launches as menu-bar-only with waveform icon, quit works_

- [x] 3. AudioRecorder actor
  - [x] 3.1 Write `AudioRecorder.swift` as Swift `actor`
  - [x] 3.2 Implement `startRecording(onLevelUpdate: @Sendable (Float) -> Void)`: create fresh AVAudioEngine, install 1024-sample tap, resample to 16kHz via stride if needed, calculate RMS dB, normalize to 0–1 range `max(0, min(1, (db + 55) / 35))`, call onLevelUpdate
  - [x] 3.3 Implement `stopRecording() -> [Float]?`: set isRecording=false first, removeTap THEN stop engine (order matters — late callbacks fire otherwise), validate duration >= 0.3s, validate RMS >= -55dB, pad with 1s zeros if duration < 1.5s, return buffer or nil
  - [x] 3.4 Implement `cancelRecording()`: stop engine, remove tap, clear buffer
  - [x] 3.5 Implement 5-minute auto-stop: check `audioBuffer.count > 4_800_000` in tap callback, fire stop if exceeded
    - _Acceptance: can record audio, get level updates, stop returns valid 16kHz buffer, cancel clears state_

- [x] 4. HotkeyManager
  - [x] 4.1 Write `HotkeyManager.swift` with KeyboardShortcuts.Name extensions: `.toggleRecording` (Cmd+Opt+Z), `.toggleRecordingAlt` (Cmd+Opt+.), `.showHistory` (Cmd+Opt+A), `.pasteLastTranscription` (Cmd+Opt+V)
  - [x] 4.2 Register default shortcuts via `KeyboardShortcuts.setShortcut()`
  - [x] 4.3 Wire `onKeyUp` handlers to AppDelegate callbacks
  - [x] 4.4 Implement Escape key monitor: `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` for keyCode 53, install only during recording, remove on stop/cancel
    - _Acceptance: hotkeys trigger recording toggle, escape cancels, all 4 shortcuts work_

- [x] 5. GlowOverlay
  - [x] 5.1 Write `GlowOverlay.swift`: borderless NSWindow, 6pt tall, full screen width, bottom edge, click-through, always on top, joins all spaces
  - [x] 5.2 Create `CAGradientLayer` as contentView backing: axial horizontal, center-bright with transparent edges at locations [0.0, 0.3, 0.7, 1.0]
  - [x] 5.3 Implement `show(state:)` with color mapping: recording=#00BFFF, processing=#FFB020, done=#30D158, error=#FF453A
  - [x] 5.4 Recording state: opacity = `0.3 + 0.7 * audioLevel`, updated via `updateLevel(_ level: Float)`
  - [x] 5.5 Processing state: `CABasicAnimation` pulse opacity 0.4↔0.9, duration 0.8s, autoreverses, repeats infinite
  - [x] 5.6 Done/error state: `CAKeyframeAnimation` opacity [1.0, 1.0, 0.0] at keyTimes [0, 0.5, 1.0], duration 0.6s, then hide
  - [x] 5.7 Cancelled state: fade out opacity to 0.0 over 0.2s, then hide
  - [x] 5.8 Multi-monitor: reposition to `NSScreen.main` on each state transition
  - [x] 5.9 `hide()`: remove all animations, `orderOut`
    - _Acceptance: glow bar visible at bottom edge, reacts to audio level, transitions through all states with correct colors and animations_

## Phase 2: Transcription

- [x] 6. TranscriptionEngine protocol + ParakeetVersion
  - [x] 6.1 Write `TranscriptionEngine.swift` protocol: `isReady: Bool`, `loadModel() async throws`, `unloadModel()`, `transcribe(audioSamples: [Float]) async throws -> String`
  - [x] 6.2 Write `Speak2Kit/Models/ParakeetVersion.swift` enum with v2/v3 cases, computed properties: displayName, description, size, speed, wer, accuracy, languages
    - _Acceptance: protocol compiles, ParakeetVersion has all metadata_

- [x] 7. ParakeetEngine
  - [x] 7.1 Write `ParakeetEngine.swift` conforming to `TranscriptionEngine`
  - [x] 7.2 `loadModel(version:)`: create `AsrManager()`, create `~/Documents/Speak2/models/` if needed, `AsrModels.load(from:version:)`, `manager.initialize(models:)`
  - [x] 7.3 `transcribe(audioSamples:)`: call `manager.transcribe()`, return `.text`
  - [x] 7.4 `unloadModel()`: set asrManager to nil
  - [x] 7.5 `isReady`: check asrManager != nil
    - _Acceptance: can download Parakeet v2, load it, transcribe a test buffer, unload it_

- [x] 8. EngineManager
  - [x] 8.1 Write `EngineManager.swift` as `@MainActor` class
  - [x] 8.2 `loadModel(version:)`: cancel existing loadTask, unload current, create new ParakeetEngine, load it, update AppState.engineLoadingState through states (.downloading → .loading → .loaded)
  - [x] 8.3 `unloadModel()`: call engine.unloadModel(), set engine = nil, set state to .downloaded or .notDownloaded based on files on disk
  - [x] 8.4 `transcribe(audioSamples:)`: guard engine.isReady, delegate to engine
  - [x] 8.5 `isModelDownloaded(version:)`: check model files exist at ~/Documents/Speak2/models/
  - [x] 8.6 On startup: load previously selected version from UserDefaults
    - _Acceptance: version switching works, state updates correctly, memory freed on unload_

- [x] 9. Wire recording → transcription flow
  - [x] 9.1 In AppDelegate: on toggle hotkey, implement re-entry guards — if idle → start; if recording → stop + process; if processing → ignore; if transient (.done/.error/.cancelled) → cancel timer + start recording
  - [x] 9.2 On stopRecording returns buffer: set .processing, call EngineManager.transcribe(), on success set .done, on failure set .error
  - [x] 9.3 On stopRecording returns nil (silence): set .cancelled, show notification
  - [x] 9.4 On escape: call cancelRecording(), set .cancelled
  - [x] 9.5 Wire AudioRecorder level updates → AppState.audioLevel → GlowOverlay.updateLevel()
  - [x] 9.6 Add transient state timers: .done/.error → .idle after 0.6s, .cancelled → .idle after 0.3s
    - _Acceptance: end-to-end recording → transcription works, glow transitions through all states, silence/cancel handled_

## Phase 3: Integration

- [x] 10. PasteService
  - [x] 10.1 Write `PasteService.swift`
  - [x] 10.2 `pasteAtCursor(_ text:)`: check `AppState.autoPasteEnabled` — if true: save all pasteboard types, set text, simulate Cmd+V via CGEvent (keyDown virtualKey 0x09 with .maskCommand, then keyUp); if false: just set text on clipboard, show "Copied to clipboard" notification, skip Cmd+V and clipboard restore
  - [x] 10.3 After 0.2s delay: check frontmost app bundleIdentifier against problematic list (com.apple.finder, com.apple.dock, com.apple.systempreferences), if match → trigger show history hotkey
  - [x] 10.4 Restore original clipboard contents after the 0.2s delay
    - _Acceptance: transcription pastes at cursor in text editors, clipboard restored, problematic apps trigger history fallback_

- [x] 11. NotificationService
  - [x] 11.1 Write `NotificationService.swift` wrapping `UNUserNotificationCenter`
  - [x] 11.2 Request authorization on first use (`.alert`, `.sound`)
  - [x] 11.3 Implement notification methods: `showTranscriptionComplete(text:)`, `showError(message:)`, `showCancelled()`, `showSkipped()`
  - [x] 11.4 Each notification: create `UNMutableNotificationContent`, add to center with `UNNotificationRequest`
    - _Acceptance: notifications appear for all recording states, sound plays on completion_

- [x] 12. TextReplacements
  - [x] 12.1 Write `Speak2Kit/TextProcessing/TextReplacementEngine.swift`: pure logic, no file I/O — `func process(_ text: String, replacements: [String: String]) -> String`
  - [x] 12.2 Implement: apply all find→replace, strip enclosing quotes (4 types: "", '', \u201c\u201d, \u2018\u2019), clean bullet formatting (remove "- " prefix, remove single leading space, preserve double+ spaces)
  - [x] 12.3 Write `Services/TextReplacements.swift`: singleton that loads `config.json` from working directory, delegates to TextReplacementEngine
  - [x] 12.4 `reloadConfig()` method to hot-reload from disk
    - _Acceptance: text replacements applied correctly, quote stripping works for all 4 types, bullet cleanup preserves indentation_

- [x] 13. End-to-end integration
  - [x] 13.1 Wire PasteService into transcription completion flow
  - [x] 13.2 Wire TextReplacements: apply processText() before pasting
  - [x] 13.3 Wire NotificationService into all state transitions
  - [x] 13.4 Wire TranscriptionHistory.addEntry() on successful transcription
  - [x] 13.5 Wire Cmd+Opt+V → paste last transcription from history
    - _Acceptance: full flow works: hotkey → record → glow → transcribe → text-replace → paste → notify → history saved_

## Phase 4: UI

- [x] 14. Settings window shell
  - [x] 14.1 Write `SettingsWindow.swift`: NSWindow (850x600, min 600x400) hosting SwiftUI tabbed view, `isReleasedWhenClosed = false`
  - [x] 14.2 Implement 4 tabs with toolbar-style icons: Settings (gear), History (clock), Statistics (chart.bar), Audio Devices (speaker.wave.2)
  - [x] 14.3 Wire "Settings..." menu item to show window
  - [x] 14.4 Wire "View History..." menu item to show window on history tab
    - _Acceptance: window opens from menu bar, tabs switch, window persists in memory_

- [ ] 15. SettingsView (model selection)
  - [ ] 15.1 Write `SettingsView.swift` with two ParakeetModelCard views (v2, v3)
  - [ ] 15.2 Write `ModelCardView.swift`: radio button, name, language badge, description, size/speed metadata, accuracy bar
  - [ ] 15.3 Accuracy bar: color-coded (green >= 97%, blue 95-96.9%, orange 93-94.9%), width proportional to percentage
  - [ ] 15.4 State-aware buttons: "Download" / progress bar / "Downloaded" checkmark / "Loading..." spinner / "Loaded" green checkmark
  - [ ] 15.5 On card tap: if downloaded → select + load; if not downloaded → start download
  - [ ] 15.6 Check filesystem for already-downloaded models on appear
    - _Acceptance: model cards show correct state, download works with progress, selection loads model_

- [ ] 16. Glow color picker + hotkey customization
  - [ ] 16.1 Add "Glow Color" section to SettingsView: horizontal row of color swatches (cyan, purple, green, pink, orange, system accent), selected state with checkmark overlay
  - [ ] 16.2 Define `GlowColor` enum: `.cyan` (#00BFFF), `.purple` (#BF5AF2), `.green` (#30D158), `.pink` (#FF375F), `.orange` (#FF9F0A), `.system` (NSColor.controlAccentColor)
  - [ ] 16.3 Persist selection to UserDefaults "glowColor", wire to GlowOverlay recording color
  - [ ] 16.4 Add "Keyboard Shortcuts" section: use `KeyboardShortcuts.RecorderCocoa` for each shortcut (Toggle Recording, Toggle Recording Alt, Show History, Paste Last Transcription)
  - [ ] 16.5 Display shortcut label + recorder side by side, grouped in a styled list
  - [ ] 16.6 Add "Reset to Defaults" button that restores default shortcuts
    - _Acceptance: color swatches update glow bar in real-time, hotkeys rebindable and persisted across launches_

- [ ] 17. HistoryView
  - [ ] 17.1 Write `HistoryView.swift` with List of transcription entries
  - [ ] 17.2 Each row: transcription text (scrollable), action buttons (Copy, Delete, Copy & Close), smart timestamp
  - [ ] 17.3 Smart timestamp: "Today 2:30 PM" / "Yesterday 2:30 PM" / "Mar 27, 2:30 PM"
  - [ ] 17.4 Copy button: copies to pasteboard, shows "Copied!" for 1 second
  - [ ] 17.5 Delete button: confirmation alert, then remove entry
  - [ ] 17.6 Copy & Close: copies text, closes window after 0.27s delay
  - [ ] 17.7 "Clear History" button with confirmation alert, disabled if empty
  - [ ] 17.8 Auto-refresh on tab selection
    - _Acceptance: history displays entries, all actions work, timestamps format correctly, clear works_

- [ ] 18. StatsView
  - [ ] 18.1 Write `StatsView.swift`: centered layout with title (16pt bold), count (48pt bold accent), subtitle (14pt secondary)
  - [ ] 18.2 Read from TranscriptionStats.shared, refresh on appear
    - _Acceptance: shows total transcription count, updates after new transcription_

- [ ] 19. AudioDevicesView
  - [ ] 19.1 Write `AudioDevicesView.swift` with two sections (input/output)
  - [ ] 19.2 Each section: radio buttons "Follow System Default" / "Use Specific Device", dropdown populated from AudioDeviceManager
  - [ ] 19.3 Dropdown filters out "system_default" UID entries
  - [ ] 19.4 Selection changes call `AudioDeviceManager.savePreferences()`
  - [ ] 19.5 Live sync with AudioDeviceManager state
    - _Acceptance: shows available devices, selection persists, radio/dropdown state syncs_

## Phase 5: Polish

- [ ] 20. Speak2Kit library extraction
  - [ ] 20.1 Move `ParakeetVersion`, `TranscriptionEntry`, `AudioDevice`, `GlowColor` structs/enums to `Speak2Kit/Models/`
  - [ ] 20.2 Ensure `TextReplacementEngine` is in `Speak2Kit/TextProcessing/` (pure logic, no singletons)
  - [ ] 20.3 Update imports in main target to use Speak2Kit
    - _Acceptance: `swift build` passes, library target compiles independently_

- [ ] 21. Unit tests
  - [ ] 21.1 Write `TextReplacementTests.swift`: test find/replace, quote stripping (all 4 types), bullet cleanup, empty input, no-op config
  - [ ] 21.2 Write `TranscriptionHistoryTests.swift`: test add/delete/clear, 100-entry FIFO limit, JSON round-trip serialization
    - _Acceptance: `swift test` passes, covers edge cases_

- [ ] 22. Startup model validation
  - [ ] 22.1 On app launch: check if selected version's model files exist on disk
  - [ ] 22.2 If files exist but model not loaded: set state to .downloaded (not .notDownloaded)
  - [ ] 22.3 Auto-load the previously selected version in background
    - _Acceptance: app resumes correct state after restart, previously downloaded models detected_

- [ ] 23. README and documentation
  - [ ] 23.1 Write README.md: features, requirements (macOS 14+), installation (swift build + swift run), permissions setup (Accessibility, Microphone), keyboard shortcuts table, config.json format
  - [ ] 23.2 Ensure LICENSE is MIT with correct year/author
    - _Acceptance: README covers all setup steps, new user can get running from README alone_
