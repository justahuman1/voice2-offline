import Foundation
import SwiftUI

enum RecordingState {
    case idle
    case recording
    case processing
    case done
    case error
    case cancelled
}

enum EngineLoadingState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case loading
    case loaded
}

enum ParakeetVersion: String, CaseIterable {
    case v2
    case v3
}

enum GlowColor: String, CaseIterable {
    case cyan
    case purple
    case green
    case pink
    case orange
    case system
}

@Observable
@MainActor
final class AppState {
    var recordingState: RecordingState = .idle
    var audioLevel: Double = 0.0
    var selectedVersion: ParakeetVersion = .v2
    var engineLoadingState: EngineLoadingState = .notDownloaded
    var autoPasteEnabled: Bool {
        didSet { UserDefaults.standard.set(autoPasteEnabled, forKey: "autoPasteEnabled") }
    }
    var glowColor: GlowColor = .cyan
    var recentTranscription: String?

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "autoPasteEnabled") == nil {
            defaults.set(true, forKey: "autoPasteEnabled")
        }
        self.autoPasteEnabled = defaults.bool(forKey: "autoPasteEnabled")
    }
}
