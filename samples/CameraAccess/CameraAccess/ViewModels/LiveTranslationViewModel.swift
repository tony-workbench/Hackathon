import AVFoundation
import Foundation
import Observation
import Speech
import MediaPlayer  // Play/pause commands from the glasses

@Observable
@MainActor
final class LiveTranslationViewModel {
    enum TranslationDirection: String, CaseIterable, Identifiable, Codable {
        case englishToSpanish
        case spanishToEnglish
        case englishToMandarin
        case mandarinToEnglish

        var id: String { rawValue }

        var title: String {
            switch self {
            case .englishToSpanish:
                return "English → Spanish"
            case .spanishToEnglish:
                return "Spanish → English"
            case .englishToMandarin:
                return "English → 中文"
            case .mandarinToEnglish:
                return "中文 → English"
            }
        }
        
        var emoji: String {
            switch self {
            case .englishToSpanish:
                return "🇺🇸🇪🇸"
            case .spanishToEnglish:
                return "🇪🇸🇺🇸"
            case .englishToMandarin:
                return "🇺🇸🇨🇳"
            case .mandarinToEnglish:
                return "🇨🇳🇺🇸"
            }
        }

        var sourceLanguageName: String {
            switch self {
            case .englishToSpanish, .englishToMandarin:
                return "English"
            case .spanishToEnglish:
                return "Spanish"
            case .mandarinToEnglish:
                return "Mandarin"
            }
        }

        var targetLanguageName: String {
            switch self {
            case .englishToSpanish:
                return "Spanish"
            case .spanishToEnglish, .mandarinToEnglish:
                return "English"
            case .englishToMandarin:
                return "Mandarin"
            }
        }
        
        var sourceLanguageCode: String {
            switch self {
            case .englishToSpanish, .englishToMandarin:
                return "en"
            case .spanishToEnglish:
                return "es"
            case .mandarinToEnglish:
                return "zh"
            }
        }
        
        var targetLanguageCode: String {
            switch self {
            case .englishToSpanish:
                return "es"
            case .spanishToEnglish, .mandarinToEnglish:
                return "en"
            case .englishToMandarin:
                return "zh"
            }
        }
    }

    private struct TranslationRequest: Encodable {
        let direction: TranslationDirection
        let mimeType: String
        let audioBase64: String
    }

    private struct TranslationResponse: Decodable {
        let transcript: String
        let translation: String
    }

    private struct BackendErrorResponse: Decodable {
        let error: String
    }

    var direction: TranslationDirection = .englishToSpanish
    var transcript: String = ""
    var translatedText: String = ""
    var isListening: Bool = false
    var isTranslating: Bool = false
    var showError: Bool = false
    var errorMessage: String = ""
    var statusMessage: String = "Ready"
    var microphoneLevel: Double = 0
    var isAudioOutputEnabled: Bool = true

    private let audioEngine = AVAudioEngine()
    // Same backend URL as produce inspection; set it in AppConfiguration.swift.
    private var backendBaseURL: URL {
        AppConfiguration.shared.backendURL ?? URL(string: AppConfiguration.defaultBackendURL)!
    }
    private let audioQueue = DispatchQueue(label: "live.translation.audio.queue")
    private let targetSampleRate: Double = 16_000
    
    // One session for all backend requests, with short timeouts and no cache.
    private let urlSession: URLSession

    private let sampleBuffer = SampleBuffer()
    private var inputSampleRate: Double = 48_000
    private var uploadTask: Task<Void, Never>?
    
    // Reads each translation aloud.
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // Set to true to test the UI with canned translations and no backend.
    private let useMockTranslation = false
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = 2
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        self.urlSession = URLSession(configuration: config)
        
        // The glasses send play/pause commands; use them to start and stop listening.
        setupRemoteCommandCenter()
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.startListening()
            }
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stopListening()
            }
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isListening {
                    self.stopListening()
                } else {
                    await self.startListening()
                }
            }
            return .success
        }
        
        print("🎮 Meta glasses button controls enabled")
    }
    
    private func updateNowPlayingInfo(isListening: Bool) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "Live Translation"
        nowPlayingInfo[MPMediaItemPropertyArtist] = isListening ? "Listening..." : "Ready"
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isListening ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func speakTranslation(_ text: String, language: String) {
        guard isAudioOutputEnabled, !text.isEmpty else { return }
        
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        
        switch language.lowercased() {
        case "spanish", "español":
            utterance.voice = AVSpeechSynthesisVoice(language: "es-ES")
        case "mandarin", "chinese", "中文":
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        case "english":
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        default:
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        print("🔊 Speaking (\(language)): '\(text)'")
        speechSynthesizer.speak(utterance)
    }

    func startListening() async {
        guard !isListening else { return }

        let microphoneAuthorized = await requestMicrophoneAuthorization()
        guard microphoneAuthorized else {
            showError("Microphone permission is required for live translation.")
            return
        }

        do {
            sampleBuffer.removeAll()
            try beginAudioCapture()
            statusMessage = "Listening… tap Stop microphone to translate."
            updateNowPlayingInfo(isListening: true)
        } catch {
            showError("Unable to start microphone capture: \(error.localizedDescription)")
        }
    }
    
    func testBackend() async {
        statusMessage = "Testing backend connection…"
        
        do {
            var request = URLRequest(url: backendBaseURL)
            request.timeoutInterval = 5
            
            let (_, response) = try await urlSession.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                statusMessage = "Backend reachable (HTTP \(httpResponse.statusCode))"
            }
        } catch {
            statusMessage = "Backend unreachable: \(error.localizedDescription)"
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        updateNowPlayingInfo(isListening: false)

        let recordedSamples = sampleBuffer.drain()

        isListening = false
        microphoneLevel = 0

        print("🎤 Recorded \(recordedSamples.count) samples")

        guard !recordedSamples.isEmpty else {
            statusMessage = "No audio was captured."
            showError("No audio captured! Check microphone permissions in Settings.")
            return
        }

        statusMessage = "Microphone stopped. Translating…"
        
        let trimmedSamples = Self.trimSilence(from: recordedSamples)
        
        print("🔇 Trimmed silence: \(recordedSamples.count) → \(trimmedSamples.count) samples")
        
        guard !trimmedSamples.isEmpty else {
            statusMessage = "No audio detected (only silence)."
            showError("Only silence detected. Speak louder and closer to the microphone.")
            return
        }
        
        let wavData = Self.makeWAVData(samples: trimmedSamples, sampleRate: Int(targetSampleRate))
        
        let trimmedDuration = Double(trimmedSamples.count) / targetSampleRate
        print("📦 WAV size: \(wavData.count / 1024)KB (\(String(format: "%.1f", trimmedDuration))s)")
        
        // Debug builds keep each clip in the app's Documents folder for listening back.
        #if DEBUG
        Self.saveDebugAudio(wavData)
        #endif
        
        statusMessage = "Sending \(String(format: "%.1f", trimmedDuration))s audio to backend…"
        sendAudioChunk(wavData)
    }

    func changeDirection(to newDirection: TranslationDirection) {
        guard newDirection != direction else { return }
        direction = newDirection
        transcript = ""
        translatedText = ""
    }

    func dismissError() {
        showError = false
        errorMessage = ""
    }

    func toggleAudioOutput() {
        isAudioOutputEnabled.toggle()

        if !isAudioOutputEnabled, speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
    }

    func cleanup() {
        uploadTask?.cancel()
        uploadTask = nil

        if isListening {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            isListening = false
        }

        microphoneLevel = 0
        sampleBuffer.removeAll()
        speechSynthesizer.stopSpeaking(at: .immediate)
        updateNowPlayingInfo(isListening: false)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func beginAudioCapture() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.duckOthers, .allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker]
        )
        try audioSession.setPreferredSampleRate(targetSampleRate)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputSampleRate = recordingFormat.sampleRate

        let capturedInputSampleRate = recordingFormat.sampleRate
        let capturedTargetSampleRate = targetSampleRate
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.handleAudioBuffer(
                buffer,
                inputSampleRate: capturedInputSampleRate,
                targetSampleRate: capturedTargetSampleRate
            )
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    nonisolated private func handleAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        inputSampleRate: Double,
        targetSampleRate: Double
    ) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        var convertedSamples: [Int16] = []
        convertedSamples.reserveCapacity(frameLength)

        for index in 0..<frameLength {
            let sample = max(-1, min(1, channelData[index]))
            convertedSamples.append(Int16(sample * Float(Int16.max)))
        }

        let resampledSamples = Self.resample(
            convertedSamples,
            from: inputSampleRate,
            to: targetSampleRate
        )
        let currentAverageAmplitude = Self.averageAmplitude(of: resampledSamples)

        Task { @MainActor [weak self] in
            self?.microphoneLevel = currentAverageAmplitude
        }

        audioQueue.async { [weak self] in
            self?.sampleBuffer.append(contentsOf: resampledSamples)
        }
    }

    private func sendAudioChunk(_ data: Data) {
        guard uploadTask == nil else { return }
        isTranslating = true
        
        if useMockTranslation {
            uploadTask = Task { [weak self] in
                guard let self else { return }
                defer {
                    Task { @MainActor in
                        self.isTranslating = false
                        self.uploadTask = nil
                    }
                }
                
                try? await Task.sleep(for: .milliseconds(500))
                
                await MainActor.run {
                    if self.direction == .englishToSpanish {
                        self.transcript = "Hello, how are you today?"
                        self.translatedText = "Hola, ¿cómo estás hoy?"
                    } else {
                        self.transcript = "Hola, ¿cómo estás hoy?"
                        self.translatedText = "Hello, how are you today?"
                    }
                    self.statusMessage = "Mock translation completed."
                }
            }
            return
        }

        let requestBody = TranslationRequest(
            direction: direction,
            mimeType: "audio/wav",
            audioBase64: data.base64EncodedString()
        )

        uploadTask = Task { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor in
                    self.isTranslating = false
                    self.uploadTask = nil
                }
            }

            do {
                let startTime = Date()
                
                var request = URLRequest(url: backendBaseURL.appendingPathComponent("translate-audio"))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
                request.httpBody = try JSONEncoder().encode(requestBody)
                
                // Fail fast if the backend or tunnel is down.
                request.timeoutInterval = 15
                
                print("📤 Sending to backend:")
                print("   - Direction: \(direction.rawValue)")
                print("   - Audio size: \(data.count) bytes (\(data.count / 1024)KB)")
                print("   - Sample rate: 16kHz")
                print("   - Format: WAV, mono, 16-bit")

                let (responseData, response) = try await urlSession.data(for: request)
                
                let elapsed = Date().timeIntervalSince(startTime)
                print("📥 Response received in \(String(format: "%.2f", elapsed))s")
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw LiveTranslationError.invalidServerResponse
                }

                guard 200..<300 ~= httpResponse.statusCode else {
                    if let backendError = try? JSONDecoder().decode(BackendErrorResponse.self, from: responseData) {
                        throw LiveTranslationError.backendError(
                            statusCode: httpResponse.statusCode,
                            message: backendError.error
                        )
                    }

                    let responseBody = String(data: responseData, encoding: .utf8) ?? "Unknown server response"
                    throw LiveTranslationError.backendError(
                        statusCode: httpResponse.statusCode,
                        message: responseBody
                    )
                }

                let translationResponse = try JSONDecoder().decode(TranslationResponse.self, from: responseData)
                
                print("✅ Backend Response:")
                print("   - Transcript: '\(translationResponse.transcript)'")
                print("   - Translation: '\(translationResponse.translation)'")
                
                await MainActor.run {
                    self.transcript = translationResponse.transcript
                    self.translatedText = translationResponse.translation
                    if translationResponse.transcript.isEmpty && translationResponse.translation.isEmpty {
                        self.statusMessage = "No speech detected in audio. Try speaking louder or longer."
                    } else {
                        self.statusMessage = "Translation received in \(String(format: "%.1f", elapsed))s"
                        self.speakTranslation(translationResponse.translation, language: self.direction.targetLanguageName)
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    self.showError("Backend request failed: \(error.localizedDescription)")
                }
            }
        }
    }

    nonisolated private static func resample(_ samples: [Int16], from inputRate: Double, to outputRate: Double) -> [Int16] {
        guard !samples.isEmpty, inputRate > 0, outputRate > 0 else { return samples }
        guard inputRate != outputRate else { return samples }

        let ratio = inputRate / outputRate
        let outputCount = max(Int(Double(samples.count) / ratio), 1)
        var output: [Int16] = []
        output.reserveCapacity(outputCount)

        for outputIndex in 0..<outputCount {
            let sourcePosition = Double(outputIndex) * ratio
            let lowerIndex = min(Int(sourcePosition), samples.count - 1)
            let upperIndex = min(lowerIndex + 1, samples.count - 1)
            let fraction = sourcePosition - Double(lowerIndex)
            let lower = Double(samples[lowerIndex])
            let upper = Double(samples[upperIndex])
            let interpolated = lower + ((upper - lower) * fraction)
            output.append(Int16(max(Double(Int16.min), min(Double(Int16.max), interpolated))))
        }

        return output
    }

    nonisolated private static func averageAmplitude(of samples: [Int16]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let total = samples.reduce(0.0) { partialResult, sample in
            partialResult + Double(abs(Int(sample)))
        }
        return total / Double(samples.count)
    }
    
    nonisolated private static func trimSilence(from samples: [Int16], threshold: Int16 = 500) -> [Int16] {
        guard !samples.isEmpty else { return samples }
        
        var start = 0
        while start < samples.count && abs(samples[start]) < threshold {
            start += 1
        }
        
        var end = samples.count - 1
        while end > start && abs(samples[end]) < threshold {
            end -= 1
        }
        
        guard start < end else { return [] }
        
        // Keep a small buffer before and after speech
        let buffer = 1600 // ~100ms at 16kHz
        start = max(0, start - buffer)
        end = min(samples.count - 1, end + buffer)
        
        return Array(samples[start...end])
    }

    private static func makeWAVData(samples: [Int16], sampleRate: Int) -> Data {
        let channelCount: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(channelCount) * UInt32(bitsPerSample / 8)
        let blockAlign = channelCount * bitsPerSample / 8
        let dataSize = UInt32(samples.count * MemoryLayout<Int16>.size)
        let chunkSize = 36 + dataSize

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.appendLittleEndian(chunkSize)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(channelCount)
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(byteRate)
        data.appendLittleEndian(blockAlign)
        data.appendLittleEndian(bitsPerSample)
        data.append("data".data(using: .ascii)!)
        data.appendLittleEndian(dataSize)

        for sample in samples {
            data.appendLittleEndian(sample)
        }

        return data
    }
    
    #if DEBUG
    private static func saveDebugAudio(_ wavData: Data) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "debug_audio_\(Date().timeIntervalSince1970).wav"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try wavData.write(to: fileURL)
            print("💾 Saved debug audio to: \(fileURL.path)")
            print("   To get it: Xcode > Devices and Simulators > CameraAccess > Download Container")
        } catch {
            print("❌ Failed to save debug audio: \(error)")
        }
    }
    #endif

    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

private final class SampleBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Int16] = []

    func append(contentsOf newSamples: [Int16]) {
        lock.lock()
        samples.append(contentsOf: newSamples)
        lock.unlock()
    }

    func removeAll() {
        lock.lock()
        samples.removeAll()
        lock.unlock()
    }

    func drain() -> [Int16] {
        lock.lock()
        let drainedSamples = samples
        samples.removeAll()
        lock.unlock()
        return drainedSamples
    }
}

private enum LiveTranslationError: LocalizedError {
    case invalidServerResponse
    case backendError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidServerResponse:
            return "The translation server returned an invalid response."
        case let .backendError(statusCode, message):
            return "Backend returned HTTP \(statusCode): \(message)"
        }
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            append(contentsOf: bytes)
        }
    }
}
