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

            // MARK: Glow Color
            Section("Glow Color") {
                HStack(spacing: 12) {
                    ForEach(GlowColor.allCases, id: \.self) { color in
                        Button {
                            appState.glowColor = color
                            UserDefaults.standard.set(color.rawValue, forKey: "glowColor")
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 24, height: 24)
                                if appState.glowColor == color {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .help(color.rawValue.capitalized)
                    }
                }
            }

            // MARK: Keyboard Shortcuts
            Section("Keyboard Shortcuts") {
                shortcutRow("Toggle Recording", name: .toggleRecording)
                shortcutRow("Toggle Recording Alt", name: .toggleRecordingAlt)
                shortcutRow("Show History", name: .showHistory)
                shortcutRow("Paste Last", name: .pasteLastTranscription)

                Button("Reset to Defaults") {
                    KeyboardShortcuts.reset([
                        .toggleRecording,
                        .toggleRecordingAlt,
                        .showHistory,
                        .pasteLastTranscription,
                    ])
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            refreshDownloadedState()
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
