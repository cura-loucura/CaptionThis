import AVFoundation
import ScreenCaptureKit
import CoreMedia
import AppKit

// MARK: - Recording State

enum RecordingState: Sendable {
    case idle
    case recording
    case paused
}

// MARK: - ScreenRecordingService

@MainActor
@Observable
final class ScreenRecordingService {
    private(set) var state: RecordingState = .idle
    private(set) var currentSegmentIndex: Int = 0
    private(set) var captureSettings: CaptureSettings?

    private var recorder: SegmentRecorder?

    /// Starts recording a new segment.
    /// If resuming from paused state, increments the segment index.
    func start(settings: CaptureSettings) async throws {
        captureSettings = settings

        if state == .paused {
            currentSegmentIndex += 1
        } else {
            currentSegmentIndex = 1
        }

        let recorder = SegmentRecorder(settings: settings, segmentIndex: currentSegmentIndex)
        self.recorder = recorder
        try await recorder.start()
        state = .recording
    }

    /// Pauses recording — finalizes the current segment file.
    /// The next `start` call will create a new numbered segment.
    func pause() async {
        await recorder?.stop()
        recorder = nil
        state = .paused
    }

    /// Stops recording completely — finalizes and resets all state.
    func stop() async {
        await recorder?.stop()
        recorder = nil
        state = .idle
        currentSegmentIndex = 0
    }

    /// The number of segments recorded so far.
    var segmentCount: Int { currentSegmentIndex }

    /// Returns the URLs of all segment files created in the current session.
    func segmentURLs() -> [URL] {
        guard let settings = captureSettings, currentSegmentIndex > 0 else { return [] }
        return (1...currentSegmentIndex).map { index in
            Self.segmentURL(for: settings, index: index)
        }
    }

    static func segmentURL(for settings: CaptureSettings, index: Int) -> URL {
        let fileName = index <= 1
            ? "\(settings.baseFileName).mov"
            : "\(settings.baseFileName)\(index).mov"
        return settings.captureDirectory.appendingPathComponent(fileName)
    }
}

// MARK: - SegmentRecorder

/// Records a single video+audio segment to a .mov file using SCStream + AVAssetWriter.
final class SegmentRecorder: NSObject, @unchecked Sendable {
    private let settings: CaptureSettings
    private let segmentIndex: Int
    private let outputURL: URL
    private let outputQueue = DispatchQueue(label: "com.captionthis.screenrecording", qos: .userInteractive)

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?

    private let lock = NSLock()
    private var isWriting = false
    /// Whether `startSession(atSourceTime:)` has been called. Only accessed on `outputQueue`.
    private var sessionStarted = false

    /// Sets `isWriting` under the lock (safe to call from async contexts).
    private func setWriting(_ value: Bool) {
        lock.withLock { isWriting = value }
    }

    /// Atomically sets `isWriting = false` and takes ownership of the stream reference.
    private func stopWritingAndTakeStream() -> SCStream? {
        lock.withLock {
            isWriting = false
            let scStream = stream
            stream = nil
            return scStream
        }
    }

    init(settings: CaptureSettings, segmentIndex: Int) {
        self.settings = settings
        self.segmentIndex = segmentIndex

        let fileName = segmentIndex <= 1
            ? "\(settings.baseFileName).mov"
            : "\(settings.baseFileName)\(segmentIndex).mov"
        self.outputURL = settings.captureDirectory.appendingPathComponent(fileName)

        super.init()
    }

    func start() async throws {
        // Create output directory if needed
        try FileManager.default.createDirectory(
            at: settings.captureDirectory,
            withIntermediateDirectories: true
        )
        // Remove existing file at this path (e.g., from a previous session)
        try? FileManager.default.removeItem(at: outputURL)

        // Get display info for capture
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first else {
            throw CaptureError.noDisplayFound
        }

        // Determine video dimensions
        let videoWidth: Int
        let videoHeight: Int
        if let dims = settings.videoResolution.dimensions {
            videoWidth = dims.width
            videoHeight = dims.height
        } else {
            // Native: use display pixel dimensions (points × scale factor)
            let scale = Int(NSScreen.main?.backingScaleFactor ?? 2.0)
            videoWidth = display.width * scale
            videoHeight = display.height * scale
        }

        // --- AVAssetWriter ---
        let writer = try AVAssetWriter(url: outputURL, fileType: .mov)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: settings.videoCodec == .hevc
                ? AVVideoCodecType.hevc
                : AVVideoCodecType.h264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: settings.videoBitrate.bitsPerSecond
            ]
        ]
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true
        writer.add(vInput)

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128_000
        ]
        let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        aInput.expectsMediaDataInRealTime = true
        writer.add(aInput)

        assetWriter = writer
        videoInput = vInput
        audioInput = aInput

        // --- SCStream ---
        // For app-scoped capture, pick the largest on-screen window of the target app
        // and use a window-scoped filter so the source follows the window as it
        // moves/resizes. Fall back to the display-scoped app filter if none is found.
        let filter: SCContentFilter
        var windowAspect: CGFloat?
        if let targetApp = settings.targetApplication {
            let appWindows = content.windows.filter {
                $0.owningApplication?.bundleIdentifier == targetApp.bundleIdentifier
            }
            let windowArea: (SCWindow) -> CGFloat = { $0.frame.width * $0.frame.height }
            let bestWindow = appWindows
                .filter { $0.isOnScreen && $0.frame.width > 100 && $0.frame.height > 100 }
                .max { windowArea($0) < windowArea($1) }
            if let bestWindow {
                filter = SCContentFilter(desktopIndependentWindow: bestWindow)
                windowAspect = bestWindow.frame.width / bestWindow.frame.height
            } else {
                filter = SCContentFilter(display: display, including: appWindows)
            }
        } else {
            filter = SCContentFilter(
                display: display,
                excludingApplications: [],
                exceptingWindows: []
            )
        }

        let config = SCStreamConfiguration()
        config.width = videoWidth
        config.height = videoHeight
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(settings.frameRate))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = true
        config.sampleRate = 48000
        config.channelCount = 2
        config.excludesCurrentProcessAudio = true

        // Letterbox/pillarbox the window into the standard output canvas, preserving
        // its aspect ratio so no content is cropped or stretched. The aspect is locked
        // at start, so resizing the window mid-recording will scale within these bars.
        if let windowAspect {
            let canvasW = CGFloat(videoWidth)
            let canvasH = CGFloat(videoHeight)
            let canvasAspect = canvasW / canvasH
            if windowAspect > canvasAspect {
                let fitH = (canvasW / windowAspect).rounded()
                config.destinationRect = CGRect(
                    x: 0, y: ((canvasH - fitH) / 2).rounded(),
                    width: canvasW, height: fitH
                )
            } else {
                let fitW = (canvasH * windowAspect).rounded()
                config.destinationRect = CGRect(
                    x: ((canvasW - fitW) / 2).rounded(), y: 0,
                    width: fitW, height: canvasH
                )
            }
            config.backgroundColor = .black
        }

        let scStream = SCStream(filter: filter, configuration: config, delegate: self)
        try scStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
        try scStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: outputQueue)

        // Begin writing
        guard writer.startWriting() else {
            throw writer.error ?? CaptureError.recordingFailed("AVAssetWriter failed to start writing.")
        }

        setWriting(true)

        try await scStream.startCapture()
        self.stream = scStream
    }

    func stop() async {
        let scStream = stopWritingAndTakeStream()

        if let scStream {
            try? await scStream.stopCapture()
        }

        // Drain the output queue so any in-flight appends complete
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            outputQueue.async {
                continuation.resume()
            }
        }

        // Finalize the asset writer
        if let writer = assetWriter, writer.status == .writing {
            videoInput?.markAsFinished()
            audioInput?.markAsFinished()
            await writer.finishWriting()
        }

        assetWriter = nil
        videoInput = nil
        audioInput = nil
    }
}

// MARK: - SCStreamOutput

extension SegmentRecorder: SCStreamOutput {
    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard lock.withLock({ isWriting }) else { return }

        guard let writer = assetWriter, writer.status == .writing else { return }

        // Start the writing session at the first sample's timestamp
        if !sessionStarted {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startSession(atSourceTime: timestamp)
            sessionStarted = true
        }

        switch type {
        case .screen:
            // Skip frames without valid image data (e.g., idle frames)
            guard sampleBuffer.isValid,
                  CMSampleBufferGetImageBuffer(sampleBuffer) != nil else { return }
            if let videoInput, videoInput.isReadyForMoreMediaData {
                videoInput.append(sampleBuffer)
            }
        case .audio:
            guard sampleBuffer.isValid else { return }
            if let audioInput, audioInput.isReadyForMoreMediaData {
                audioInput.append(sampleBuffer)
            }
        case .microphone:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - SCStreamDelegate

extension SegmentRecorder: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        lock.withLock { isWriting = false }
    }
}
