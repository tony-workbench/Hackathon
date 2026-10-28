//
//  EnhancedLiveTranslationView.swift
//  Full-screen translation view, opened from the Translate button while streaming.
//

import SwiftUI

struct EnhancedLiveTranslationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = LiveTranslationViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        directionSelector
                        
                        statusCard
                        
                        VStack(spacing: 16) {
                            transcriptCard(
                                title: viewModel.direction.sourceLanguageName,
                                emoji: String(viewModel.direction.emoji.prefix(2)),
                                text: viewModel.transcript,
                                placeholder: "Speak in \(viewModel.direction.sourceLanguageName)...",
                                isSource: true
                            )
                            
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title)
                                .foregroundStyle(.blue)
                                .opacity(viewModel.isTranslating ? 1 : 0.3)
                                .scaleEffect(viewModel.isTranslating ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: viewModel.isTranslating)
                            
                            transcriptCard(
                                title: viewModel.direction.targetLanguageName,
                                emoji: String(viewModel.direction.emoji.suffix(2)),
                                text: viewModel.translatedText,
                                placeholder: "Translation appears here...",
                                isSource: false
                            )
                        }
                        
                        if viewModel.isListening {
                            microphoneLevelView
                        }
                        
                        controlButtons
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Live Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.toggleAudioOutput()
                    } label: {
                        Image(systemName: viewModel.isAudioOutputEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.title3)
                            .foregroundStyle(viewModel.isAudioOutputEnabled ? .blue : .secondary)
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    // MARK: - Direction Selector
    
    private var directionSelector: some View {
        VStack(spacing: 12) {
            Text("Translation Direction")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(LiveTranslationViewModel.TranslationDirection.allCases) { direction in
                        DirectionButton(
                            direction: direction,
                            isSelected: viewModel.direction == direction
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                if viewModel.direction != direction {
                                    viewModel.changeDirection(to: direction)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Status Card
    
    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.isListening ? "waveform" : "mic.slash.fill")
                .font(.title2)
                .foregroundStyle(viewModel.isListening ? .blue : .secondary)
                .symbolEffect(.variableColor, isActive: viewModel.isListening)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.isListening ? "Listening..." : "Ready")
                    .font(.headline)
                
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if viewModel.isTranslating {
                ProgressView()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    // MARK: - Transcript Card
    
    private func transcriptCard(title: String, emoji: String, text: String, placeholder: String, isSource: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(emoji)
                    .font(.title2)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                if !text.isEmpty {
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    Text(text)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 100)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSource ? Color.blue.opacity(0.05) : Color.purple.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSource ? Color.blue.opacity(0.2) : Color.purple.opacity(0.2), lineWidth: 1)
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    // MARK: - Microphone Level
    
    private var microphoneLevelView: some View {
        VStack(spacing: 8) {
            Text("Microphone Level")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.green, .yellow, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(viewModel.microphoneLevel / 32768, 1.0))
                        .animation(.linear(duration: 0.1), value: viewModel.microphoneLevel)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        VStack(spacing: 12) {
            Button {
                if viewModel.isListening {
                    viewModel.stopListening()
                } else {
                    Task {
                        await viewModel.startListening()
                    }
                }
            } label: {
                HStack {
                    Image(systemName: viewModel.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                    
                    Text(viewModel.isListening ? "Stop & Translate" : "Start Listening")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isListening ? Color.red : Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: (viewModel.isListening ? Color.red : Color.blue).opacity(0.3), radius: 8, y: 4)
            }
            .disabled(viewModel.isTranslating)
            
            HStack(spacing: 12) {
                Button {
                    viewModel.changeDirection(to: .englishToMandarin)
                } label: {
                    VStack(spacing: 4) {
                        Text("🇺🇸🇨🇳")
                            .font(.title3)
                        Text("EN→中文")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button {
                    viewModel.changeDirection(to: .mandarinToEnglish)
                } label: {
                    VStack(spacing: 4) {
                        Text("🇨🇳🇺🇸")
                            .font(.title3)
                        Text("中文→EN")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button {
                    viewModel.changeDirection(to: .englishToSpanish)
                } label: {
                    VStack(spacing: 4) {
                        Text("🇺🇸🇪🇸")
                            .font(.title3)
                        Text("EN→ES")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// MARK: - Direction Button Component

struct DirectionButton: View {
    let direction: LiveTranslationViewModel.TranslationDirection
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(direction.emoji)
                    .font(.title)
                
                Text(direction.title)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .shadow(color: isSelected ? Color.blue.opacity(0.3) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    EnhancedLiveTranslationView()
}
