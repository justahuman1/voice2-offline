public enum ParakeetVersion: String, CaseIterable, Sendable {
    case v2 = "parakeet-v2"
    case v3 = "parakeet-v3"

    public var displayName: String {
        switch self {
        case .v2: return "Parakeet v2"
        case .v3: return "Parakeet v3"
        }
    }

    public var description: String {
        switch self {
        case .v2: return "English-optimized"
        case .v3: return "25 European languages"
        }
    }

    public var size: String { "~600MB" }

    public var speed: String {
        switch self {
        case .v2: return "~110x RTF"
        case .v3: return "~210x RTF"
        }
    }

    public var wer: String {
        switch self {
        case .v2: return "1.69%"
        case .v3: return "1.93%"
        }
    }

    public var accuracy: String {
        switch self {
        case .v2: return "98.31%"
        case .v3: return "98.07%"
        }
    }

    public var languages: String {
        switch self {
        case .v2: return "English"
        case .v3: return "25 languages"
        }
    }
}
