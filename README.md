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

## License

MIT
