import SwiftUI

struct CaptureSettingsView: View {
    @Bindable var settings: SettingsState
    @Environment(\.dismiss) private var dismiss

    @State private var draftVideoCodec: VideoCodec = .hevc
    @State private var draftVideoBitrate: VideoBitrate = .medium
    @State private var draftVideoResolution: VideoResolution = .hd1080
    @State private var draftFrameRate: Int = 30

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Video Compression") {
                    Picker("Codec", selection: $draftVideoCodec) {
                        ForEach(VideoCodec.allCases) { codec in
                            Text(codec.displayName).tag(codec)
                        }
                    }

                    Picker("Bitrate", selection: $draftVideoBitrate) {
                        ForEach(VideoBitrate.allCases) { bitrate in
                            Text(bitrate.displayName).tag(bitrate)
                        }
                    }

                    Picker("Resolution", selection: $draftVideoResolution) {
                        ForEach(VideoResolution.allCases) { resolution in
                            Text(resolution.displayName).tag(resolution)
                        }
                    }

                    Picker("Frame Rate", selection: $draftFrameRate) {
                        ForEach(CaptureSettings.availableFrameRates, id: \.self) { rate in
                            Text("\(rate) fps").tag(rate)
                        }
                    }

                    Text("Estimated size: ~\(estimatedSizePerHour) per hour")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 420, height: 300)
        .onAppear {
            loadFromSettings()
        }
    }

    // MARK: - Computed

    private var estimatedSizePerHour: String {
        let totalBitsPerSecond = Double(draftVideoBitrate.bitsPerSecond) + 128_000.0
        let bytesPerHour = totalBitsPerSecond / 8.0 * 3600.0
        let gbPerHour = bytesPerHour / 1_000_000_000.0
        return String(format: "%.1f GB", gbPerHour)
    }

    // MARK: - Actions

    private func loadFromSettings() {
        draftVideoCodec = settings.captureVideoCodec
        draftVideoBitrate = settings.captureVideoBitrate
        draftVideoResolution = settings.captureVideoResolution
        draftFrameRate = settings.captureFrameRate
    }

    private func save() {
        settings.captureVideoCodec = draftVideoCodec
        settings.captureVideoBitrate = draftVideoBitrate
        settings.captureVideoResolution = draftVideoResolution
        settings.captureFrameRate = draftFrameRate
        dismiss()
    }
}
