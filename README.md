# Speak2

Offline speech-to-text for macOS. Press a hotkey, talk, release — transcribed text is pasted at your cursor.

Everything runs locally on your Mac. No accounts, no API keys, no network requests.


https://github.com/user-attachments/assets/3bbdbff9-a87c-42c9-9029-6540bf22ec9d




## How it works

1. Global hotkey starts recording
2. Audio is transcribed on-device using [Parakeet](https://github.com/FluidInference/FluidAudio) (NVIDIA's speech recognition model)
3. Result is pasted into whatever app has focus

## Install

Requires macOS 14+ and Swift 5.9+.

```bash
swift build
.build/debug/Speak2
```

On first run, grant **Accessibility** and **Microphone** permission to Terminal (System Settings > Privacy & Security).

## Models

The first launch downloads the Parakeet model (~600 MB) from HuggingFace. After that, the app makes zero network requests — everything runs offline.

Models are cached in `~/Library/Application Support/FluidAudio/Models/`. For airgapped machines, copy this directory from a machine that has already downloaded the models.

## Usage

Speak2 lives in the menu bar. Click the icon to configure your hotkey, pick an audio device, or browse transcription history.

That's it. You talk, it types.

### Push-to-talk with Karabiner-Elements

Speak2 supports a dedicated push-to-talk hotkey (`Cmd+Option+Shift+X`) that starts recording on key-down and stops on key-up. You can map any physical key to this with [Karabiner-Elements](https://karabiner-elements.pqrs.org/).

For example, to use the `fn` key as push-to-talk, add this rule to your Karabiner profile's `complex_modifications.rules` array in `~/.config/karabiner/karabiner.json`:

```json
{
    "description": "fn → push-to-talk for Speak2",
    "manipulators": [
        {
            "type": "basic",
            "from": {
                "key_code": "fn",
                "modifiers": { "optional": ["any"] }
            },
            "to": [
                {
                    "key_code": "x",
                    "modifiers": ["left_command", "left_option", "left_shift"]
                }
            ]
        }
    ]
}
```

Karabiner holds the virtual key down while `fn` is pressed and releases it when `fn` is released, giving you hold-to-talk. The existing toggle hotkey (`Cmd+Option+X`) continues to work independently.

> **Note:** This remaps `fn` entirely — you'll lose `fn`+F-key behavior. Swap `"fn"` for another `key_code` if that's a concern.

## License

MIT
