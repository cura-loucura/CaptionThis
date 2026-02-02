import Foundation

/// Manages transcription and translation text files for a CaptureThis session.
/// Opens files in append mode so text survives across pause/resume cycles.
final class CaptureFileManager {
    private let directory: URL
    private let baseFileName: String
    private var transcriptionHandle: FileHandle?
    private var translationHandle: FileHandle?

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    /// Creates (or re-opens) the text files inside the capture directory.
    /// If the directory or files don't exist yet they are created.
    /// Existing files are opened in append mode so pause/resume works correctly.
    init(settings: CaptureSettings) throws {
        self.directory = settings.captureDirectory
        self.baseFileName = settings.baseFileName

        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let transcriptionURL = directory.appendingPathComponent("\(baseFileName)_transcription.txt")
        let translationURL = directory.appendingPathComponent("\(baseFileName)_translation.txt")

        // Create the files only if they don't already exist
        if !fm.fileExists(atPath: transcriptionURL.path) {
            fm.createFile(atPath: transcriptionURL.path, contents: nil)
        }
        if !fm.fileExists(atPath: translationURL.path) {
            fm.createFile(atPath: translationURL.path, contents: nil)
        }

        transcriptionHandle = try FileHandle(forWritingTo: transcriptionURL)
        translationHandle = try FileHandle(forWritingTo: translationURL)

        // Seek to end for append mode
        transcriptionHandle?.seekToEndOfFile()
        translationHandle?.seekToEndOfFile()
    }

    func appendTranscription(_ text: String, timestamp: Date) {
        write(text, timestamp: timestamp, to: transcriptionHandle)
    }

    func appendTranslation(_ text: String, timestamp: Date) {
        write(text, timestamp: timestamp, to: translationHandle)
    }

    func close() {
        try? transcriptionHandle?.close()
        try? translationHandle?.close()
        transcriptionHandle = nil
        translationHandle = nil
    }

    // MARK: - Private

    private func write(_ text: String, timestamp: Date, to handle: FileHandle?) {
        guard let handle else { return }
        let entry = "[\(Self.timestampFormatter.string(from: timestamp))] \(text)\n"
        guard let data = entry.data(using: .utf8) else { return }
        try? handle.write(contentsOf: data)
    }

    deinit {
        close()
    }
}
