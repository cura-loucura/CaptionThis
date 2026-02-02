import AVFoundation

final class MicrophoneCapture: AudioCaptureService, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var continuation: AsyncThrowingStream<AVAudioPCMBuffer, Error>.Continuation?
    private let lock = NSLock()

    /// Target format: 16kHz, mono, Float32
    private static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    func startCapture() async throws -> AsyncThrowingStream<AVAudioPCMBuffer, Error> {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            throw CaptureError.noAudioInput
        }

        let converter = AVAudioConverter(from: inputFormat, to: Self.targetFormat)
        guard let converter else {
            throw CaptureError.converterCreationFailed
        }

        let stream = AsyncThrowingStream<AVAudioPCMBuffer, Error> { continuation in
            self.lock.lock()
            self.continuation = continuation
            self.lock.unlock()

            continuation.onTermination = { @Sendable _ in
                self.stopCaptureSync()
            }

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
                guard let converted = self.convert(buffer: buffer, using: converter) else { return }
                continuation.yield(converted)
            }
        }

        engine.prepare()
        try engine.start()

        return stream
    }

    func stopCapture() async {
        stopCaptureSync()
    }

    private func stopCaptureSync() {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        cont?.finish()
    }

    private func convert(buffer: AVAudioPCMBuffer, using converter: AVAudioConverter) -> AVAudioPCMBuffer? {
        let ratio = Self.targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard outputFrameCapacity > 0 else { return nil }

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: Self.targetFormat,
            frameCapacity: outputFrameCapacity
        ) else { return nil }

        var error: NSError?
        var hasData = true

        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if hasData {
                hasData = false
                outStatus.pointee = .haveData
                return buffer
            }
            outStatus.pointee = .noDataNow
            return nil
        }

        if let error {
            print("Audio conversion error: \(error)")
            return nil
        }

        return outputBuffer
    }
}

enum CaptureError: LocalizedError {
    case noAudioInput
    case converterCreationFailed
    case screenCaptureNotAvailable
    case noDisplayFound
    case recordingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAudioInput:
            return "No audio input device found."
        case .converterCreationFailed:
            return "Failed to create audio format converter."
        case .screenCaptureNotAvailable:
            return "Screen capture is not available."
        case .noDisplayFound:
            return "No display found for screen capture."
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        }
    }
}
