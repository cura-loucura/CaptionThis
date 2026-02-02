import SwiftUI
import AppKit

struct CaptureSettingsView: View {
    @Bindable var settings: SettingsState
    @Environment(\.dismiss) private var dismiss

    @State private var draftBaseFileName: String = ""
    @State private var draftVideoCodec: VideoCodec = .hevc
    @State private var draftVideoBitrate: VideoBitrate = .medium
    @State private var draftVideoResolution: VideoResolution = .hd1080
    @State private var draftFrameRate: Int = 30
    @State private var draftOutputDirectory: URL = CaptureSettings.defaultOutputDirectory
    @State private var draftIsEnabled: Bool = false

    @State private var showDirectoryExistsWarning = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Toggle("Enable Screen Capture", isOn: $draftIsEnabled)
                }

                Section("Output") {
                    TextField("Base File Name", text: $draftBaseFileName)
                        .textFieldStyle(.roundedBorder)

                    if !isBaseFileNameValid && !draftBaseFileName.isEmpty {
                        Text("File name contains invalid characters.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    HStack {
                        Text("Output Folder")
                        Spacer()
                        Text(draftOutputDirectory.path(percentEncoded: false))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose...") {
                            chooseOutputDirectory()
                        }
                        Button {
                            NSWorkspace.shared.open(draftOutputDirectory)
                        } label: {
                            Image(systemName: "folder")
                        }
                        .help("Open in Finder")
                    }

                    if directoryExists {
                        Label("Folder \"\(draftBaseFileName)\" already exists at this location. Existing files may be overwritten.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

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
                .disabled(!isBaseFileNameValid)
            }
            .padding()
        }
        .frame(width: 480, height: 460)
        .onAppear {
            loadFromSettings()
        }
    }

    // MARK: - Computed

    private var isBaseFileNameValid: Bool {
        let trimmed = draftBaseFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return trimmed.rangeOfCharacter(from: illegal) == nil
    }

    private var estimatedSizePerHour: String {
        // Video bitrate + audio at 128 kbps, converted to GB/hour
        let totalBitsPerSecond = Double(draftVideoBitrate.bitsPerSecond) + 128_000.0
        let bytesPerHour = totalBitsPerSecond / 8.0 * 3600.0
        let gbPerHour = bytesPerHour / 1_000_000_000.0
        return String(format: "%.1f GB", gbPerHour)
    }

    private var directoryExists: Bool {
        let dir = draftOutputDirectory
            .appendingPathComponent(draftBaseFileName, isDirectory: true)
        return FileManager.default.fileExists(atPath: dir.path)
    }

    // MARK: - Actions

    private func loadFromSettings() {
        draftIsEnabled = settings.captureIsEnabled
        draftBaseFileName = settings.captureBaseFileName
        draftVideoCodec = settings.captureVideoCodec
        draftVideoBitrate = settings.captureVideoBitrate
        draftVideoResolution = settings.captureVideoResolution
        draftFrameRate = settings.captureFrameRate
        draftOutputDirectory = settings.captureOutputDirectory
    }

    private func save() {
        settings.captureIsEnabled = draftIsEnabled
        settings.captureBaseFileName = draftBaseFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.captureVideoCodec = draftVideoCodec
        settings.captureVideoBitrate = draftVideoBitrate
        settings.captureVideoResolution = draftVideoResolution
        settings.captureFrameRate = draftFrameRate
        settings.captureOutputDirectory = draftOutputDirectory
        dismiss()
    }

    private func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose the root folder for captures"

        if panel.runModal() == .OK, let url = panel.url {
            draftOutputDirectory = url
        }
    }
}
