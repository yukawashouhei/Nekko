//
//  MistralRealtimeService.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import AVFoundation
import Foundation

@Observable
final class MistralRealtimeService: @unchecked Sendable {
    private(set) var transcription = ""
    private(set) var isConnected = false
    private(set) var error: String?

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var sendTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var audioConverter: AVAudioConverter?
    private var pendingAudioData = Data()
    private let sendLock = NSLock()
    private var isStopping = false

    private static let targetSampleRate: Double = 16000
    private static let wsBaseURL = "wss://api.mistral.ai/v1/audio/transcriptions/realtime"
    private static let model = "voxtral-mini-transcribe-realtime-2602"

    var apiKey: String {
        UserDefaults.standard.string(forKey: "nekko_mistral_api_key") ?? ""
    }

    var hasAPIKey: Bool {
        !apiKey.isEmpty
    }

    // MARK: - Public

    func start(language: String) async {
        guard hasAPIKey else {
            error = "Mistral APIキーが設定されていません。設定画面から入力してください。"
            return
        }

        isStopping = false
        transcription = ""
        error = nil
        pendingAudioData = Data()

        do {
            try await connectWebSocket(language: language)
        } catch {
            self.error = "WebSocket接続に失敗しました: \(error.localizedDescription)"
        }
    }

    func stop() async {
        guard !isStopping else { return }
        isStopping = true

        sendEndAudio()

        try? await Task.sleep(for: .milliseconds(500))

        sendTask?.cancel()
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        audioConverter = nil
        isConnected = false
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isConnected, !isStopping else { return }

        let pcmData = convertToTargetFormat(buffer: buffer)
        guard !pcmData.isEmpty else { return }

        sendLock.lock()
        pendingAudioData.append(pcmData)

        let chunkSize = Int(Self.targetSampleRate) * 2 * 480 / 1000 // 480ms chunks (15360 bytes)
        while pendingAudioData.count >= chunkSize {
            let chunk = pendingAudioData.prefix(chunkSize)
            pendingAudioData = Data(pendingAudioData.dropFirst(chunkSize))
            sendLock.unlock()
            sendAudioChunk(Data(chunk))
            sendLock.lock()
        }
        sendLock.unlock()
    }

    // MARK: - WebSocket

    private func connectWebSocket(language: String) async throws {
        var components = URLComponents(string: Self.wsBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "model", value: Self.model),
            URLQueryItem(name: "language", value: language),
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 300

        let session = URLSession(configuration: .default)
        self.urlSession = session
        let task = session.webSocketTask(with: request)
        self.webSocketTask = task
        task.resume()

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }

        try await waitForSessionCreated()
        await sendSessionUpdate()
    }

    private func waitForSessionCreated() async throws {
        let timeout: UInt64 = 15_000_000_000 // 15 seconds
        let start = ContinuousClock.now

        while ContinuousClock.now - start < .nanoseconds(Int64(timeout)) {
            if isConnected { return }
            if let error = self.error { throw NSError(domain: "MistralRealtime", code: -1, userInfo: [NSLocalizedDescriptionKey: error]) }
            try await Task.sleep(for: .milliseconds(100))
        }

        if !isConnected {
            throw NSError(domain: "MistralRealtime", code: -1, userInfo: [NSLocalizedDescriptionKey: "セッション作成がタイムアウトしました"])
        }
    }

    private func sendSessionUpdate() async {
        let message: [String: Any] = [
            "type": "session.update",
            "session": [
                "audio_format": [
                    "encoding": "pcm_s16le",
                    "sample_rate": Int(Self.targetSampleRate),
                ],
                "target_streaming_delay_ms": 480,
            ],
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: data, encoding: .utf8)
        else { return }

        try? await webSocketTask?.send(.string(jsonString))
    }

    private func receiveLoop() async {
        guard let task = webSocketTask else { return }

        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    handleServerEvent(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleServerEvent(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                if !isStopping {
                    await MainActor.run {
                        self.error = "WebSocket受信エラー: \(error.localizedDescription)"
                        self.isConnected = false
                    }
                }
                break
            }
        }
    }

    private func handleServerEvent(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String
        else { return }

        Task { @MainActor in
            switch type {
            case "session.created":
                self.isConnected = true

            case "session.updated":
                break

            case "transcription.text.delta":
                if let deltaText = json["text"] as? String {
                    self.transcription += deltaText
                }

            case "transcription.done":
                break

            case "error":
                if let errorObj = json["error"] as? [String: Any],
                   let message = errorObj["message"] as? String {
                    self.error = message
                } else {
                    self.error = "Mistral APIエラーが発生しました"
                }

            default:
                break
            }
        }
    }

    // MARK: - Audio Send

    private func sendAudioChunk(_ data: Data) {
        let base64 = data.base64EncodedString()
        let message: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64,
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else { return }

        webSocketTask?.send(.string(jsonString)) { error in
            if let error {
                print("Audio send error: \(error.localizedDescription)")
            }
        }
    }

    private func sendFlushAudio() {
        let message = "{\"type\":\"input_audio_buffer.flush\"}"
        webSocketTask?.send(.string(message)) { _ in }
    }

    private func sendEndAudio() {
        sendLock.lock()
        if !pendingAudioData.isEmpty {
            let remaining = pendingAudioData
            pendingAudioData = Data()
            sendLock.unlock()
            sendAudioChunk(remaining)
        } else {
            sendLock.unlock()
        }

        sendFlushAudio()

        let message = "{\"type\":\"input_audio_buffer.end\"}"
        webSocketTask?.send(.string(message)) { _ in }
    }

    // MARK: - Audio Conversion (to 16kHz mono S16LE)

    private func convertToTargetFormat(buffer: AVAudioPCMBuffer) -> Data {
        let inputFormat = buffer.format
        let targetRate = Self.targetSampleRate

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetRate,
            channels: 1,
            interleaved: true
        ) else { return Data() }

        if inputFormat.sampleRate == targetRate && inputFormat.channelCount == 1 && inputFormat.commonFormat == .pcmFormatInt16 {
            return bufferToData(buffer)
        }

        if audioConverter == nil || audioConverter?.inputFormat != inputFormat {
            audioConverter = AVAudioConverter(from: inputFormat, to: outputFormat)
        }

        guard let converter = audioConverter else { return Data() }

        let ratio = targetRate / inputFormat.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard outputFrameCount > 0,
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCount)
        else { return Data() }

        var error: NSError?
        var consumed = false
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        if error != nil { return Data() }
        return bufferToData(outputBuffer)
    }

    private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return Data() }

        if buffer.format.commonFormat == .pcmFormatInt16, let int16Data = buffer.int16ChannelData {
            return Data(bytes: int16Data[0], count: frameCount * 2)
        }

        if let floatData = buffer.floatChannelData {
            var data = Data(count: frameCount * 2)
            data.withUnsafeMutableBytes { rawBuffer in
                let int16Ptr = rawBuffer.bindMemory(to: Int16.self)
                for i in 0..<frameCount {
                    let sample = max(-1.0, min(1.0, floatData[0][i]))
                    int16Ptr[i] = Int16(sample * Float(Int16.max))
                }
            }
            return data
        }

        return Data()
    }
}
