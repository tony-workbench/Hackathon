import SwiftUI

struct LiveTranslationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = LiveTranslationViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Translation direction", selection: $viewModel.direction) {
                    ForEach(LiveTranslationViewModel.TranslationDirection.allCases) { direction in
                        Text(direction.title).tag(direction)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.direction) { oldValue, newValue in
                    if oldValue != newValue {
                        viewModel.transcript = ""
                        viewModel.translatedText = ""
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Mic level: \(Int(viewModel.microphoneLevel))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: viewModel.isAudioOutputEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .font(.caption)
                                .foregroundStyle(viewModel.isAudioOutputEnabled ? .blue : .secondary)

                            Text(viewModel.isAudioOutputEnabled ? "Audio ON" : "Audio OFF")
                                .font(.caption)
                                .foregroundStyle(viewModel.isAudioOutputEnabled ? .blue : .secondary)
                        }
                        .onTapGesture {
                            viewModel.toggleAudioOutput()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    transcriptCard(
                        title: viewModel.direction.sourceLanguageName,
                        text: viewModel.transcript,
                        placeholder: "Your API transcript will appear here…",
                        isLoading: viewModel.isTranslating
                    )

                    transcriptCard(
                        title: viewModel.direction.targetLanguageName,
                        text: viewModel.translatedText,
                        placeholder: "Your API translation will appear here…",
                        isLoading: viewModel.isTranslating
                    )
                }

                Spacer()

                CustomButton(
                    title: viewModel.isListening ? "Stop microphone" : "Start microphone",
                    style: viewModel.isListening ? .destructive : .primary,
                    isDisabled: false
                ) {
                    if viewModel.isListening {
                        viewModel.stopListening()
                    } else {
                        Task {
                            await viewModel.startListening()
                        }
                    }
                }
            }
            .padding(24)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Live Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }

                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    Button("Test") {
                        Task {
                            await viewModel.testBackend()
                        }
                    }
                    .font(.caption)
                }
                #endif
            }
        }
        .alert("Translation Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    @ViewBuilder
    private func transcriptCard(title: String, text: String, placeholder: String, isLoading: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ScrollView {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(text)
                        .font(.body)
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 200)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct LiveTranslationOverlayPanel: View {
    @Bindable var viewModel: LiveTranslationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Translation")
                    .font(.headline)
                    .foregroundStyle(.black)

                Spacer()

                Picker("Direction", selection: $viewModel.direction) {
                    ForEach(LiveTranslationViewModel.TranslationDirection.allCases) { direction in
                        Text(direction.title).tag(direction)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(.black)
                .onChange(of: viewModel.direction) { oldValue, newValue in
                    if oldValue != newValue {
                        viewModel.transcript = ""
                        viewModel.translatedText = ""
                    }
                }
            }

            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundStyle(Color.black.opacity(0.72))
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 8) {
                compactTextRow(
                    title: viewModel.direction.sourceLanguageName,
                    text: viewModel.transcript,
                    placeholder: "Transcript…"
                )

                compactTextRow(
                    title: viewModel.direction.targetLanguageName,
                    text: viewModel.translatedText,
                    placeholder: "Translation…"
                )
            }

            HStack(spacing: 10) {
                Button {
                    if viewModel.isListening {
                        viewModel.stopListening()
                    } else {
                        Task {
                            await viewModel.startListening()
                        }
                    }
                } label: {
                    Label(
                        viewModel.isListening ? "Stop" : "Start",
                        systemImage: viewModel.isListening ? "stop.fill" : "mic.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isListening ? .red : .blue)

                Button {
                    viewModel.toggleAudioOutput()
                } label: {
                    Image(systemName: viewModel.isAudioOutputEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.bordered)
                .tint(.black)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)
        .alert("Translation Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    @ViewBuilder
    private func compactTextRow(title: String, text: String, placeholder: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.72))
                .frame(width: 58, alignment: .leading)

            Text(text.isEmpty ? placeholder : text)
                .font(.subheadline)
                .foregroundStyle(text.isEmpty ? Color.black.opacity(0.52) : .black)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
