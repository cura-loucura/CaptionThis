import AVFoundation
import ScreenCaptureKit
import CoreMedia

final class AppAudioCapture: NSObject, AudioCaptureService, @unchecked Sendable {
    private let application: SCRunningApplication
    private var stream: SCStream?
    private var continuation: AsyncThrowingStream<AVAudioPCMBuffer, Error>.Continuation?
    private let lock = NSLock()

    /// Target format: 16kHz, mono, Float32
    private static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    init(application: SCRunningApplication) {
        self.application = application
        super.init()
    }

    func startCapture() async throws -> AsyncThrowingStream<AVAudioPCMBuffer, Error> {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        guard let display = content.displays.first else {
            throw CaptureError.noDisplayFound
        }

        // Include only windows from the target app
        let appWindows = content.windows.filter {
            $0.owningApplication?.bundleIdentifier == application.bundleIdentifier
        }

        let filter = SCContentFilter(display: display, including: appWindows)

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 16000
        config.channelCount = 1
        // Minimize video overhead — we only want audio
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let scStream = SCStream(filter: filter, configuration: config, delegate: self)

        let asyncStream = AsyncThrowingStream<AVAudioPCMBuffer, Error> { continuation in
            self.lock.lock()
            self.continuation = continuation
            self.lock.unlock()

            continuation.onTermination = { @Sendable _ in
                Task { await self.stopCapture() }
            }
        }

        try scStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
        try await scStream.startCapture()
        self.stream = scStream

        return asyncStream
    }

    func stopCapture() async {
        lock.lock()
        let cont = continuation
        continuation = nil
        let scStream = stream
        stream = nil
        lock.unlock()

        if let scStream {
            try? await scStream.stopCapture()
        }
        cont?.finish()
    }

    private func convertCMSampleBufferToAVAudioPCMBuffer(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = sampleBuffer.formatDescription,
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }

        guard let avFormat = AVAudioFormat(streamDescription: streamDescription) else {
            return nil
        }

        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frameCount > 0 else { return nil }

        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: avFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }

        var dataPointer: UnsafeMutablePointer<Int8>?
        var lengthAtOffset: Int = 0
        var totalLength: Int = 0

        let status = CMBlockBufferGetDataPointer(
            blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength, dataPointerOut: &dataPointer
        )

        guard status == noErr, let dataPointer else { return nil }

        if let channelData = pcmBuffer.floatChannelData {
            memcpy(channelData[0], dataPointer, min(totalLength, Int(pcmBuffer.frameCapacity) * MemoryLayout<Float>.size))
        }

        return pcmBuffer
    }
}

extension AppAudioCapture: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard let pcmBuffer = convertCMSampleBufferToAVAudioPCMBuffer(sampleBuffer) else { return }

        lock.lock()
        let cont = continuation
        lock.unlock()

        cont?.yield(pcmBuffer)
    }
}

extension AppAudioCapture: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()

        cont?.finish(throwing: error)
    }
}
