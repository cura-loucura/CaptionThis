import Foundation

@Observable
final class SettingsState {
    private static let inputLanguageKey = "inputLanguage"
    private static let captionLanguageKey = "captionLanguage"
    private static let captionEnabledKey = "captionEnabled"
    private static let translationModeKey = "translationMode"
    private static let isPinnedKey = "isPinned"
    private static let audioSourceIDKey = "audioSourceID"
    private static let captureBaseFileNameKey = "captureBaseFileName"
    private static let captureVideoCodecKey = "captureVideoCodec"
    private static let captureVideoBitrateKey = "captureVideoBitrate"
    private static let captureVideoResolutionKey = "captureVideoResolution"
    private static let captureFrameRateKey = "captureFrameRate"
    private static let captureOutputDirectoryKey = "captureOutputDirectory"
    private static let captureMinutesKey = "captureMinutes"

    var inputLanguage: SupportedLanguage {
        didSet { UserDefaults.standard.set(inputLanguage.rawValue, forKey: Self.inputLanguageKey) }
    }

    var captionLanguage: SupportedLanguage {
        didSet { UserDefaults.standard.set(captionLanguage.rawValue, forKey: Self.captionLanguageKey) }
    }

    var captionEnabled: Bool {
        didSet { UserDefaults.standard.set(captionEnabled, forKey: Self.captionEnabledKey) }
    }

    var translationMode: TranslationMode {
        didSet { UserDefaults.standard.set(translationMode.rawValue, forKey: Self.translationModeKey) }
    }

    var isPinned: Bool {
        didSet { UserDefaults.standard.set(isPinned, forKey: Self.isPinnedKey) }
    }

    var audioSourceID: String {
        didSet { UserDefaults.standard.set(audioSourceID, forKey: Self.audioSourceIDKey) }
    }

    // MARK: - Capture Settings (persistent except isEnabled)

    /// Not persisted — always false on app launch.
    var captureIsEnabled: Bool = false

    var captureBaseFileName: String {
        didSet { UserDefaults.standard.set(captureBaseFileName, forKey: Self.captureBaseFileNameKey) }
    }

    var captureVideoCodec: VideoCodec {
        didSet { UserDefaults.standard.set(captureVideoCodec.rawValue, forKey: Self.captureVideoCodecKey) }
    }

    var captureVideoBitrate: VideoBitrate {
        didSet { UserDefaults.standard.set(captureVideoBitrate.rawValue, forKey: Self.captureVideoBitrateKey) }
    }

    var captureVideoResolution: VideoResolution {
        didSet { UserDefaults.standard.set(captureVideoResolution.rawValue, forKey: Self.captureVideoResolutionKey) }
    }

    var captureFrameRate: Int {
        didSet { UserDefaults.standard.set(captureFrameRate, forKey: Self.captureFrameRateKey) }
    }

    var captureOutputDirectory: URL {
        didSet { UserDefaults.standard.set(captureOutputDirectory.path, forKey: Self.captureOutputDirectoryKey) }
    }

    /// The number of minutes after which recording should automatically stop (0 = disabled)
    var captureMinutes: Int {
        didSet { UserDefaults.standard.set(captureMinutes, forKey: Self.captureMinutesKey) }
    }

    /// Builds a `CaptureSettings` snapshot from the current persisted values.
    var captureSettings: CaptureSettings {
        get {
            var s = CaptureSettings()
            s.isEnabled = captureIsEnabled
            s.baseFileName = captureBaseFileName
            s.videoCodec = captureVideoCodec
            s.videoBitrate = captureVideoBitrate
            s.videoResolution = captureVideoResolution
            s.frameRate = captureFrameRate
            s.outputDirectory = captureOutputDirectory
            return s
        }
        set {
            captureIsEnabled = newValue.isEnabled
            captureBaseFileName = newValue.baseFileName
            captureVideoCodec = newValue.videoCodec
            captureVideoBitrate = newValue.videoBitrate
            captureVideoResolution = newValue.videoResolution
            captureFrameRate = newValue.frameRate
            captureOutputDirectory = newValue.outputDirectory
        }
    }

    init() {
        let defaults = UserDefaults.standard

        if let raw = defaults.string(forKey: Self.inputLanguageKey),
           let lang = SupportedLanguage(rawValue: raw) {
            self.inputLanguage = lang
        } else {
            self.inputLanguage = .english
        }

        if let raw = defaults.string(forKey: Self.captionLanguageKey),
           let lang = SupportedLanguage(rawValue: raw) {
            self.captionLanguage = lang
        } else {
            self.captionLanguage = .portuguese
        }

        if defaults.object(forKey: Self.captionEnabledKey) != nil {
            self.captionEnabled = defaults.bool(forKey: Self.captionEnabledKey)
        } else {
            self.captionEnabled = true
        }

        if let raw = defaults.string(forKey: Self.translationModeKey),
           let mode = TranslationMode(rawValue: raw) {
            self.translationMode = mode
        } else {
            // Default to live mode instead of delayed
            self.translationMode = .live
        }

        self.isPinned = defaults.bool(forKey: Self.isPinnedKey)
        self.audioSourceID = defaults.string(forKey: Self.audioSourceIDKey) ?? AudioSource.microphone.id

        // Capture settings (persistent except isEnabled which defaults to false)
        self.captureBaseFileName = defaults.string(forKey: Self.captureBaseFileNameKey) ?? "capture"

        if let raw = defaults.string(forKey: Self.captureVideoCodecKey),
           let codec = VideoCodec(rawValue: raw) {
            self.captureVideoCodec = codec
        } else {
            self.captureVideoCodec = .hevc
        }

        if let raw = defaults.string(forKey: Self.captureVideoBitrateKey),
           let bitrate = VideoBitrate(rawValue: raw) {
            self.captureVideoBitrate = bitrate
        } else {
            self.captureVideoBitrate = .medium
        }

        if let raw = defaults.string(forKey: Self.captureVideoResolutionKey),
           let resolution = VideoResolution(rawValue: raw) {
            self.captureVideoResolution = resolution
        } else {
            self.captureVideoResolution = .hd1080
        }

        if defaults.object(forKey: Self.captureFrameRateKey) != nil {
            self.captureFrameRate = defaults.integer(forKey: Self.captureFrameRateKey)
        } else {
            self.captureFrameRate = 30
        }

        if let path = defaults.string(forKey: Self.captureOutputDirectoryKey) {
            self.captureOutputDirectory = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            self.captureOutputDirectory = CaptureSettings.defaultOutputDirectory
        }

        // New capture minutes setting
        self.captureMinutes = defaults.integer(forKey: Self.captureMinutesKey)
    }
}
