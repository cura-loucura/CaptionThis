import SwiftUI
import ScreenCaptureKit

@MainActor
@Observable
final class CaptionViewModel {
    // MARK: - Published State

    var isRunning: Bool = false
    var errorMessage: String = ""
    var showError: Bool = false
    var availableApps: [SCRunningApplication] = []

    // MARK: - Segment-Based History

    private(set) var segments: [TranscriptionSegment] = []

    var finalTranscript: String {
        segments.map(\.originalText).joined(separator: "\n")
    }

    var finalTranslation: String {
        segments.compactMap(\.translatedText).joined(separator: "\n")
    }

    // MARK: - In-Progress Text

    var inProgressTranscript: String = ""
    var inProgressTranslation: String = ""

    let settings = SettingsState()

    // MARK: - Audio Source

    var selectedSource: AudioSource = .microphone {
        didSet {
            settings.audioSourceID = selectedSource.id
            if isRunning {
                Task { await restartPipeline() }
            }
        }
    }

    // MARK: - Services

    private let speechService = SpeechRecognitionService()
    private let translationService = TranslationService()
    private var audioCapture: (any AudioCaptureService)?
    private var pipelineTask: Task<Void, Never>?
    private var translationTask: Task<Void, Never>?
    private var translationDebounceTask: Task<Void, Never>?
    private var speechPauseTask: Task<Void, Never>?

    /// The currently active (in-progress) transcript that hasn't been finalized yet.
    private var activeTranscript: String = ""
    /// The currently active (in-progress) translation that hasn't been finalized yet.
    private var activeTranslation: String = ""
    /// The exact raw `result.latestSegment` value from the last partial result.
    /// Updated on every partial so the pause timer can snapshot it at finalization.
    private var lastReceivedRawSegment: String = ""
    /// Snapshot of the raw `latestSegment` at the moment the pause timer committed
    /// text to history. Used as a stable prefix to strip from future partial results
    /// so only genuinely new text appears in "In Progress".
    private var committedRawPrefix: String = ""

    // MARK: - Init

    init() {
        speechService.setLanguage(settings.inputLanguage)
        Task { await loadAvailableApps() }
    }

    // MARK: - Public Actions

    func toggleRunning() {
        if isRunning {
            stopPipeline()
        } else {
            Task { await startPipeline() }
        }
    }

    func startPipeline() async {
        guard !isRunning else { return }

        // Request permissions
        let permissions = await PermissionService.requestAllPermissions()
        guard permissions.microphone else {
            showErrorMessage("Microphone permission is required.")
            return
        }
        guard permissions.speechRecognition else {
            showErrorMessage("Speech recognition permission is required.")
            return
        }

        isRunning = true
        audioCapture = createAudioCapture()

        pipelineTask = Task { @MainActor in
            do {
                guard let audioCapture else { return }
                let audioStream = try await audioCapture.startCapture()
                let transcriptionStream = speechService.startRecognition(audioStream: audioStream)

                for try await result in transcriptionStream {
                    guard !Task.isCancelled else { break }

                    if result.isFinal {
                        // Cancel pause timer — we're finalizing now
                        speechPauseTask?.cancel()

                        // Finalize any remaining in-progress text
                        if !activeTranscript.isEmpty {
                            await finalizeActiveTranscript()
                        } else {
                            // Pause timer may have already handled it; check if
                            // latestSegment has genuinely new text after the prefix.
                            let fullSegment = result.latestSegment
                            let newText: String
                            if !committedRawPrefix.isEmpty && fullSegment.hasPrefix(committedRawPrefix) {
                                newText = String(fullSegment.dropFirst(committedRawPrefix.count))
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                            } else {
                                newText = fullSegment.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            if !newText.isEmpty {
                                let segment = TranscriptionSegment(originalText: newText)
                                segments.append(segment)
                                if settings.captionEnabled {
                                    await translateSegment(at: segments.count - 1)
                                }
                            }
                        }

                        // Reset prefix tracking — new recognition task starts fresh
                        committedRawPrefix = ""
                        lastReceivedRawSegment = ""
                    } else {
                        // Partial: save raw segment, then strip committed prefix
                        let fullSegment = result.latestSegment
                        lastReceivedRawSegment = fullSegment

                        if !committedRawPrefix.isEmpty && fullSegment.hasPrefix(committedRawPrefix) {
                            activeTranscript = String(fullSegment.dropFirst(committedRawPrefix.count))
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                        } else {
                            activeTranscript = fullSegment
                        }
                        inProgressTranscript = activeTranscript

                        // Reset pause timer — finalize after 1s of silence
                        resetSpeechPauseTimer()

                        // Live translation of partial text
                        if settings.captionEnabled && settings.translationMode == .live {
                            debounceLiveTranslation(text: activeTranscript)
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.showErrorMessage(error.localizedDescription)
                }
            }
            self.isRunning = false
        }
    }

    func stopPipeline() {
        pipelineTask?.cancel()
        pipelineTask = nil
        translationTask?.cancel()
        translationTask = nil
        translationDebounceTask?.cancel()
        translationDebounceTask = nil
        speechPauseTask?.cancel()
        speechPauseTask = nil
        committedRawPrefix = ""
        lastReceivedRawSegment = ""
        speechService.stopRecognition()
        Task {
            await audioCapture?.stopCapture()
            audioCapture = nil
        }
        isRunning = false
    }

    // MARK: - Clear Methods

    func clearFinalTranscript() {
        segments.removeAll()
        committedRawPrefix = ""
        lastReceivedRawSegment = ""
    }

    func clearInProgressTranscript() {
        inProgressTranscript = ""
        activeTranscript = ""
    }

    func clearFinalTranslation() {
        for i in segments.indices {
            segments[i].translatedText = nil
        }
    }

    func clearInProgressTranslation() {
        inProgressTranslation = ""
        activeTranslation = ""
    }

    func onInputLanguageChanged() {
        speechService.setLanguage(settings.inputLanguage)
        if isRunning {
            Task { await restartPipeline() }
        }
        if settings.captionEnabled {
            Task { await prepareTranslation() }
        }
    }

    func onCaptionLanguageChanged() {
        if settings.captionEnabled {
            Task { await prepareTranslation() }
        }
    }

    func onCaptionEnabledChanged() {
        if settings.captionEnabled {
            Task { await prepareTranslation() }
        } else {
            inProgressTranslation = ""
            activeTranslation = ""
        }
    }

    func loadAvailableApps() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            availableApps = content.applications.filter { !$0.applicationName.isEmpty }

            // Restore saved audio source
            if settings.audioSourceID != AudioSource.microphone.id {
                if let app = availableApps.first(where: { $0.bundleIdentifier == settings.audioSourceID }) {
                    selectedSource = .application(app)
                }
            }
        } catch {
            // Screen recording permission not granted yet; that's fine
            availableApps = []
        }
    }

    // MARK: - Private

    private func createAudioCapture() -> any AudioCaptureService {
        switch selectedSource {
        case .microphone:
            return MicrophoneCapture()
        case .application(let app):
            return AppAudioCapture(application: app)
        }
    }

    private func restartPipeline() async {
        stopPipeline()
        // Small delay to allow cleanup
        try? await Task.sleep(for: .milliseconds(200))
        await startPipeline()
    }

    private func translateSegment(at index: Int) async {
        guard settings.captionEnabled, index < segments.count else { return }
        let text = segments[index].originalText
        do {
            let translated = try await translationService.translate(
                text: text,
                from: settings.inputLanguage,
                to: settings.captionLanguage
            )
            if index < segments.count {
                segments[index].translatedText = translated
            }
        } catch {
            if settings.translationMode == .delayed {
                showErrorMessage("Translation failed: \(error.localizedDescription)")
            }
        }
    }

    private func debounceLiveTranslation(text: String) {
        translationDebounceTask?.cancel()
        translationDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self.translateLivePartial(text)
        }
    }

    private func translateLivePartial(_ text: String) async {
        guard settings.captionEnabled else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let translated = try await translationService.translate(
                text: text,
                from: settings.inputLanguage,
                to: settings.captionLanguage
            )
            activeTranslation = translated
            inProgressTranslation = translated
        } catch {
            // Swallow live translation errors
        }
    }

    /// Moves the current in-progress transcript into a finalized segment.
    /// Called when a speech pause is detected or when isFinal fires.
    private func finalizeActiveTranscript() async {
        let text = activeTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let segment = TranscriptionSegment(originalText: text)
        segments.append(segment)

        // Snapshot the exact raw latestSegment from Apple at this moment.
        // Future partial results that start with this prefix will have it
        // stripped so only genuinely new text appears in "In Progress".
        committedRawPrefix = lastReceivedRawSegment

        activeTranscript = ""
        inProgressTranscript = ""

        if settings.captionEnabled {
            let segmentIndex = segments.count - 1
            await translateSegment(at: segmentIndex)
        }
        activeTranslation = ""
        inProgressTranslation = ""
    }

    /// Resets the speech pause timer. When no new partial results arrive
    /// for 1 second, the current active transcript is finalized into a segment.
    private func resetSpeechPauseTimer() {
        speechPauseTask?.cancel()
        speechPauseTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1000))
            guard !Task.isCancelled else { return }
            await finalizeActiveTranscript()
        }
    }

    private func prepareTranslation() async {
        guard settings.captionEnabled else { return }
        do {
            try await translationService.prepareLanguagePair(
                from: settings.inputLanguage,
                to: settings.captionLanguage
            )
        } catch {
            showErrorMessage("Failed to prepare translation: \(error.localizedDescription)")
        }
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    func cleanup() {
        stopPipeline()
    }
}
