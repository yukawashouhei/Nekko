//
//  BackendAPIService.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import Foundation

@Observable
final class BackendAPIService {
    static let shared = BackendAPIService()

    private static let mistralBaseURL = "https://api.mistral.ai/v1"
    private let session = URLSession.shared

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "nekko_mistral_api_key") ?? ""
    }

    private var hasAPIKey: Bool { !apiKey.isEmpty }

    // MARK: - Transcription (Direct Mistral API)

    func transcribe(audioFileURL: URL, language: String) async throws -> String {
        let result = try await transcribeWithSegments(audioFileURL: audioFileURL, language: language)
        return result.text
    }

    func transcribeWithSegments(audioFileURL: URL, language: String) async throws -> TranscriptionResult {
        guard hasAPIKey else { throw APIError.noAPIKey }

        let url = URL(string: "\(Self.mistralBaseURL)/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 300

        let boundary = UUID().uuidString
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        let audioData = try Data(contentsOf: audioFileURL)
        let body = createTranscriptionBody(
            boundary: boundary,
            audioData: audioData,
            fileName: audioFileURL.lastPathComponent,
            language: language
        )
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            print("[BackendAPI] Transcription error \(statusCode): \(errorBody)")
            throw APIError.serverError(statusCode)
        }

        let decoded = try JSONDecoder().decode(VoxtralResponse.self, from: data)
        let segments = decoded.segments?.map { seg in
            TranscriptionSegment(
                speaker: seg.speaker,
                start: seg.start,
                end: seg.end,
                text: seg.text
            )
        }

        return TranscriptionResult(text: decoded.text, segments: segments)
    }

    // MARK: - Summarization (Direct Mistral API)

    func summarize(text: String, language: String) async throws -> String {
        guard hasAPIKey else { throw APIError.noAPIKey }

        let languageName = languageDisplayName(language)
        let chatRequest = ChatRequest(
            model: "mistral-small-latest",
            messages: [
                ChatMessage(
                    role: "system",
                    content: """
                        You are a professional meeting summarizer. Summarize the following transcription concisely in \(languageName). \
                        Include key points, decisions made, and action items if any. \
                        Keep the summary clear and well-structured with bullet points.
                        """
                ),
                ChatMessage(role: "user", content: text),
            ],
            temperature: 0.3
        )

        return try await chatCompletion(chatRequest)
    }

    // MARK: - Translation (Direct Mistral API)

    func translate(text: String, fromLanguage: String, toLanguage: String) async throws -> String {
        guard hasAPIKey else { throw APIError.noAPIKey }

        let fromName = languageDisplayName(fromLanguage)
        let toName = languageDisplayName(toLanguage)

        let chatRequest = ChatRequest(
            model: "mistral-small-latest",
            messages: [
                ChatMessage(
                    role: "system",
                    content: """
                        You are a professional translator. Translate the following text from \(fromName) to \(toName). \
                        Maintain the original meaning, tone, and formatting. \
                        If the text contains speaker labels or timestamps, preserve them. \
                        Only output the translated text, no explanations.
                        """
                ),
                ChatMessage(role: "user", content: text),
            ],
            temperature: 0.2
        )

        return try await chatCompletion(chatRequest)
    }

    // MARK: - Chat Completion Helper

    private func chatCompletion(_ chatRequest: ChatRequest) async throws -> String {
        let url = URL(string: "\(Self.mistralBaseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        request.httpBody = try JSONEncoder().encode(chatRequest)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            print("[BackendAPI] Chat error \(statusCode): \(errorBody)")
            throw APIError.serverError(statusCode)
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        return content
    }

    // MARK: - Multipart Body

    private func createTranscriptionBody(
        boundary: String,
        audioData: Data,
        fileName: String,
        language: String
    ) -> Data {
        var body = Data()
        let crlf = "\r\n"

        func addField(_ name: String, _ value: String) {
            body.append("--\(boundary)\(crlf)")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)")
            body.append("\(value)\(crlf)")
        }

        addField("model", "voxtral-mini-latest")
        addField("language", language)
        addField("diarize", "true")
        addField("timestamp_granularities[]", "segment")

        body.append("--\(boundary)\(crlf)")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\(crlf)")
        body.append("Content-Type: audio/mp4\(crlf)\(crlf)")
        body.append(audioData)
        body.append(crlf)

        body.append("--\(boundary)--\(crlf)")
        return body
    }

    // MARK: - Language Helper

    private func languageDisplayName(_ code: String) -> String {
        switch code {
        case "ja": "日本語"
        case "en": "English"
        case "fr": "Français"
        case "de": "Deutsch"
        case "es": "Español"
        case "it": "Italiano"
        case "pt": "Português"
        case "nl": "Nederlands"
        case "ru": "Русский"
        case "zh": "中文"
        case "ko": "한국어"
        case "ar": "العربية"
        case "hi": "हिन्दी"
        default: "the same language as the input"
        }
    }
}

// MARK: - API Types

extension BackendAPIService {
    enum APIError: LocalizedError {
        case serverError(Int)
        case invalidResponse
        case noAPIKey

        var errorDescription: String? {
            switch self {
            case .serverError(let code): "APIエラー (コード: \(code))"
            case .invalidResponse: "不正なレスポンス"
            case .noAPIKey: "Mistral APIキーが設定されていません"
            }
        }
    }

    struct TranscriptionResult {
        let text: String
        let segments: [TranscriptionSegment]?
    }

    struct TranscriptionSegment: Codable {
        let speaker: String?
        let start: Double?
        let end: Double?
        let text: String
    }
}

// MARK: - Mistral API Response Types

private struct VoxtralResponse: Codable {
    let text: String
    let language: String?
    let segments: [VoxtralSegment]?
}

private struct VoxtralSegment: Codable {
    let speaker: String?
    let start: Double?
    let end: Double?
    let text: String
}

private struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatResponse: Codable {
    let choices: [ChatChoice]
}

private struct ChatChoice: Codable {
    let message: ChatMessage
}

// MARK: - Data Extension

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
