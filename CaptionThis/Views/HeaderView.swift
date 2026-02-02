import SwiftUI

struct HeaderView: View {
    @Bindable var viewModel: CaptionViewModel
    @Binding var showCaptureSettings: Bool

    var body: some View {
        @Bindable var settings = viewModel.settings

        VStack(spacing: 12) {
            HStack(spacing: 16) {
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
                    .frame(width: 120)
                    .onChange(of: viewModel.settings.inputLanguage) {
                        viewModel.onInputLanguageChanged()
                    }
                }

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)

                // Caption language
                VStack(alignment: .leading, spacing: 2) {
                    Text("Caption")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { viewModel.settings.captionEnabled ? viewModel.settings.captionLanguage : nil as SupportedLanguage? },
                        set: { newValue in
                            if let lang = newValue {
                                viewModel.settings.captionEnabled = true
                                viewModel.settings.captionLanguage = lang
                                viewModel.onCaptionLanguageChanged()
                            } else {
                                viewModel.settings.captionEnabled = false
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
                    .frame(width: 120)
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
                }
            }

            HStack(spacing: 16) {
                // Translation mode toggle
                if viewModel.settings.captionEnabled {
                    Picker("Mode", selection: $settings.translationMode) {
                        // Only showing Live option now, removed Delayed
                        ForEach([TranslationMode.live]) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
                // Capture minutes input / countdown display
                if viewModel.settings.captionEnabled {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Minutes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if viewModel.isCapturing {
                            if viewModel.isCountdownActive {
                                Text(viewModel.countdownDisplay)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(viewModel.countdownSecondsRemaining < 60 ? .red : .orange)
                                    .frame(width: 60, alignment: .center)
                            } else {
                                TextField("Minutes", value: $settings.captureMinutes, format: .number)
                                    .frame(width: 60)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(true)
                            }
                        } else {
                            TextField("Minutes", value: $settings.captureMinutes, format: .number)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: settings.captureMinutes) { oldValue, newValue in
                                    if newValue < 0 {
                                        settings.captureMinutes = 0
                                    } else if newValue > 99 {
                                        settings.captureMinutes = 99
                                    }
                                }
                        }
                    }
                }

                // Translation download status
                if !viewModel.translationStatus.isEmpty {
                    HStack(spacing: 6) {
                        if viewModel.isPreparingTranslation {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(viewModel.translationStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // CaptureThis toggle
                Button {
                    showCaptureSettings = true
                } label: {
                    HStack(spacing: 4) {
                        if viewModel.isCapturing {
                            Image(systemName: "record.circle.fill")
                                .foregroundStyle(.red)
                                .symbolEffect(.pulse, isActive: true)
                        } else if viewModel.settings.captureIsEnabled {
                            Image(systemName: "record.circle")
                                .foregroundStyle(.red)
                        } else {
                            Image(systemName: "record.circle")
                        }
                        Text("CaptureThis")
                    }
                }
                .disabled(viewModel.isCapturing || viewModel.isProcessingVideo)
                .help(viewModel.isCapturing ? "Recording in progress" : "Screen capture settings")

                // Pin toggle
                Toggle(isOn: $settings.isPinned) {
                    Image(systemName: viewModel.settings.isPinned ? "pin.fill" : "pin")
                }
                .toggleStyle(.button)
                .help(viewModel.settings.isPinned ? "Unpin window" : "Pin window on top")

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
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
