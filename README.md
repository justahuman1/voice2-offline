# Speak2

Offline speech-to-text for macOS. Press a hotkey, talk, release — transcribed text is pasted at your cursor.

After downloading the models, everything runs locally on your Mac. No accounts or API keys.


https://github.com/user-attachments/assets/3bbdbff9-a87c-42c9-9029-6540bf22ec9d




## How it works

1. Global hotkey starts recording
2. Audio is transcribed on-device using [Parakeet](https://github.com/FluidInference/FluidAudio) (NVIDIA's speech recognition model)
3. Result is pasted into whatever app has focus

## Install

Requires macOS 14+ and Swift 5.9+.

Run setup once to install Xcode's Metal Toolchain and perform the slow initial build:

```bash
./run.sh setup
```

Then build and launch with:

```bash
./run.sh
```

MLX's Metal shaders must be compiled by Xcode; a plain `swift build` can compile Speak2 but will fail when Kokoro runs. Setup downloads Apple's Metal Toolchain and prebuilds the dependencies; subsequent `./run.sh` calls are incremental.

On first run, grant **Accessibility** and **Microphone** permission to the terminal app you use (System Settings > Privacy & Security).

## Models

Speak2 uses separate local models for speech recognition and speech generation:

| Model | Use case | Runtime | Download |
|---|---|---|---|
| Parakeet v2 (default) or v3 | Microphone speech → text | FluidAudio; on-device | Selected model, ~600 MB. v2 is English-focused; v3 supports 25 languages. |
| Kokoro-82M | Selected text → speech | MLX on Apple Silicon | ~310 MB model weights plus the `af_heart` voice. |

Parakeet downloads on first launch. Kokoro can be downloaded from **Settings → Text-to-Speech Model** or on the first read. After download, both models run locally. Parakeet files are cached in `~/Library/Application Support/FluidAudio/Models/`; Kokoro files are cached in `~/Library/Application Support/Speak2/Kokoro/`. For airgapped machines, copy these directories from a machine that has already downloaded the models.

## Usage

Speak2 lives in the menu bar. Click the icon to configure your hotkeys, pick an audio device, or browse transcription history. Select text in an app and press `Cmd+Option+R` to read it aloud with the local Kokoro voice; press again to stop. This does not use or modify the clipboard.

That's it. You talk, it types—and now it can talk back.

### Push-to-talk

Hold the `fn` key to record, release to transcribe and paste. Works out of the box — no extra configuration needed. The toggle hotkey (`Cmd+Option+X`) continues to work independently.

There's also a dedicated push-to-talk hotkey (`Cmd+Option+Shift+X`) you can map to any key via [Karabiner-Elements](https://karabiner-elements.pqrs.org/) or similar tools.

## License

MIT
