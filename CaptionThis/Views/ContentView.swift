import SwiftUI
import AppKit

struct ContentView: View {
    @State private var viewModel = CaptionViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(viewModel: viewModel)

            Divider()

            // Panels
            VStack(spacing: 12) {
                TranscriptionPanelView(
                    title: "Transcript 1 (Final)",
                    text: viewModel.finalTranscript,
                    onClear: { viewModel.clearFinalTranscript() }
                )

                TranscriptionPanelView(
                    title: "Transcript 2 (In Progress)",
                    text: viewModel.inProgressTranscript,
                    onClear: { viewModel.clearInProgressTranscript() }
                )

                if viewModel.settings.captionEnabled {
                    TranscriptionPanelView(
                        title: "Translation 1 (Final)",
                        text: viewModel.finalTranslation,
                        onClear: { viewModel.clearFinalTranslation() }
                    )

                    TranscriptionPanelView(
                        title: "Translation 2 (In Progress)",
                        text: viewModel.inProgressTranslation,
                        onClear: { viewModel.clearInProgressTranslation() }
                    )
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
            view.window?.level = isPinned ? .floating : .normal
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
