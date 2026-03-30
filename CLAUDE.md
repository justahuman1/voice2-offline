# Speak2

macOS menu-bar speech-to-text app. Record via global hotkey, transcribe on-device with Parakeet (FluidAudio), paste at cursor.

## Build & Run

```bash
swift build
swift run Speak2        # or: .build/debug/Speak2
```

Requires Terminal to have Accessibility permission (System Settings > Privacy > Accessibility) for global hotkeys and paste simulation.

There is a `run.sh` that wraps the binary in a `.app` bundle — avoid it for development. The ad-hoc code signature changes on every rebuild, breaking Accessibility permission grants.

## Design Principles

- **Keep it simple.** Prefer the dumbest thing that works. Avoid layered abstractions, fallback chains, and "clever" solutions. Three lines of obvious code beats a two-path strategy.
- **No fragile timing.** Avoid `sleep`, `usleep`, `DispatchQueue.asyncAfter` as load-bearing correctness mechanisms. If something only works with a delay, the approach is wrong.
- **Minimal dependencies.** Only KeyboardShortcuts and FluidAudio. No SwiftUI app lifecycle — raw NSApplication + AppDelegate.
- **No .app bundle required.** Runs as a bare SPM executable via `swift run`. Menu bar icon works with `.accessory` activation policy.

## Architecture

AppDelegate-driven, no SwiftUI app lifecycle. State machine in AppDelegate orchestrates recording flow:

```
Idle → Recording → Processing → Done/Error → Idle
                 ↘ Cancelled → Idle
```

Key components:
- `AppDelegate` — owns status item, state machine, wires everything
- `AppState` — `@Observable` shared state
- `AudioRecorder` — Swift actor, AVAudioEngine, resamples to 16kHz
- `EngineManager` / `ParakeetEngine` — FluidAudio transcription
- `PasteService` — clipboard + CGEvent Cmd+V
- `GlowOverlay` — borderless window, bottom-edge color bar
- `HotkeyManager` — KeyboardShortcuts wrapper

## Learnings & Gotchas

### macOS App Lifecycle (SPM executable)
- `NSApplication.shared` + `MainActor.assumeIsolated { app.run() }` is the bootstrap pattern.
- `.accessory` activation policy = no dock icon, menu bar only. Works fine from a bare binary.
- Previous sessions wrongly concluded menu bar icon doesn't render via `swift run` — it does. The testing methodology (using `timeout` command, buffered stdout) gave false negatives.

### Paste Simulation
- CGEvent Cmd+V is the industry standard (Maccy, Alfred, etc.). There is no better macOS API for cross-app text insertion.
- `kAXSelectedTextAttribute` (Accessibility API) looks promising but many apps (terminals, Electron) report it as settable without actually supporting it. Don't use it.
- `keyUp` event should NOT have `.maskCommand` flag — only `keyDown` needs it.
- The current `usleep(20_000)` between keyDown/keyUp is unfortunate but seems necessary. Would like to eliminate it.

### Permissions
- Accessibility permission is keyed to code signature hash. Ad-hoc signatures change on every rebuild, so `.app` bundles lose their grant after each `swift build`.
- For development: grant Accessibility to Terminal.app, run via `swift run`.
- `AXIsProcessTrustedWithOptions` with prompt option triggers the system dialog.

### Audio Recording
- `inputNode.removeTap(onBus: 0)` MUST come before `audioEngine.stop()` — tap callback can fire after stop if reversed.
- Create fresh `AVAudioEngine()` each recording session to avoid stale state.
- Resample from device rate to 16kHz via stride (Parakeet requirement).

### Storage
- Uses `~/Library/Application Support/Speak2/` — not `~/Documents/` (avoids macOS Documents permission prompt).

## Tests

```bash
swift test
```

17 tests in Speak2KitTests covering TextReplacements and TranscriptionHistory.
