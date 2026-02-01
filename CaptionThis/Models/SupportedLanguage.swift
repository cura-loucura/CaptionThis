import Foundation

enum SupportedLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en-US"
    case french = "fr-FR"
    case japanese = "ja-JP"
    case portuguese = "pt-BR"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .french: "French"
        case .japanese: "Japanese"
        case .portuguese: "Portuguese"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var languageCode: String {
        switch self {
        case .english: "en"
        case .french: "fr"
        case .japanese: "ja"
        case .portuguese: "pt"
        }
    }
}
