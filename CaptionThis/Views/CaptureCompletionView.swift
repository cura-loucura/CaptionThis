import SwiftUI

/// Dialog presented when the user pauses while CaptureThis is actively recording.
struct CaptureCompletionView: View {
    let onComplete: () -> Void
    let onContinueLater: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "record.circle")
                .font(.system(size: 36))
                .foregroundStyle(.red)

            Text("Complete Capture?")
                .font(.headline)

            Text("Do you want to finalize the capture session or continue recording later?")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Continue Later") {
                    onContinueLater()
                }

                Button("Complete") {
                    onComplete()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
