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

    var backendURL: String {
        get { UserDefaults.standard.string(forKey: "nekko_backend_url") ?? "http://localhost:8080" }
        set { UserDefaults.standard.set(newValue, forKey: "nekko_backend_url") }
    }

    private let session = URLSession.shared

    // MARK: - Transcription

    func transcribe(audioFileURL: URL, language: String) async throws -> String {
        let url = URL(string: "\(backendURL)/api/transcribe")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300

        let boundary = UUID().uuidString
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        let audioData = try Data(contentsOf: audioFileURL)
        let body = createMultipartBody(
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
            throw APIError.serverError(
                (response as? HTTPURLResponse)?.statusCode ?? 0
            )
        }

        let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return result.text
    }

    // MARK: - Summarization

    func summarize(text: String, language: String) async throws -> String {
        let url = URL(string: "\(backendURL)/api/summarize")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body = SummarizeRequest(text: text, language: language)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
            throw APIError.serverError(
                (response as? HTTPURLResponse)?.statusCode ?? 0
            )
        }

        let result = try JSONDecoder().decode(SummarizeResponse.self, from: data)
        return result.summary
    }

    // MARK: - Multipart Body

    private func createMultipartBody(
        boundary: String,
        audioData: Data,
        fileName: String,
        language: String
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        body.append("--\(boundary)\(lineBreak)")
        body.append("Content-Disposition: form-data; name=\"language\"\(lineBreak)\(lineBreak)")
        body.append("\(language)\(lineBreak)")

        body.append("--\(boundary)\(lineBreak)")
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\(lineBreak)"
        )
        body.append("Content-Type: audio/mp4\(lineBreak)\(lineBreak)")
        body.append(audioData)
        body.append(lineBreak)

        body.append("--\(boundary)--\(lineBreak)")
        return body
    }
}

// MARK: - API Types

extension BackendAPIService {
    enum APIError: LocalizedError {
        case serverError(Int)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .serverError(let code): "サーバーエラー (コード: \(code))"
            case .invalidResponse: "不正なレスポンス"
            }
        }
    }

    struct TranscriptionResponse: Codable {
        let text: String
        let segments: [TranscriptionSegment]?
    }

    struct TranscriptionSegment: Codable {
        let speaker: String?
        let start: Double?
        let end: Double?
        let text: String
    }

    struct SummarizeRequest: Codable {
        let text: String
        let language: String
    }

    struct SummarizeResponse: Codable {
        let summary: String
    }
}

// MARK: - Data Extension

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
