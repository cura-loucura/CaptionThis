import SwiftUI
import ScreenCaptureKit

@MainActor
@Observable
final class CaptionViewModel {
    // MARK: - Published State

    var inputText: String = ""
    var outputText: String = ""
    var isRunning: Bool = false
    var errorMessage: String = ""
    var showError: Bool = false
    var availableApps: [SCRunningApplication] = []

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

    /// Text pending translation (for debouncing in live mode).
    private var pendingTranslationText: String = ""

    /// Transcript text preserved across pipeline restarts.
    private var transcriptHistory: String = ""
    /// Translation text preserved across pipeline restarts.
    private var translationHistory: String = ""
    /// Finalized input text already translated in the current session.
    private var sessionTranslatedInput: String = ""
    /// Accumulated translation for the current session.
    private var sessionTranslation: String = ""

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
                    let sessionText = result.fullText
                    self.inputText = self.transcriptHistory.isEmpty
                        ? sessionText
                        : self.transcriptHistory + " " + sessionText

                    if self.settings.captionEnabled {
                        if self.settings.translationMode == .live {
                            self.debounceLiveTranslation(text: result.latestSegment)
                        } else if result.isFinal {
                            await self.translateNewFinalized(sessionFullText: sessionText)
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
        preserveHistory()
        pipelineTask?.cancel()
        pipelineTask = nil
        translationTask?.cancel()
        translationTask = nil
        translationDebounceTask?.cancel()
        translationDebounceTask = nil
        speechService.stopRecognition()
        Task {
            await audioCapture?.stopCapture()
            audioCapture = nil
        }
        isRunning = false
    }

    func clearInputText() {
        inputText = ""
        transcriptHistory = ""
    }

    func clearOutputText() {
        outputText = ""
        translationHistory = ""
        sessionTranslation = ""
        sessionTranslatedInput = ""
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
            outputText = ""
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

    private func preserveHistory() {
        transcriptHistory = inputText
        translationHistory = outputText
        sessionTranslatedInput = ""
        sessionTranslation = ""
    }

    private func debounceLiveTranslation(text: String) {
        pendingTranslationText = text
        translationDebounceTask?.cancel()
        translationDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self.translateLivePartial(self.pendingTranslationText)
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
            let base = translationHistory.isEmpty
                ? sessionTranslation
                : translationHistory + " " + sessionTranslation
            self.outputText = base.isEmpty ? translated : base + " " + translated
        } catch {
            // Swallow live translation errors
        }
    }

    private func translateNewFinalized(sessionFullText: String) async {
        guard settings.captionEnabled else { return }

        // Determine the new text that hasn't been translated yet
        let newText: String
        if sessionTranslatedInput.isEmpty {
            newText = sessionFullText
        } else if sessionFullText.hasPrefix(sessionTranslatedInput) {
            newText = String(sessionFullText.dropFirst(sessionTranslatedInput.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Text was revised; re-translate the full session
            newText = sessionFullText
            sessionTranslation = ""
        }

        guard !newText.isEmpty else { return }

        do {
            let translated = try await translationService.translate(
                text: newText,
                from: settings.inputLanguage,
                to: settings.captionLanguage
            )
            if sessionTranslation.isEmpty {
                sessionTranslation = translated
            } else {
                sessionTranslation += " " + translated
            }
            self.outputText = translationHistory.isEmpty
                ? sessionTranslation
                : translationHistory + " " + sessionTranslation
            sessionTranslatedInput = sessionFullText
        } catch {
            if settings.translationMode == .delayed {
                showErrorMessage("Translation failed: \(error.localizedDescription)")
            }
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
