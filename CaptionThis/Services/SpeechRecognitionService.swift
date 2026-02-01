import AVFoundation
import Speech

@MainActor
final class SpeechRecognitionService {
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var continuation: AsyncThrowingStream<TranscriptionResult, Error>.Continuation?

    /// Text accumulated from previous recognition tasks (before auto-restarts).
    private var cumulativeText: String = ""

    /// Last transcription text from the current recognition task (for stitching on restart).
    private var lastSegmentText: String = ""

    /// Current language being recognized.
    private(set) var language: SupportedLanguage = .english

    func setLanguage(_ language: SupportedLanguage) {
        self.language = language
        recognizer = SFSpeechRecognizer(locale: language.locale)
        recognizer?.defaultTaskHint = .dictation
    }

    /// Starts recognition from an audio buffer stream.
    /// Automatically restarts when the ~1 minute recognition limit is hit.
    /// Returns a stream of TranscriptionResult.
    func startRecognition(
        audioStream: AsyncThrowingStream<AVAudioPCMBuffer, Error>
    ) -> AsyncThrowingStream<TranscriptionResult, Error> {
        cumulativeText = ""

        if recognizer == nil {
            setLanguage(language)
        }

        let stream = AsyncThrowingStream<TranscriptionResult, Error> { continuation in
            self.continuation = continuation

            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.cancelCurrentTask()
                }
            }
        }

        Task { @MainActor in
            await startRecognitionTask(audioStream: audioStream)
        }

        return stream
    }

    func stopRecognition() {
        cancelCurrentTask()
        let cont = continuation
        continuation = nil
        cont?.finish()
    }

    // MARK: - Private

    private func startRecognitionTask(
        audioStream: AsyncThrowingStream<AVAudioPCMBuffer, Error>
    ) async {
        guard let recognizer, recognizer.isAvailable else {
            continuation?.finish(throwing: RecognitionError.recognizerUnavailable)
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = true
        self.recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let fullTranscription = result.bestTranscription.formattedString
                self.lastSegmentText = fullTranscription
                let combinedText = self.cumulativeText.isEmpty
                    ? fullTranscription
                    : self.cumulativeText + " " + fullTranscription

                let transcriptionResult = TranscriptionResult(
                    fullText: combinedText,
                    latestSegment: fullTranscription,
                    finalizedText: result.isFinal ? combinedText : self.cumulativeText,
                    isFinal: result.isFinal
                )

                self.continuation?.yield(transcriptionResult)

                if result.isFinal {
                    self.cumulativeText = combinedText
                    self.lastSegmentText = ""  // prevent double-counting on error code 1
                }
            }

            if let error {
                let nsError = error as NSError
                // Error code 1 = recognition task limit reached or cancelled; auto-restart
                // Error code 216 = request was cancelled
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1 {
                    // Emit synthetic final for text accumulated in this task
                    if !self.lastSegmentText.isEmpty {
                        let combinedText = self.cumulativeText.isEmpty
                            ? self.lastSegmentText
                            : self.cumulativeText + " " + self.lastSegmentText
                        let syntheticResult = TranscriptionResult(
                            fullText: combinedText,
                            latestSegment: self.lastSegmentText,
                            finalizedText: combinedText,
                            isFinal: true
                        )
                        self.continuation?.yield(syntheticResult)
                        self.cumulativeText = combinedText
                    }
                    self.lastSegmentText = ""
                    self.cancelCurrentTask()
                    Task { @MainActor in
                        await self.startRecognitionTask(audioStream: audioStream)
                    }
                } else if nsError.code != 216 {
                    self.continuation?.finish(throwing: error)
                }
            }
        }

        // Feed audio buffers to the recognition request
        Task {
            do {
                for try await buffer in audioStream {
                    await MainActor.run {
                        self.recognitionRequest?.append(buffer)
                    }
                }
                await MainActor.run {
                    self.recognitionRequest?.endAudio()
                }
            } catch {
                await MainActor.run {
                    self.recognitionRequest?.endAudio()
                }
            }
        }
    }

    private func cancelCurrentTask() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
    }
}

enum RecognitionError: LocalizedError {
    case recognizerUnavailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is not available for the selected language."
        case .notAuthorized:
            return "Speech recognition is not authorized."
        }
    }
}
