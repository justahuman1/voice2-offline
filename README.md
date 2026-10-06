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

Normal runs and setup build the optimized **Release** configuration. Kokoro's Swift inference/MLX graph-building work should not be benchmarked in an unoptimized Debug build. To build and launch Debug explicitly, use `./run.sh debug`. The first Release build after switching configurations can take longer; subsequent builds are incremental. The launcher prints its configuration so timing comparisons are unambiguous.

MLX's Metal shaders must be compiled by Xcode; a plain `swift build` can compile Speak2 but will fail when Kokoro runs. Setup downloads Apple's Metal Toolchain and prebuilds the dependencies.

On first run, grant **Accessibility** and **Microphone** permission to the terminal app you use (System Settings > Privacy & Security).

## Models

Speak2 uses separate local models for speech recognition and speech generation:

| Model | Use case | Runtime | Download |
|---|---|---|---|
| Parakeet v2 (default) or v3 | Microphone speech → text | FluidAudio; on-device | Selected model, ~600 MB. v2 is English-focused; v3 supports 25 languages. |
| Kokoro-82M | Selected text → speech | MLX on Apple Silicon | ~310 MB model weights plus the `af_heart` voice. |

Parakeet downloads on first launch. Kokoro can be downloaded from **Settings → Text-to-Speech Model** or on the first read. After download, both models run locally. Parakeet files are cached in `~/Library/Application Support/FluidAudio/Models/`; Kokoro files are cached in `~/Library/Application Support/Speak2/Kokoro/`. For airgapped machines, copy these directories from a machine that has already downloaded the models.

## Usage

Speak2 lives in the menu bar. Click the icon to configure your hotkeys, pick an audio device, or browse transcription history.

| Read command | Default shortcut | Text source |
|---|---|---|
| Read Selection | `Cmd+Option+R` | Focused app's Accessibility selection; never touches the clipboard. |
| Read Clipboard | `Cmd+Option+C` | Copy text yourself first, then invoke; clipboard contents are read but never changed. |
| Read Screen Region | `Cmd+Option+O` | Drag a rectangle over visible text; Apple Vision recognizes it locally. Escape cancels. |

All three commands use the same local Kokoro voice. While capture, OCR, generation, or playback is active, any read command cancels/stops it instead of starting another read. Configure shortcuts under **Settings → Keyboard Shortcuts**. Clipboard reading works with copied text from Firefox or Ghostty even when their Accessibility selection is unavailable; empty or non-text clipboards produce an error.

### Region OCR

The first OCR request asks for **Screen Recording** permission (called **Screen & System Audio Recording** on newer macOS). Enable Speak2 or its launching terminal under **System Settings → Privacy & Security**, restart if macOS requires it, and retry. No OCR model download or API key is needed.

Press `Cmd+Option+O`, drag over text on one display, and release to read it. Screenshots remain in memory—nothing is saved, uploaded, or copied to the clipboard, and recognized text is not logged. Capture panels are excluded from the image. Escape, another read command, or starting a recording cancels the operation; in-flight capture/OCR may finish, but cancelled results cannot start speech.

Recognition is configured for English to match the current Kokoro voice. OCR sees only visible pixels: it cannot recover off-screen selections, and complex columns, small fonts, or protected content can produce missing or misordered text. For selectable text in Firefox or Ghostty, copying and using **Read Clipboard** is usually more accurate.

#### Debugging region OCR

Quit the existing Speak2 process, launch `./run.sh` from your terminal, and reproduce with the configured OCR shortcut (default `Cmd+Option+O`). Terminal logs tagged `[ReadSpeech]` show shortcut registration, received/ignored requests, and playback; `[ScreenOCR]` traces permission, region selection, ScreenCaptureKit metadata/capture, and Vision recognition. Failures include the stage, error domain/code, and elapsed time. These diagnostics never log screenshots, recognized text, window titles, or clipboard contents.

If permission is denied despite the Settings toggle, restart both Speak2 and the launching terminal before retrying. Logged process/parent metadata helps identify the launch context but does not authoritatively identify which app macOS attributes the permission to. Share only the `[ScreenOCR]` and `[ReadSpeech]` lines for troubleshooting.

### Speaking status

The bottom glow reacts to audio while recording or speaking. Configure **Recording** and **Speaking** colors independently under **Settings → Glow Color**; speaking defaults to purple and your existing recording color is preserved. There is no percentage or estimated remaining time, and ordinary synthesis stays visually quiet. The speaking glow stays visible between chunks and disappears when reading finishes or is stopped.

Recording takes priority: starting a recording stops speech playback and cancels pending generation. Read requests are ignored while recording or transcribing. Cancellation silences playback immediately, although an in-flight model inference may finish before its result is discarded.

Speech starts after a small sentence-aware chunk is generated, while subsequent chunks are synthesized during playback. Word-count targets are soft: complete sentences are preserved for natural phrasing, except where Kokoro's own input limit requires splitting. Audio is queued directly as PCM rather than packaging the entire selection as a WAV. First use still includes model and phonemizer initialization.

That's it. You talk, it types—and now it can talk back.

### Push-to-talk

Hold the `fn` key to record, release to transcribe and paste. Works out of the box — no extra configuration needed. The toggle hotkey (`Cmd+Option+X`) continues to work independently.

There's also a dedicated push-to-talk hotkey (`Cmd+Option+Shift+X`) you can map to any key via [Karabiner-Elements](https://karabiner-elements.pqrs.org/) or similar tools.

## License

MIT
