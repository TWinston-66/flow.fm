import Foundation

/// The DEF CON Radio stream formats SomaFM offers. Raw values are persisted, so don't rename them.
enum StreamQuality: String, CaseIterable, Identifiable {
    case aac128
    case aac64
    case aac32
    case mp3_256
    case mp3_128

    var id: Self { self }

    var label: String {
        switch self {
        case .aac128: "AAC 128k"
        case .aac64: "AAC 64k"
        case .aac32: "AAC 32k"
        case .mp3_256: "MP3 256k"
        case .mp3_128: "MP3 128k"
        }
    }

    /// SomaFM's playlist for this quality; it lists the current mirrors.
    var playlistURL: URL {
        let name = switch self {
        case .aac128: "defcon130"
        case .aac64: "defcon64"
        case .aac32: "defcon32"
        case .mp3_256: "defcon256"
        case .mp3_128: "defcon"
        }
        return URL(string: "https://somafm.com/\(name).pls")!
    }

    /// Known mirrors, used when the playlist itself can't be fetched.
    var fallbackMirrors: [URL] {
        let path = switch self {
        case .aac128: "defcon-128-aac"
        case .aac64: "defcon-64-aac"
        case .aac32: "defcon-32-aac"
        case .mp3_256: "defcon-256-mp3"
        case .mp3_128: "defcon-128-mp3"
        }
        return ["ice2", "ice5", "ice6"].map { URL(string: "https://\($0).somafm.com/\(path)")! }
    }
}
