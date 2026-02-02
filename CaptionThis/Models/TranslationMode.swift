import Foundation

enum TranslationMode: String, CaseIterable, Identifiable, Codable {
    case live

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .live: "Live"
        }
    }
}
