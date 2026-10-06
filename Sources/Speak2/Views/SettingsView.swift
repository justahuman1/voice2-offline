import KeyboardShortcuts
import Speak2Kit
import SwiftUI

// MARK: - ShortcutRecorder (NSViewRepresentable wrapper)

struct ShortcutRecorder: NSViewRepresentable {
    let name: KeyboardShortcuts.Name

    func makeNSView(context: Context) -> KeyboardShortcuts.RecorderCocoa {
        KeyboardShortcuts.RecorderCocoa(for: name)
    }

    func updateNSView(_ nsView: KeyboardShortcuts.RecorderCocoa, context: Context) {}
}

// MARK: - SettingsView

struct SettingsView: View {
    var appState: AppState
    var engineManager: EngineManager

    @State private var downloadedVersions: Set<ParakeetVersion> = []

    var body: some View {
        Form {
            // MARK: Model Selection
            Section("Model") {
                VStack(spacing: 8) {
                    ForEach(ParakeetVersion.allCases, id: \.self) { version in
                        ModelCardView(
                            version: version,
                            isSelected: appState.selectedVersion == version,
                            loadingState: appState.selectedVersion == version
                                ? appState.engineLoadingState
                                : .notDownloaded,
                            isDownloaded: downloadedVersions.contains(version),
                            onTap: { selectModel(version) }
                        )
                    }
                }
            }

            // MARK: Text-to-Speech Model
            Section("Text-to-Speech Model") {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kokoro-82M · MLX")
                            .font(.headline)
                        Text("Local neural speech · voice af_heart · ~310 MB")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    kokoroStateView
                }
                .padding(.vertical, 4)
            }

            // MARK: Glow Color
            Section("Glow Color") {
                glowColorRow("Recording", selection: Bindable(appState).glowColor)
                glowColorRow("Speaking", selection: Bindable(appState).speakingGlowColor)
            }

            // MARK: Keyboard Shortcuts
            Section("Keyboard Shortcuts") {
                shortcutRow("Toggle Recording", name: .toggleRecording)
                shortcutRow("Toggle Recording Alt", name: .toggleRecordingAlt)
                shortcutRow("Push-to-Talk (combo)", name: .pushToTalk)
                shortcutRow("Show History", name: .showHistory)
                shortcutRow("Paste Last", name: .pasteLastTranscription)
                shortcutRow("Read Selection / Stop", name: .readSelection)
                shortcutRow("Read Clipboard / Stop", name: .readClipboard)
                shortcutRow("Read Screen Region / Stop", name: .readScreenRegion)
                Text("Region OCR uses Apple Vision locally and requires Screen Recording permission. Clipboard reading never changes your clipboard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Push-to-Talk Key", selection: Bindable(appState).pushToTalkKey) {
                    ForEach(PushToTalkKey.allCases, id: \.self) { key in
                        Text(key.label).tag(key)
                    }
                }

                Button("Reset to Defaults") {
                    KeyboardShortcuts.reset([
                        .toggleRecording,
                        .toggleRecordingAlt,
                        .pushToTalk,
                        .showHistory,
                        .pasteLastTranscription,
                        .readSelection,
                        .readClipboard,
                        .readScreenRegion,
                    ])
                    appState.pushToTalkKey = .fn
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            refreshDownloadedState()
            refreshKokoroState()
        }
    }

    private func glowColorRow(_ label: String, selection: Binding<GlowColor>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: 80, alignment: .leading)
            ForEach(GlowColor.allCases, id: \.self) { color in
                Button {
                    selection.wrappedValue = color
                } label: {
                    ZStack {
                        Circle()
                            .fill(color.swiftUIColor)
                            .frame(width: 24, height: 24)
                        if selection.wrappedValue == color {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(color.rawValue.capitalized)
                .accessibilityLabel("\(label) glow: \(color.rawValue)")
            }
        }
    }

    private func shortcutRow(_ label: String, name: KeyboardShortcuts.Name) -> some View {
        HStack {
            Text(label)
            Spacer()
            ShortcutRecorder(name: name)
                .frame(width: 160)
        }
    }

    @ViewBuilder
    private var kokoroStateView: some View {
        switch appState.kokoroModelState {
        case .notDownloaded:
            Button("Download") {
                downloadKokoroModel()
            }
        case .downloading(let status):
            VStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 180, alignment: .trailing)
            }
        case .downloaded:
            Label("Downloaded", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .loading:
            VStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .loaded:
            Label("Loaded", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    private func refreshKokoroState() {
        Task { @MainActor in
            if await KokoroSpeechEngine.shared.isDownloaded(), appState.kokoroModelState == .notDownloaded {
                appState.kokoroModelState = .downloaded
            }
        }
    }

    private func downloadKokoroModel() {
        appState.kokoroModelState = .downloading(status: "Preparing download…")
        Task { @MainActor in
            do {
                try await KokoroSpeechEngine.shared.downloadAssets { status in
                    appState.kokoroModelState = .downloading(status: status)
                }
                appState.kokoroModelState = .downloaded
            } catch {
                appState.kokoroModelState = await KokoroSpeechEngine.shared.isDownloaded() ? .downloaded : .notDownloaded
                NSLog("[Kokoro] Download failed: %@", error.localizedDescription)
                NotificationService.shared.showError(message: "Kokoro download failed: \(error.localizedDescription)")
            }
        }
    }

    private func selectModel(_ version: ParakeetVersion) {
        appState.selectedVersion = version
        if engineManager.isModelDownloaded(version: version) {
            engineManager.loadModel(version: version)
        } else {
            engineManager.downloadAndLoadModel(version: version)
        }
        refreshDownloadedState()
    }

    private func refreshDownloadedState() {
        downloadedVersions = Set(
            ParakeetVersion.allCases.filter { engineManager.isModelDownloaded(version: $0) }
        )
    }
}

// MARK: - GlowColor SwiftUI helpers

extension GlowColor {
    var swiftUIColor: Color {
        switch self {
        case .cyan: return Color(red: 0, green: 0.749, blue: 1)         // #00BFFF
        case .purple: return Color(red: 0.749, green: 0.353, blue: 0.949) // #BF5AF2
        case .green: return Color(red: 0.188, green: 0.820, blue: 0.345)  // #30D158
        case .pink: return Color(red: 1, green: 0.216, blue: 0.373)       // #FF375F
        case .orange: return Color(red: 1, green: 0.624, blue: 0.039)     // #FF9F0A
        case .system: return Color(nsColor: .controlAccentColor)
        }
    }
}
