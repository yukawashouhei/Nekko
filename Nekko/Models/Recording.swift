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
}
