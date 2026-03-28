import SwiftUI

struct ModelMetadata {
    let displayName: String
    let description: String
    let size: String
    let speed: String
    let wer: String
    let accuracy: String
    let accuracyValue: Double
    let languages: String

    static func metadata(for version: ParakeetVersion) -> ModelMetadata {
        switch version {
        case .v2:
            return ModelMetadata(
                displayName: "Parakeet v2",
                description: "English-optimized, highest accuracy",
                size: "~600MB",
                speed: "~110x RTF",
                wer: "1.69% WER",
                accuracy: "98.31%",
                accuracyValue: 98.31,
                languages: "English"
            )
        case .v3:
            return ModelMetadata(
                displayName: "Parakeet v3",
                description: "Multi-language support",
                size: "~600MB",
                speed: "~210x RTF",
                wer: "1.93% WER",
                accuracy: "98.07%",
                accuracyValue: 98.07,
                languages: "25 languages"
            )
        }
    }
}

struct ModelCardView: View {
    let version: ParakeetVersion
    let isSelected: Bool
    let loadingState: EngineLoadingState
    let isDownloaded: Bool
    let onTap: () -> Void

    private var metadata: ModelMetadata {
        .metadata(for: version)
    }

    private var accuracyBarColor: Color {
        if metadata.accuracyValue >= 97.0 {
            return .green
        } else if metadata.accuracyValue >= 95.0 {
            return .blue
        } else if metadata.accuracyValue >= 93.0 {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Radio button
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 6) {
                    // Title row
                    HStack {
                        Text(metadata.displayName)
                            .font(.headline)
                        Text(metadata.languages)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }

                    // Description
                    Text(metadata.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Metadata row
                    HStack(spacing: 16) {
                        Label(metadata.size, systemImage: "internaldrive")
                        Label(metadata.speed, systemImage: "bolt")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Accuracy bar
                    HStack(spacing: 8) {
                        Text(metadata.accuracy)
                            .font(.caption.monospacedDigit())
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.quaternary)
                                Capsule()
                                    .fill(accuracyBarColor)
                                    .frame(width: geo.size.width * metadata.accuracyValue / 100.0)
                            }
                        }
                        .frame(height: 6)
                    }
                }

                Spacer()

                // State indicator
                stateView
            }
            .padding(12)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var stateView: some View {
        if isSelected {
            switch loadingState {
            case .notDownloaded:
                Label("Download", systemImage: "arrow.down.circle")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            case .downloading(let progress):
                VStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            case .downloaded:
                Label("Downloaded", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .loading:
                VStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            case .loaded:
                Label("Loaded", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        } else if isDownloaded {
            Label("Downloaded", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Label("Download", systemImage: "arrow.down.circle")
                .font(.caption)
                .foregroundStyle(Color.accentColor)
        }
    }
}
