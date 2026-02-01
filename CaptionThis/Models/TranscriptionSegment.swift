import Foundation

struct TranscriptionSegment: Identifiable {
    let id = UUID()
    let originalText: String
    var translatedText: String?
    let timestamp: Date

    init(originalText: String, translatedText: String? = nil, timestamp: Date = Date()) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.timestamp = timestamp
    }
}
