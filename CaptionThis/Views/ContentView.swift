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
                    title: "Transcription",
                    text: viewModel.inputText,
                    onClear: { viewModel.clearInputText() }
                )

                if viewModel.settings.captionEnabled {
                    TranscriptionPanelView(
                        title: "Translation",
                        text: viewModel.outputText,
                        onClear: { viewModel.clearOutputText() }
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
            if viewModel.settings.isPinned {
                setWindowLevel(.floating)
            }
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
