import AVFoundation

enum VideoProcessingState {
    case idle
    case processing
    case completed
    case failed(String)
}

@MainActor
@Observable
final class VideoProcessingService {
    private(set) var state: VideoProcessingState = .idle
    private(set) var progress: Double = 0.0

    private var exportSession: AVAssetExportSession?
    private var progressTask: Task<Void, Never>?

    /// Merges the given segment files into a single `.mp4` and writes it
    /// to `<captureDirectory>/<baseFileName>_final.mp4`.
    /// Segments are already compressed, so passthrough (no re-encoding) is used.
    func process(segmentURLs: [URL], settings: CaptureSettings) async {
        // Filter to only existing, non-empty segment files
        let fm = FileManager.default
        let validURLs = segmentURLs.filter { url in
            guard fm.fileExists(atPath: url.path) else { return false }
            let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
            return size > 0
        }

        guard !validURLs.isEmpty else {
            state = .failed("No valid video segments to process.")
            return
        }

        state = .processing
        progress = 0.0

        do {
            let composition = AVMutableComposition()
            var videoTrack: AVMutableCompositionTrack?
            var audioTrack: AVMutableCompositionTrack?
            var insertTime = CMTime.zero

            for url in validURLs {
                let asset = AVURLAsset(url: url)
                let duration = try await asset.load(.duration)
                let timeRange = CMTimeRange(start: .zero, duration: duration)

                if let sourceVideo = try await asset.loadTracks(withMediaType: .video).first {
                    if videoTrack == nil {
                        videoTrack = composition.addMutableTrack(
                            withMediaType: .video,
                            preferredTrackID: kCMPersistentTrackID_Invalid
                        )
                    }
                    try videoTrack?.insertTimeRange(timeRange, of: sourceVideo, at: insertTime)
                }

                if let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first {
                    if audioTrack == nil {
                        audioTrack = composition.addMutableTrack(
                            withMediaType: .audio,
                            preferredTrackID: kCMPersistentTrackID_Invalid
                        )
                    }
                    try audioTrack?.insertTimeRange(timeRange, of: sourceAudio, at: insertTime)
                }

                insertTime = CMTimeAdd(insertTime, duration)
            }

            guard !composition.tracks.isEmpty else {
                throw VideoProcessingError.noValidSegments
            }

            let outputURL = settings.captureDirectory
                .appendingPathComponent("\(settings.baseFileName)_final.mp4")
            try? FileManager.default.removeItem(at: outputURL)

            guard let session = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetPassthrough
            ) else {
                throw VideoProcessingError.failedToCreateExportSession
            }

            exportSession = session
            startProgressMonitoring()
            try await session.export(to: outputURL, as: .mp4)
            stopProgressMonitoring()

            progress = 1.0
            state = .completed
        } catch {
            stopProgressMonitoring()
            state = .failed(error.localizedDescription)
        }
    }

    func cancel() {
        exportSession?.cancelExport()
        stopProgressMonitoring()
        state = .idle
        progress = 0.0
    }

    func reset() {
        state = .idle
        progress = 0.0
    }

    // MARK: - Private

    private func startProgressMonitoring() {
        progressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, let session = self.exportSession else { break }
                self.progress = Double(session.progress)
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func stopProgressMonitoring() {
        progressTask?.cancel()
        progressTask = nil
        exportSession = nil
    }
}

enum VideoProcessingError: LocalizedError {
    case noValidSegments
    case failedToCreateExportSession
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .noValidSegments:
            "No valid video segments found."
        case .failedToCreateExportSession:
            "Failed to create video export session."
        case .exportFailed(let message):
            "Video export failed: \(message)"
        }
    }
}
