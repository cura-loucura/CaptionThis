import SwiftUI
import ScreenCaptureKit

struct AudioSourcePicker: View {
    @Binding var selectedSource: AudioSource
    var availableApps: [SCRunningApplication]
    var onRefresh: () async -> Void

    var body: some View {
        Menu {
            Button {
                selectedSource = .microphone
            } label: {
                HStack {
                    Image(systemName: "mic")
                    Text("Microphone")
                }
            }

            Divider()

            if availableApps.isEmpty {
                Text("No applications available")
            } else {
                ForEach(availableApps, id: \.bundleIdentifier) { app in
                    Button {
                        selectedSource = .application(app)
                    } label: {
                        Text(app.applicationName)
                    }
                }
            }

            Divider()

            Button {
                Task { await onRefresh() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedSource == .microphone ? "mic" : "app.badge.checkmark")
                Text(selectedSource.displayName)
                    .lineLimit(1)
            }
            .frame(minWidth: 100)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
