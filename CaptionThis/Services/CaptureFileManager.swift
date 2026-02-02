import Foundation

/// Manages transcription and translation text files for a CaptureThis session.
/// Opens files in append mode so text survives across pause/resume cycles.
final class CaptureFileManager {
    private let directory: URL
    private let baseFileName: String
    private var transcriptionHandle: FileHandle?
    private var translationHandle: FileHandle?

    /// The time when the capture session started.
    /// All timestamps are formatted as offsets from this point.
    private let startTime: Date

    /// Creates (or re-opens) the text files inside the capture directory.
    /// If the directory or files don't exist yet they are created.
    /// Existing files are opened in append mode so pause/resume works correctly.
    init(settings: CaptureSettings, startTime: Date = Date()) throws {
        self.directory = settings.captureDirectory
        self.baseFileName = settings.baseFileName
        self.startTime = startTime

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
        let elapsed = max(0, Int(timestamp.timeIntervalSince(startTime)))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        let ts = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        let entry = "[\(ts)] \(text)\n"
        guard let data = entry.data(using: .utf8) else { return }
        try? handle.write(contentsOf: data)
    }

    deinit {
        close()
    }
}
