# Speak2 — Design Document

## Overview

Speak2 is a macOS menu-bar utility that records speech via global hotkeys, transcribes on-device using Parakeet (FluidAudio), and pastes the result at the cursor. Recording state is shown via a bottom-edge glow bar overlay. No dock icon, no traditional recording UI.

**Project location:** `~/code/side/speak2`
**License:** MIT
**Platform:** macOS 14.0+, Swift 5.9+, Swift Package Manager

## Architecture

```
AppDelegate (NSApplicationDelegate)
 ├── NSStatusItem (menu bar icon, settings/quit)
 ├── AppState (@Observable, @MainActor)
 │    ├── recordingState: RecordingState
 │    ├── audioLevel: Float (0.0–1.0)
 │    ├── selectedVersion: ParakeetVersion
 │    └── engineLoadingState: EngineLoadingState
 ├── HotkeyManager (KeyboardShortcuts)
 ├── GlowOverlay (NSWindow + CAGradientLayer)
 ├── AudioRecorder (Swift actor)
 ├── EngineManager (@MainActor)
 │    └── TranscriptionEngine protocol
 │         └── ParakeetEngine (FluidAudio wrapper)
 ├── PasteService (CGEvent clipboard paste)
 ├── NotificationService (UNUserNotificationCenter)
 ├── TextReplacements (config.json)
 ├── TranscriptionHistory (JSON, max 100)
 └── TranscriptionStats (JSON counter)
```

## Dependencies

| Package | Version | License | Purpose |
|---------|---------|---------|---------|
| KeyboardShortcuts | 1.8.0 (exact) | MIT | Global hotkey registration |
| FluidAudio | 0.7.9+ | Apache 2.0 | Parakeet on-device transcription |

## State Machine

```
                    ┌──────────┐
                    │   Idle   │◄────────────────────┐
                    └────┬─────┘                     │
                         │ hotkey press              │
                    ┌────▼─────┐    escape       ┌───┴──────┐
                    │Recording │────────────────►│Cancelled │
                    └────┬─────┘                 └──────────┘
                         │ hotkey press (stop)
                    ┌────▼──────┐
                    │Processing │
                    └────┬──┬───┘
              success    │  │  failure
                    ┌────▼┐ ┌▼─────┐
                    │Done │ │Error │
                    └──┬──┘ └──┬───┘
                       │       │
                       └───┬───┘  (after 0.6s)
                           ▼
                         Idle
```

```swift
enum RecordingState {
    case idle
    case recording
    case processing
    case done        // transient, 0.6s then → idle
    case error       // transient, 0.6s then → idle
    case cancelled   // transient, 0.3s then → idle
}
```

**Edge cases and re-entry guards:**
- **Hotkey during .processing:** Ignored. Only allow toggle in `.idle` or `.recording`.
- **Hotkey during transient state (.done/.error/.cancelled):** Cancel the transient timer, immediately transition to `.recording`.
- **Empty transcription result:** Treat as silence — transition to `.cancelled`, show "Recording Skipped" notification.
- **Audio engine fails to start:** Transition to `.error`, show notification with error message.

```swift
// Pseudocode for hotkey handler
func handleToggleHotkey() {
    switch appState.recordingState {
    case .idle:
        startRecording()
    case .recording:
        stopAndTranscribe()
    case .processing:
        return // ignore
    case .done, .error, .cancelled:
        cancelTransientTimer()
        startRecording()
    }
}
```

---

## Component Specifications

### 1. AppDelegate + App Bootstrap

**File:** `Sources/Speak2/App/main.swift`, `AppDelegate.swift`

- `NSApplication.shared` with `setActivationPolicy(.accessory)` — no dock icon
- `NSStatusItem` with `NSStatusBar.system.statusItem(withLength: .variable)`
- Waveform icon: `NSImage(systemSymbolName: "waveform")`
- Menu items:
  - "Settings..." (Cmd+,) → opens settings window
  - "View History..." → opens history tab
  - Separator
  - "Auto-Paste" — checkmark toggle (checked = paste at cursor, unchecked = copy to clipboard only)
  - Separator
  - "Quit Speak2" (Cmd+Q)

**Auto-Paste setting:**
- Persisted to UserDefaults key `"autoPasteEnabled"`, default: `true`
- When enabled: PasteService simulates Cmd+V at cursor (current behavior)
- When disabled: text is placed on clipboard only, notification says "Copied to clipboard"
- On launch: load AppState, register hotkeys, check/load persisted model selection

### 2. AppState

**File:** `Sources/Speak2/App/AppState.swift`

```swift
@Observable
@MainActor
final class AppState {
    // Recording
    var recordingState: RecordingState = .idle
    var audioLevel: Float = 0.0  // 0.0–1.0 normalized from dB

    // Engine
    var selectedVersion: ParakeetVersion = .v2
    var engineLoadingState: EngineLoadingState = .notDownloaded
    // .notDownloaded | .downloading(progress: Double) | .downloaded | .loading | .loaded

    // Preferences
    var autoPasteEnabled: Bool = true  // persisted to UserDefaults "autoPasteEnabled"
    var glowColor: GlowColor = .cyan  // persisted to UserDefaults "glowColor"

    // History (in-memory cache, persisted by TranscriptionHistory)
    var recentTranscription: String? = nil
}
```

**Persistence:** `selectedVersion` saved to `UserDefaults` key `"selectedParakeetVersion"`.

### 3. GlowOverlay

**File:** `Sources/Speak2/Overlay/GlowOverlay.swift`

A borderless, transparent, click-through window pinned to the bottom edge of the active screen.

**Window properties:**
- `styleMask: .borderless`
- `backgroundColor: .clear`
- `isOpaque: false`
- `hasShadow: false`
- `ignoresMouseEvents: true`
- `level: .screenSaver` (above all normal windows)
- `collectionBehavior: [.canJoinAllSpaces, .stationary]`

**Dimensions:**
- Width: full screen width (`NSScreen.main!.frame.width`)
- Height: **6 points**
- Position: bottom edge of active screen (y = screen.frame.minY)

**Visual layer:** `CAGradientLayer` as the window's contentView backing layer
- Type: `.axial` (linear), horizontal (startPoint: (0, 0.5), endPoint: (1, 0.5))
- Colors: center bright, edges fade to transparent
  - `[.clear, glowColor, glowColor, .clear]`
  - Locations: `[0.0, 0.3, 0.7, 1.0]`

**Glow color (configurable):**

The recording glow color is user-selectable. Processing/done/error colors remain fixed for clear state communication.

```swift
enum GlowColor: String, CaseIterable {
    case cyan    // #00BFFF — default
    case purple  // #BF5AF2
    case green   // #30D158
    case pink    // #FF375F
    case orange  // #FF9F0A
    case system  // NSColor.controlAccentColor (follows macOS accent)
}
```

Persisted to UserDefaults key `"glowColor"`, default `.cyan`.

**Colors by state:**

| State | Color | Behavior |
|-------|-------|----------|
| idle | — | window hidden (`orderOut`) |
| recording | user-selected `GlowColor` | opacity = `0.3 + 0.7 * audioLevel` |
| processing | `#FFB020` (amber, fixed) | pulse: opacity animates 0.4↔0.9, duration 0.8s, autoreverses, repeats |
| done | `#30D158` (green, fixed) | fade in at 1.0, hold 0.3s, fade out over 0.3s |
| error | `#FF453A` (red, fixed) | fade in at 1.0, hold 0.3s, fade out over 0.3s |
| cancelled | — | immediate fade out over 0.2s |

**Animation implementation:**
- Recording level: update `layer.opacity` directly (no animation, real-time from audio callback)
- Processing pulse: `CABasicAnimation(keyPath: "opacity")` with `repeatCount = .infinity`, `autoreverses = true`
- Done/error flash: `CAKeyframeAnimation(keyPath: "opacity")` with keyTimes `[0, 0.5, 1.0]` and values `[1.0, 1.0, 0.0]`, duration 0.6s
- All transitions: remove existing animations before adding new ones

**Multi-monitor:** On state change, reposition to `NSScreen.main` (screen with focused window). Check on each state transition.

**Public API:**
```swift
class GlowOverlay {
    func show(state: RecordingState)
    func updateLevel(_ level: Float)  // 0.0–1.0, only used during .recording
    func hide()
}
```

### 4. AudioRecorder

**File:** `Sources/Speak2/Audio/AudioRecorder.swift`

A Swift `actor` that encapsulates AVAudioEngine recording, resampling, and level metering. Actor isolation prevents data races between the audio callback thread and consumers.

**Constants:**
```swift
let targetSampleRate: Double = 16_000        // Hz, required by Parakeet
let bufferSize: UInt32 = 1_024               // samples per tap callback
let maxRecordingDuration: Double = 300.0     // 5 minutes
let maxBufferSamples: Int = 16_000 * 300     // 4,800,000 samples
let silenceThresholdDB: Float = -55.0        // dB RMS
let minRecordingDuration: Double = 0.3       // seconds
let shortAudioThreshold: Double = 1.5        // seconds — pad if below
let silencePaddingDuration: Double = 1.0     // seconds of zeros to append
```

**Recording flow:**
1. `startRecording()`:
   - Create fresh `AVAudioEngine()` (avoid stale state from previous sessions)
   - Get `inputNode`, read its `outputFormat(forBus: 0)` for device sample rate
   - Call `audioEngine.prepare()` **before** installing tap
   - Install tap: `inputNode.installTap(onBus: 0, bufferSize: 1024, format: deviceFormat)`
   - In tap callback:
     - Extract `floatChannelData[0]` samples
     - If device rate != 16kHz: resample via stride (`stride(from: 0, to: count, by: ratio)`)
     - Append to `audioBuffer: [Float]`
     - Check `audioBuffer.count > maxBufferSamples` → auto-stop
     - Calculate RMS: `sqrt(sum(s*s) / N)`, convert to dB: `20 * log10(max(rms, 0.00001))`
     - Normalize to 0–1: `max(0, min(1, (db + 55) / 35))`
     - Send level to callback: `onLevelUpdate: @Sendable (Float) -> Void`
   - `audioEngine.prepare()` then `audioEngine.start()`

2. `stopRecording() -> [Float]?`:
   - `inputNode.removeTap(onBus: 0)` **first**, then `audioEngine.stop()` (order matters — tap callback can fire after stop if reversed)
   - Guard: set `isRecording = false` before stopping so late callbacks are ignored
   - Validate:
     - Duration >= 0.3s? (else return nil — too short)
     - RMS >= -55dB? (else return nil — silence)
   - If duration < 1.5s: append `silencePaddingDuration` seconds of zeros
   - Return `audioBuffer`

3. `cancelRecording()`:
   - `inputNode.removeTap(onBus: 0)`, then `audioEngine.stop()` (same order as stopRecording)
   - Clear `audioBuffer`
   - Return nothing

**Audio device selection:**
- Read from `AudioDeviceManager` on each `startRecording()`
- If custom device selected: set as system default input via `AudioObjectSetPropertyData` with `kAudioHardwarePropertyDefaultInputDevice`

### 5. AudioDeviceManager

**File:** `Sources/Speak2/Audio/AudioDeviceManager.swift`

Enumerates CoreAudio HAL devices and persists user selection.

**Device struct:**
```swift
struct AudioDevice: Identifiable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let hasInput: Bool
    let hasOutput: Bool
}
```

**Enumeration:** Query `kAudioObjectSystemObject` with `kAudioHardwarePropertyDevices` selector. For each device, read:
- `kAudioDevicePropertyDeviceUID` → uid
- `kAudioObjectPropertyName` → name
- Stream count for input/output scopes → hasInput/hasOutput

**Published state:**
```swift
@Observable
class AudioDeviceManager {
    var availableInputDevices: [AudioDevice] = []
    var availableOutputDevices: [AudioDevice] = []
    var useSystemDefaultInput: Bool = true
    var useSystemDefaultOutput: Bool = true
    var selectedInputDeviceUID: String? = nil
    var selectedOutputDeviceUID: String? = nil
}
```

**Persistence:** All selection state saved to `UserDefaults` keys:
- `"useSystemDefaultInput"`, `"useSystemDefaultOutput"`
- `"selectedInputDeviceUID"`, `"selectedOutputDeviceUID"`

### 6. TranscriptionEngine Protocol

**File:** `Sources/Speak2/Transcription/TranscriptionEngine.swift`

```swift
protocol TranscriptionEngine {
    var isReady: Bool { get }
    func loadModel() async throws
    func unloadModel()
    func transcribe(audioSamples: [Float]) async throws -> String
}
```

This protocol exists for future extensibility (WhisperKit, etc.). Speak2 ships with `ParakeetEngine` only.

### 7. ParakeetEngine

**File:** `Sources/Speak2/Transcription/ParakeetEngine.swift`

Wraps FluidAudio's `AsrManager`.

```swift
enum ParakeetVersion: String, CaseIterable {
    case v2 = "parakeet-v2"
    case v3 = "parakeet-v3"

    var displayName: String    // "Parakeet v2", "Parakeet v3"
    var description: String    // "English-optimized", "25 European languages"
    var size: String           // "~600MB"
    var speed: String          // "~110x RTF", "~210x RTF"
    var wer: String            // "1.69%", "1.93%"
    var accuracy: String       // "98.31%", "98.07%"
    var languages: String      // "English", "25 languages"
}
```

**Model storage:** `~/Documents/Speak2/models/`

**Loading flow:**
1. Create `AsrManager()`
2. Create models directory if needed
3. `AsrModels.load(from: modelsDirectory, version: .v2 or .v3)` — downloads if not present
4. `manager.initialize(models: asrModels)`

**Transcription:** `manager.transcribe(audioSamples)` → returns `AsrResult` with `.text`

### 8. EngineManager

**File:** `Sources/Speak2/Transcription/EngineManager.swift`

Coordinates model lifecycle. Observes `AppState.selectedVersion` changes.

```swift
@MainActor
class EngineManager {
    private var engine: ParakeetEngine?
    private var loadTask: Task<Void, Never>?

    func loadModel(version: ParakeetVersion) async throws
    func unloadModel()
    func transcribe(audioSamples: [Float]) async throws -> String
    func isModelDownloaded(version: ParakeetVersion) -> Bool
}
```

**Behavior:**
- On version change: cancel existing `loadTask`, unload current, load new
- Download state updates → `AppState.engineLoadingState`
- `isModelDownloaded()`: check if model files exist at `~/Documents/Speak2/models/` for the version
- Memory: unload model sets engine to nil, releases AsrManager

### 9. HotkeyManager

**File:** `Sources/Speak2/Services/HotkeyManager.swift`

Thin wrapper around KeyboardShortcuts.

**Shortcut registrations:**
```swift
extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording")
    static let toggleRecordingAlt = Self("toggleRecordingAlt")
    static let showHistory = Self("showHistory")
    static let pasteLastTranscription = Self("pasteLastTranscription")
}
```

**Defaults:**
| Name | Shortcut |
|------|----------|
| toggleRecording | Cmd+Opt+Z |
| toggleRecordingAlt | Cmd+Opt+. |
| showHistory | Cmd+Opt+A |
| pasteLastTranscription | Cmd+Opt+V |

**Escape key:** Separate `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` checking `keyCode == 53`. Installed only while recording, removed on stop/cancel. **Important:** Always nil-check and remove existing monitor before installing a new one to prevent duplicate registrations.

### 10. PasteService

**File:** `Sources/Speak2/Services/PasteService.swift`

Pastes text at cursor or copies to clipboard, based on `AppState.autoPasteEnabled`.

**Flow (autoPaste enabled):**
1. Save all current pasteboard types and data
2. `pasteboard.clearContents()`, set transcription as `.string`
3. Simulate Cmd+V via `CGEvent`:
   - keyDown with virtualKey `0x09` (V), flags `.maskCommand`
   - keyUp with virtualKey `0x09`
4. After **0.2 seconds** (`DispatchQueue.main.asyncAfter`):
   - Check frontmost app bundle ID
   - If in problematic apps (`com.apple.finder`, `com.apple.dock`, `com.apple.systempreferences`): show history window as fallback
   - Restore original clipboard contents

**Flow (autoPaste disabled):**
1. `pasteboard.clearContents()`, set transcription as `.string`
2. No Cmd+V simulation, no clipboard restore
3. Notification: "Copied to clipboard"

### 11. NotificationService

**File:** `Sources/Speak2/Services/NotificationService.swift`

Wraps `UNUserNotificationCenter` (modern API, not deprecated `NSUserNotification`).

**Notifications sent:**

| Event | Title | Body |
|-------|-------|------|
| Transcription complete | "Transcription Complete" | First 100 chars of text |
| Transcription error | "Transcription Error" | Error message |
| Recording cancelled | "Recording Cancelled" | "Recording was cancelled" |
| Recording skipped (silence) | "Recording Skipped" | "Audio was too quiet to transcribe" |
| Paste complete | subtitle: "Pasted at cursor" | (on transcription complete) |

**Setup:** Request authorization with `.alert` + `.sound` on first launch.

### 12. TextReplacements

**File:** `Sources/Speak2/Services/TextReplacements.swift`

Loads `config.json` from `~/Documents/Speak2/config.json` and applies text processing. Falls back to working directory `./config.json` if the Documents path doesn't exist (for development convenience).

**Config format:**
```json
{
  "textReplacements": {
    "find_string": "replace_string"
  }
}
```

**Processing pipeline (applied in order):**
1. Apply all find→replace substitutions from config
2. Strip enclosing quotes (4 pair types: `""`, `''`, `""`, `''`)
3. Clean bullet formatting: remove leading `"- "`, remove single leading space, preserve double+ spaces

**API:**
```swift
class TextReplacements {
    static let shared = TextReplacements()
    func processText(_ text: String) -> String
    func reloadConfig()  // re-read config.json from disk
}
```

### 13. TranscriptionHistory

**File:** `Sources/Speak2/Persistence/TranscriptionHistory.swift`

**Storage:** `~/Documents/Speak2/transcription_history.json`

**Data model:**
```swift
struct TranscriptionEntry: Codable, Identifiable {
    let id: UUID
    let text: String
    let timestamp: Date
}
```

**Constraints:**
- Max 100 entries (FIFO — oldest removed when limit exceeded)
- Newest first in array order

**API:**
```swift
class TranscriptionHistory {
    static let shared = TranscriptionHistory()
    func addEntry(_ text: String)          // creates entry with UUID + Date.now
    func getEntries() -> [TranscriptionEntry]
    func deleteEntry(id: UUID)
    func clearAll()
}
```

On `addEntry`: also calls `TranscriptionStats.shared.increment()`.

### 14. TranscriptionStats

**File:** `Sources/Speak2/Persistence/TranscriptionStats.swift`

**Storage:** `~/Documents/Speak2/transcription_stats.json`

```json
{ "totalTranscriptions": 42 }
```

**API:**
```swift
class TranscriptionStats {
    static let shared = TranscriptionStats()
    func getTotalTranscriptions() -> Int
    func increment()
}
```

---

## Settings Window

**File:** `Sources/Speak2/Views/SettingsWindow.swift` + tab views

**Window:** NSWindow hosting SwiftUI, 850x600, resizable (min 600x400). Opened from menu bar. `isReleasedWhenClosed = false` (kept in memory).

**5 tabs** (NSTabViewController-style toolbar):
1. **Settings** (gear icon) — Model selection, glow color, hotkeys
2. **History** (clock icon) — Transcription list
3. **Statistics** (chart.bar icon) — Usage count
4. **Audio Devices** (speaker.wave.2 icon) — Input/output pickers

### Settings Tab (SwiftUI)

**Section 1: Model Selection**

Two Parakeet model cards (v2, v3). Each card shows:
- Radio button (selected state)
- Model name + language badge
- Description
- Size + Speed with icons
- Accuracy bar (color-coded: green >= 97%, blue 95-96.9%, orange 93-94.9%)
- Download/select button (state-aware)

**Model card states:**
- Not downloaded → "Download" button
- Downloading → indeterminate spinner + "Downloading..." (FluidAudio's AsrModels.load() doesn't expose progress callbacks, so no percentage available)
- Downloaded → blue checkmark "Downloaded"
- Loading → spinner "Loading..."
- Loaded → green checkmark "Loaded"

**Section 2: Glow Color**

Horizontal row of color swatches. Each is a rounded circle (~24pt) with the color fill. Selected swatch has a white checkmark overlay. Tapping updates `AppState.glowColor` and persists to UserDefaults.

Colors: Cyan (default), Purple, Green, Pink, Orange, System Accent.

**Section 3: Keyboard Shortcuts**

Uses `KeyboardShortcuts.RecorderCocoa` — the library's built-in shortcut recorder view. Each row:
- Label (e.g., "Toggle Recording") on the left
- Recorder widget on the right (click to record new shortcut)

Shortcuts listed:
- Toggle Recording (default: Cmd+Opt+Z)
- Toggle Recording Alt (default: Cmd+Opt+.)
- Show History (default: Cmd+Opt+A)
- Paste Last Transcription (default: Cmd+Opt+V)

"Reset to Defaults" button below the list.

### History Tab

NSTableView with 3 columns:
- **Transcription** (280px): scrollable text, 12pt system font
- **Actions** (125px): Copy / Delete / Copy & Close buttons
- **Time** (200px): smart formatting ("Today 2:30 PM", "Yesterday 2:30 PM", "Mar 27, 2:30 PM")

Row height: 80px. Alternating row colors. Max 100 entries. "Clear History" button with confirmation alert.

### Statistics Tab

Centered display:
- "Usage Statistics" (16pt bold)
- Total count (48pt bold, accent color)
- "Total Transcriptions" (14pt, secondary)

### Audio Devices Tab

Two sections (input/output), each with:
- Radio: "Follow System Default" / "Use Specific Device"
- Dropdown of available devices (populated from AudioDeviceManager)

---

## Data Flow: Hotkey to Paste

```
1. User presses Cmd+Opt+Z (or Cmd+Opt+.)
2. HotkeyManager fires → AppState.recordingState = .recording
3. GlowOverlay.show(.recording) — cyan bar appears
4. AudioRecorder.startRecording() — installs AVAudioEngine tap
5. Audio callback → level updates → GlowOverlay.updateLevel()
6. User presses hotkey again (or Escape)
7. AudioRecorder.stopRecording() → returns [Float] audio buffer
8. AppState.recordingState = .processing
9. GlowOverlay.show(.processing) — amber pulse
10. TextReplacements.processText(rawTranscription)
11. EngineManager.transcribe(audioSamples) → String
12. TranscriptionHistory.addEntry(text) (also increments stats)
13. AppState.recordingState = .done
14. GlowOverlay.show(.done) — green flash, auto-fades
15. PasteService.pasteAtCursor(text)
16. NotificationService.showTranscriptionComplete(text)
17. After 0.6s → AppState.recordingState = .idle
```

**Error path:** Step 11 throws → `.error` state → red flash → notification → idle after 0.6s

**Cancel path:** Escape at step 6 → `.cancelled` → fade out → idle after 0.3s

**Silence path:** Step 7 returns nil → `.cancelled` → "Recording Skipped" notification → idle

---

## File Layout

```
speak2/
├── Package.swift
├── Sources/
│   ├── Speak2/
│   │   ├── App/
│   │   │   ├── main.swift
│   │   │   ├── AppDelegate.swift
│   │   │   └── AppState.swift
│   │   ├── Overlay/
│   │   │   └── GlowOverlay.swift
│   │   ├── Audio/
│   │   │   ├── AudioRecorder.swift
│   │   │   └── AudioDeviceManager.swift
│   │   ├── Transcription/
│   │   │   ├── TranscriptionEngine.swift
│   │   │   ├── ParakeetEngine.swift
│   │   │   └── EngineManager.swift
│   │   ├── Services/
│   │   │   ├── HotkeyManager.swift
│   │   │   ├── PasteService.swift
│   │   │   ├── NotificationService.swift
│   │   │   └── TextReplacements.swift
│   │   ├── Persistence/
│   │   │   ├── TranscriptionHistory.swift
│   │   │   └── TranscriptionStats.swift
│   │   ├── Views/
│   │   │   ├── SettingsWindow.swift
│   │   │   ├── SettingsView.swift
│   │   │   ├── HistoryView.swift
│   │   │   ├── StatsView.swift
│   │   │   ├── AudioDevicesView.swift
│   │   │   └── ModelCardView.swift
│   │   └── Resources/
│   │       ├── Assets.xcassets
│   │       └── AppIcon.icns
│   └── Speak2Kit/
│       ├── Models/
│       │   ├── ParakeetVersion.swift
│       │   ├── TranscriptionEntry.swift
│       │   └── AudioDevice.swift
│       └── TextProcessing/
│           └── TextReplacementEngine.swift
├── Tests/
│   └── Speak2KitTests/
│       ├── TextReplacementTests.swift
│       └── TranscriptionHistoryTests.swift
├── config.json
├── LICENSE
└── README.md
```
