//
//  Recording.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import Foundation
import SwiftData

@Model
final class Recording {
    var id: UUID
    var title: String
    var createdAt: Date
    var duration: TimeInterval
    var language: String
    var audioFileName: String?
    var liveTranscription: String
    var finalTranscription: String?
    var summary: String?
    var isProcessing: Bool
    var segments: String?
    var translation: String?
    var translationLanguage: String?

    init(
        title: String,
        language: String,
        duration: TimeInterval = 0,
        audioFileName: String? = nil,
        liveTranscription: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.duration = duration
        self.language = language
        self.audioFileName = audioFileName
        self.liveTranscription = liveTranscription
        self.finalTranscription = nil
        self.summary = nil
        self.isProcessing = false
        self.segments = nil
        self.translation = nil
        self.translationLanguage = nil
    }

    var displayTranscription: String {
        finalTranscription ?? liveTranscription
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月 d日, HH:mm"
        return formatter.string(from: createdAt)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return String(format: "%d:%02d:%02d", hours, mins, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var durationLabel: String {
        let totalMinutes = Int(duration) / 60
        if totalMinutes < 1 { return "<1分" }
        return "\(totalMinutes)分"
    }

    var decodedSegments: [TranscriptionSegmentData]? {
        guard let segments, let data = segments.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([TranscriptionSegmentData].self, from: data)
    }
}

struct TranscriptionSegmentData: Codable, Identifiable {
    let speaker: String?
    let start: Double?
    let end: Double?
    let text: String

    var id: String {
        "\(speaker ?? "")_\(start ?? 0)_\(text.prefix(20))"
    }

    var speakerLabel: String {
        guard let speaker else { return "不明" }
        return speaker
    }

    var timeRange: String {
        guard let start, let end else { return "" }
        return "\(formatTime(start)) - \(formatTime(end))"
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
