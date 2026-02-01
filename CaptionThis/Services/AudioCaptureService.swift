import AVFoundation

protocol AudioCaptureService: AnyObject, Sendable {
    /// Starts capturing audio and returns an async stream of PCM buffers.
    /// Buffers are 16kHz, mono, Float32.
    func startCapture() async throws -> AsyncThrowingStream<AVAudioPCMBuffer, Error>

    /// Stops capturing audio. The stream returned by startCapture will end.
    func stopCapture() async
}
