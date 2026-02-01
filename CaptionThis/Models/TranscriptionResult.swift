import Foundation

struct TranscriptionResult: Sendable {
    /// The full transcription text accumulated so far (including previous segments).
    var fullText: String

    /// The latest partial or finalized segment from the current recognition task.
    var latestSegment: String

    /// Text that has been finalized (will not change).
    var finalizedText: String

    /// Whether this result represents a final (non-partial) recognition result.
    var isFinal: Bool
}
