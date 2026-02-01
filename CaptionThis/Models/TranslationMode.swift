import Foundation

enum TranslationMode: String, CaseIterable, Identifiable, Codable {
    case live
    case delayed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .live: "Live"
        case .delayed: "Delayed"
        }
    }
}
