import Foundation
import Speak2Kit
import SwiftUI

enum PushToTalkKey: String, CaseIterable {
    case none = "none"
    case fn = "fn"
    case rightCommand = "rightCommand"
    case rightOption = "rightOption"
    case rightControl = "rightControl"

    var label: String {
        switch self {
        case .none: return "Disabled"
        case .fn: return "fn"
        case .rightCommand: return "Right ⌘"
        case .rightOption: return "Right ⌥"
        case .rightControl: return "Right ⌃"
        }
    }
}

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

@Observable
@MainActor
final class AppState {
    var recordingState: RecordingState = .idle
    var audioLevel: Double = 0.0
    var selectedVersion: ParakeetVersion = .v2 {
        didSet { UserDefaults.standard.set(selectedVersion.rawValue, forKey: "selectedParakeetVersion") }
    }
    var engineLoadingState: EngineLoadingState = .notDownloaded
    var autoPasteEnabled: Bool {
        didSet { UserDefaults.standard.set(autoPasteEnabled, forKey: "autoPasteEnabled") }
    }
    var glowColor: GlowColor = .cyan
    var onPushToTalkKeyChanged: ((PushToTalkKey) -> Void)?
    var pushToTalkKey: PushToTalkKey = .fn {
        didSet {
            UserDefaults.standard.set(pushToTalkKey.rawValue, forKey: "pushToTalkKey")
            onPushToTalkKeyChanged?(pushToTalkKey)
        }
    }
    var recentTranscription: String?

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "autoPasteEnabled") == nil {
            defaults.set(true, forKey: "autoPasteEnabled")
        }
        self.autoPasteEnabled = defaults.bool(forKey: "autoPasteEnabled")

        if let raw = defaults.string(forKey: "selectedParakeetVersion"),
           let version = ParakeetVersion(rawValue: raw) {
            self.selectedVersion = version
        }
        if let raw = defaults.string(forKey: "glowColor"),
           let color = GlowColor(rawValue: raw) {
            self.glowColor = color
        }
        if let raw = defaults.string(forKey: "pushToTalkKey"),
           let key = PushToTalkKey(rawValue: raw) {
            self.pushToTalkKey = key
        }
    }
}
