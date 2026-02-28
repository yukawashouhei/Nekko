//
//  MistralService.swift
//  NekkoBackend
//
//  Created by 湯川昇平 on 2026/02/28.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct MistralService: Sendable {
    let apiKey: String
    private let baseURL = "https://api.mistral.ai/v1"

    // MARK: - Transcription (Voxtral Mini)

    func transcribe(
        audioData: Data,
        fileName: String,
        language: String
    ) async throws -> TranscriptionResponse {
        let url = URL(string: "\(baseURL)/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 300

        let boundary = UUID().uuidString
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        var body = Data()
        let lineBreak = "\r\n"

        body.appendString("--\(boundary)\(lineBreak)")
        body.appendString("Content-Disposition: form-data; name=\"model\"\(lineBreak)\(lineBreak)")
        body.appendString("voxtral-mini-latest\(lineBreak)")

        body.appendString("--\(boundary)\(lineBreak)")
        body.appendString("Content-Disposition: form-data; name=\"language\"\(lineBreak)\(lineBreak)")
        body.appendString("\(language)\(lineBreak)")

        body.appendString("--\(boundary)\(lineBreak)")
        body.appendString("Content-Disposition: form-data; name=\"diarize\"\(lineBreak)\(lineBreak)")
        body.appendString("true\(lineBreak)")

        body.appendString("--\(boundary)\(lineBreak)")
        body.appendString("Content-Disposition: form-data; name=\"timestamp_granularities[]\"\(lineBreak)\(lineBreak)")
        body.appendString("segment\(lineBreak)")

        body.appendString("--\(boundary)\(lineBreak)")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\(lineBreak)")
        body.appendString("Content-Type: audio/mp4\(lineBreak)\(lineBreak)")
        body.append(audioData)
        body.appendString(lineBreak)

        body.appendString("--\(boundary)--\(lineBreak)")

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MistralError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw MistralError.apiError(httpResponse.statusCode, errorBody)
        }

        let decoded = try JSONDecoder().decode(VoxtralResponse.self, from: data)

        let segments = decoded.segments?.map { segment in
            TranscriptionSegment(
                speaker: segment.speaker,
                start: segment.start,
                end: segment.end,
                text: segment.text
            )
        }

        return TranscriptionResponse(
            text: decoded.text,
            segments: segments
        )
    }

    // MARK: - Summarization (Mistral Small)

    func summarize(text: String, language: String) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let languageName: String
        switch language {
        case "ja": languageName = "日本語"
        case "en": languageName = "English"
        case "fr": languageName = "Français"
        default: languageName = "the same language as the input"
        }

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
                ChatMessage(
                    role: "user",
                    content: text
                ),
            ],
            temperature: 0.3
        )

        request.httpBody = try JSONEncoder().encode(chatRequest)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MistralError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw MistralError.apiError(httpResponse.statusCode, errorBody)
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw MistralError.emptyResponse
        }
        return content
    }
}

// MARK: - Mistral API Types

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

enum MistralError: Error, CustomStringConvertible {
    case invalidResponse
    case apiError(Int, String)
    case emptyResponse

    var description: String {
        switch self {
        case .invalidResponse: "Invalid response from Mistral API"
        case .apiError(let code, let body): "Mistral API error (\(code)): \(body)"
        case .emptyResponse: "Empty response from Mistral API"
        }
    }
}

// MARK: - Data Extension

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
