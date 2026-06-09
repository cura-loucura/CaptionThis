import SwiftUI
import AppKit

struct HeaderView: View {
    @Bindable var viewModel: CaptionViewModel
    @Binding var showCaptureSettings: Bool

    private var configDisabled: Bool {
        viewModel.isRunning || viewModel.isCapturing || viewModel.isProcessingVideo
    }

    var body: some View {
        @Bindable var settings = viewModel.settings

        VStack(spacing: 10) {
            configRow(settings: settings)

            if settings.captureIsEnabled {
                videoSetupRow(settings: settings)
            }

            actionRow(settings: settings)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Row 1: Mode + Languages + Source

    @ViewBuilder
    private func configRow(settings: SettingsState) -> some View {
        @Bindable var settings = settings
        HStack(spacing: 16) {
            // Mode picker
            VStack(alignment: .leading, spacing: 2) {
                Text("Mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $settings.captureIsEnabled) {
                    Text("Transcript Only").tag(false)
                    Text("Transcript + Video").tag(true)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 240)
                .disabled(configDisabled)
            }

            // Input language
            VStack(alignment: .leading, spacing: 2) {
                Text("Input")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $settings.inputLanguage) {
                    ForEach(SupportedLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
                .disabled(configDisabled)
                .onChange(of: settings.inputLanguage) {
                    viewModel.onInputLanguageChanged()
                }
            }

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)

            // Caption language (with None = translation disabled)
            VStack(alignment: .leading, spacing: 2) {
                Text("Caption")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { settings.captionEnabled ? settings.captionLanguage : nil as SupportedLanguage? },
                    set: { newValue in
                        if let lang = newValue {
                            settings.captionEnabled = true
                            settings.captionLanguage = lang
                            viewModel.onCaptionLanguageChanged()
                        } else {
                            settings.captionEnabled = false
                            viewModel.onCaptionEnabledChanged()
                        }
                    }
                )) {
                    Text("None").tag(nil as SupportedLanguage?)
                    Divider()
                    ForEach(SupportedLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang as SupportedLanguage?)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
                .disabled(configDisabled)
            }

            Spacer()

            // Audio source
            VStack(alignment: .leading, spacing: 2) {
                Text("Source")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AudioSourcePicker(
                    selectedSource: $viewModel.selectedSource,
                    availableApps: viewModel.availableApps,
                    onRefresh: { await viewModel.loadAvailableApps() }
                )
                .disabled(configDisabled)
            }
        }
    }

    // MARK: - Row 2: Video session setup (only in video mode)

    @ViewBuilder
    private func videoSetupRow(settings: SettingsState) -> some View {
        @Bindable var settings = settings
        HStack(spacing: 12) {
            // Session name
            VStack(alignment: .leading, spacing: 2) {
                Text("Session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Session name", text: $settings.captureBaseFileName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .disabled(configDisabled)
            }

            // Folder
            VStack(alignment: .leading, spacing: 2) {
                Text("Folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(settings.captureOutputDirectory.path(percentEncoded: false))
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                        .help(settings.captureOutputDirectory.path(percentEncoded: false))
                        .frame(maxWidth: 180, alignment: .leading)
                    Button("Change…") {
                        chooseOutputDirectory(settings: settings)
                    }
                    .controlSize(.small)
                    .disabled(configDisabled)
                    Button {
                        NSWorkspace.shared.open(settings.captureOutputDirectory)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help("Open in Finder")
                }
            }

            // Auto-stop minutes (or countdown when active)
            VStack(alignment: .leading, spacing: 2) {
                Text("Auto-stop (min)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if viewModel.isCapturing && viewModel.isCountdownActive {
                    Text(viewModel.countdownDisplay)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(viewModel.countdownSecondsRemaining < 60 ? .red : .orange)
                        .frame(width: 70, alignment: .center)
                } else {
                    TextField("0", value: $settings.captureMinutes, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .disabled(configDisabled)
                        .onChange(of: settings.captureMinutes) { _, newValue in
                            if newValue < 0 { settings.captureMinutes = 0 }
                            else if newValue > 99 { settings.captureMinutes = 99 }
                        }
                }
            }

            Spacer()

            // Video advanced settings
            Button {
                showCaptureSettings = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                    Text("Video settings")
                }
            }
            .disabled(configDisabled)
            .help("Codec, bitrate, resolution, frame rate")
        }
    }

    // MARK: - Row 3: Status + Pin + Start/Pause

    @ViewBuilder
    private func actionRow(settings: SettingsState) -> some View {
        @Bindable var settings = settings
        HStack(spacing: 12) {
            // Translation download / preparation status
            if !viewModel.translationStatus.isEmpty {
                HStack(spacing: 6) {
                    if viewModel.isPreparingTranslation {
                        ProgressView().controlSize(.small)
                    }
                    Text(viewModel.translationStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Running status
            if viewModel.isRunning {
                HStack(spacing: 6) {
                    if settings.captureIsEnabled {
                        Image(systemName: "record.circle.fill")
                            .foregroundStyle(.red)
                            .symbolEffect(.pulse, isActive: true)
                        Text("Recording")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Listening")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Pin toggle
            Toggle(isOn: $settings.isPinned) {
                Image(systemName: settings.isPinned ? "pin.fill" : "pin")
            }
            .toggleStyle(.button)
            .help(settings.isPinned ? "Unpin window" : "Pin window on top")

            // Start / Pause button
            Button {
                viewModel.toggleRunning()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                    Text(viewModel.isRunning ? "Pause" : "Start")
                }
                .frame(minWidth: 70)
            }
            .controlSize(.large)
            .keyboardShortcut(.space, modifiers: [])
        }
    }

    // MARK: - Folder picker

    private func chooseOutputDirectory(settings: SettingsState) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose the root folder for captures"
        panel.directoryURL = settings.captureOutputDirectory
        if panel.runModal() == .OK, let url = panel.url {
            settings.captureOutputDirectory = url
        }
    }
}
