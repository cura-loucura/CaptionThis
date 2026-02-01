import Foundation

@Observable
final class SettingsState {
    private static let inputLanguageKey = "inputLanguage"
    private static let captionLanguageKey = "captionLanguage"
    private static let captionEnabledKey = "captionEnabled"
    private static let translationModeKey = "translationMode"
    private static let isPinnedKey = "isPinned"
    private static let audioSourceIDKey = "audioSourceID"

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
            self.translationMode = .live
        }

        self.isPinned = defaults.bool(forKey: Self.isPinnedKey)
        self.audioSourceID = defaults.string(forKey: Self.audioSourceIDKey) ?? AudioSource.microphone.id
    }
}
