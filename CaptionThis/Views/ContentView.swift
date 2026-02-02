import SwiftUI
import AppKit
import Translation

struct ContentView: View {
    @State private var viewModel = CaptionViewModel()
    @State private var showCaptureSettings = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(viewModel: viewModel, showCaptureSettings: $showCaptureSettings)

            Divider()

            // Panels
            VStack(spacing: 12) {
                TranscriptionPanelView(
                    title: "Transcript",
                    text: viewModel.finalTranscript,
                    onClear: { viewModel.clearFinalTranscript() }
                )

                TranscriptionPanelView(
                    title: "Transcript (In Progress)",
                    text: viewModel.inProgressTranscript,
                    onClear: { viewModel.clearInProgressTranscript() }
                )

                if viewModel.settings.captionEnabled {
                    TranscriptionPanelView(
                        title: "Translation",
                        text: viewModel.finalTranslation,
                        onClear: { viewModel.clearFinalTranslation() }
                    )

                    TranscriptionPanelView(
                        title: "Translation (In Progress)",
                        text: viewModel.inProgressTranslation,
                        onClear: { viewModel.clearInProgressTranslation() }
                    )
                }

                if viewModel.isProcessingVideo {
                    VStack(spacing: 6) {
                        ProgressView(value: viewModel.videoProcessingProgress)
                            .progressViewStyle(.linear)
                        Text("Processing video... \(Int(viewModel.videoProcessingProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            viewModel.cleanup()
        }
        .sheet(isPresented: $showCaptureSettings) {
            CaptureSettingsView(settings: viewModel.settings)
        }
        .sheet(isPresented: $viewModel.showCaptureCompletion) {
            CaptureCompletionView(
                onComplete: { Task { await viewModel.completeCaptureAndStop() } },
                onContinueLater: { Task { await viewModel.pauseCaptureAndStop() } },
                onCancel: { viewModel.cancelCaptureCompletion() }
            )
        }
        .translationTask(viewModel.translationConfig) { session in
            do {
                try await session.prepareTranslation()
                viewModel.onTranslationDownloadComplete()
            } catch {
                viewModel.onTranslationDownloadFailed(error)
            }
        }
        .background(WindowAccessor(isPinned: viewModel.settings.isPinned))
        .onChange(of: viewModel.settings.isPinned) { _, isPinned in
            setWindowLevel(isPinned ? .floating : .normal)
        }
        .onAppear {
            // Always start unpinned to avoid hiding startup messages
            // But maintain the user's preference for future runs
            if viewModel.settings.isPinned {
                // Temporarily set to false for this session only
                viewModel.settings.isPinned = false
            }
            // Set window level after ensuring it's not pinned in the current session
            setWindowLevel(.normal)  // Start unpinned
        }
    }

    private func setWindowLevel(_ level: NSWindow.Level) {
        NSApplication.shared.windows.first?.level = level
    }
}

/// Helper to access and modify the NSWindow from SwiftUI
struct WindowAccessor: NSViewRepresentable {
    let isPinned: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.level = .normal
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.level = isPinned ? .floating : .normal
    }
}

#Preview {
    ContentView()
}
