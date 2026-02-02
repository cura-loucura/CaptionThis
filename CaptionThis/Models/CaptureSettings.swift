import Foundation

enum VideoCodec: String, CaseIterable, Identifiable, Codable {
    case h264
    case hevc

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .h264: "H.264"
        case .hevc: "HEVC (H.265)"
        }
    }
}

enum VideoBitrate: String, CaseIterable, Identifiable, Codable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: "Low (~2 Mbps)"
        case .medium: "Medium (~5 Mbps)"
        case .high: "High (~10 Mbps)"
        }
    }

    var bitsPerSecond: Int {
        switch self {
        case .low: 2_000_000
        case .medium: 5_000_000
        case .high: 10_000_000
        }
    }
}

enum VideoResolution: String, CaseIterable, Identifiable, Codable {
    case hd720
    case hd1080
    case native

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hd720: "720p"
        case .hd1080: "1080p"
        case .native: "Native"
        }
    }

    var dimensions: (width: Int, height: Int)? {
        switch self {
        case .hd720: (1280, 720)
        case .hd1080: (1920, 1080)
        case .native: nil
        }
    }
}

struct CaptureSettings {
    var isEnabled: Bool = false
    var baseFileName: String = "capture"
    var videoCodec: VideoCodec = .hevc
    var videoBitrate: VideoBitrate = .medium
    var videoResolution: VideoResolution = .hd1080
    var frameRate: Int = 30
    var outputDirectory: URL

    static let defaultOutputDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("CaptionThis/captured", isDirectory: true)
    }()

    static let availableFrameRates = [15, 24, 30]

    init() {
        self.outputDirectory = Self.defaultOutputDirectory
    }

    var captureDirectory: URL {
        outputDirectory.appendingPathComponent(baseFileName, isDirectory: true)
    }

    var captureDirectoryExists: Bool {
        FileManager.default.fileExists(atPath: captureDirectory.path)
    }

    var isBaseFileNameValid: Bool {
        let trimmed = baseFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return trimmed.rangeOfCharacter(from: illegal) == nil
    }
}
