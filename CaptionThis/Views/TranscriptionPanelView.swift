import SwiftUI

struct TranscriptionPanelView: View {
    let title: String
    let text: String
    let onClear: () -> Void

    @State private var showClearConfirmation = false
    @State private var shouldAutoScroll = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .disabled(text.isEmpty)
                .help("Clear \(title.lowercased())")
                .confirmationDialog(
                    "Clear \(title.lowercased())?",
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear", role: .destructive) {
                        onClear()
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(text.isEmpty ? " " : text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .id("textBottom")
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    let atBottom = geometry.contentOffset.y + geometry.containerSize.height
                        >= geometry.contentSize.height - 20
                    return atBottom
                } action: { _, isAtBottom in
                    shouldAutoScroll = isAtBottom
                }
                .onChange(of: text) {
                    if shouldAutoScroll {
                        withAnimation {
                            proxy.scrollTo("textBottom", anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
