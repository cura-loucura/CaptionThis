import SwiftUI

struct HeaderView: View {
    @Bindable var viewModel: CaptionViewModel

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
                        ForEach(TranslationMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                Spacer()

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
