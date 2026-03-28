# Speak2

A menu-bar-only macOS app that records speech via global hotkeys, transcribes on-device using [Parakeet](https://github.com/huggingface/swift-transformers) (FluidAudio), and pastes the result at your cursor.

## Features

- **Menu-bar only** -- no Dock icon, lives entirely in the status bar
- **On-device transcription** using Parakeet (FluidAudio) -- your audio never leaves your Mac
  - **Parakeet v2** -- English only, fast and lightweight
  - **Parakeet v3** -- 25 languages supported
- **Global hotkey recording** -- start/stop recording from any app
- **Bottom-edge glow bar** overlay showing recording state (customizable color)
- **Auto-paste** transcribed text at cursor position, or copy to clipboard
- **Text replacements** via `config.json` for common corrections
- **Transcription history** -- stores up to 100 recent entries
- **Customizable keyboard shortcuts** via Settings
- **Audio device selection** -- choose input and output devices

## Requirements

- macOS 14.0+
- Swift 5.9+
- Microphone permission
- Accessibility permission (for simulated paste via `CGEvent`)

## Installation

```bash
git clone <repo>
cd speak2
swift build
swift run Speak2
```

## Permissions Setup

Speak2 requires two system permissions:

1. **Microphone**: System Settings > Privacy & Security > Microphone > enable for Speak2 (or Terminal, if running from the command line)
2. **Accessibility**: System Settings > Privacy & Security > Accessibility > add Speak2 (or Terminal)

The Accessibility permission is needed to simulate `Cmd+V` paste events via `CGEvent`.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Cmd+Opt+Z | Toggle recording |
| Cmd+Opt+. | Toggle recording (alternate) |
| Cmd+Opt+A | Show history |
| Cmd+Opt+V | Paste last transcription |
| Escape | Cancel recording |

All shortcuts are customizable in Settings.

## Configuration

Text replacements are loaded from `~/Documents/Speak2/config.json`, falling back to `./config.json` in the working directory:

```json
{
  "textReplacements": {
    "gonna": "going to",
    "wanna": "want to"
  }
}
```

## Architecture

Speak2 is structured as two Swift Package Manager targets:

- **Speak2** -- the executable target. Menu-bar app entry point, SwiftUI settings window, glow-bar overlay, and hotkey registration.
- **Speak2Kit** -- shared library. Models, transcription logic, audio recording (`AVAudioEngine`), configuration, and history persistence.

Recording flow: global hotkey triggers `AVAudioEngine` capture, audio is transcribed on-device via FluidAudio's Parakeet model, then the result is pasted at the cursor using a simulated `Cmd+V` via `CGEvent` (or copied to the clipboard).

## License

[MIT](LICENSE)
