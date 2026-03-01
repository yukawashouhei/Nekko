//
//  routes.swift
//  NekkoBackend
//
//  Created by 湯川昇平 on 2026/02/28.
//

import Vapor

func routes(_ app: Application) throws {
    app.get("api", "health") { _ in
        ["status": "ok"]
    }

    app.on(.POST, "api", "transcribe", body: .collect(maxSize: "50mb")) { req async throws -> TranscriptionResponse in
        let input = try req.content.decode(TranscribeInput.self)
        let language = input.language ?? "ja"

        guard let file = input.file else {
            throw Abort(.badRequest, reason: "Audio file is required")
        }

        let mistral = MistralService(apiKey: getMistralAPIKey())
        let result = try await mistral.transcribe(
            audioData: Data(buffer: file.data),
            fileName: file.filename,
            language: language
        )
        return result
    }

    app.post("api", "summarize") { req async throws -> SummarizeResponse in
        let input = try req.content.decode(SummarizeInput.self)

        let mistral = MistralService(apiKey: getMistralAPIKey())
        let summary = try await mistral.summarize(
            text: input.text,
            language: input.language ?? "ja"
        )
        return SummarizeResponse(summary: summary)
    }

    app.post("api", "translate") { req async throws -> TranslateResponse in
        let input = try req.content.decode(TranslateInput.self)

        let mistral = MistralService(apiKey: getMistralAPIKey())
        let translation = try await mistral.translate(
            text: input.text,
            fromLanguage: input.fromLanguage ?? "ja",
            toLanguage: input.toLanguage ?? "en"
        )
        return TranslateResponse(translation: translation)
    }
}

private func getMistralAPIKey() -> String {
    guard let key = Environment.get("MISTRAL_API_KEY"), !key.isEmpty else {
        fatalError("MISTRAL_API_KEY environment variable is not set")
    }
    return key
}

// MARK: - Request / Response Types

struct TranscribeInput: Content {
    var file: File?
    var language: String?
}

struct TranscriptionResponse: Content {
    let text: String
    let segments: [TranscriptionSegment]?
}

struct TranscriptionSegment: Content {
    let speaker: String?
    let start: Double?
    let end: Double?
    let text: String
}

struct SummarizeInput: Content {
    let text: String
    let language: String?
}

struct SummarizeResponse: Content {
    let summary: String
}

struct TranslateInput: Content {
    let text: String
    let fromLanguage: String?
    let toLanguage: String?
}

struct TranslateResponse: Content {
    let translation: String
}
