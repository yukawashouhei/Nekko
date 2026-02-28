//
//  NekkoWidget.swift
//  NekkoWidget
//
//  Created by 湯川昇平 on 2026/02/28.
//
//  NOTE: This file requires a Widget Extension target in Xcode.
//  To set up: File > New > Target > Widget Extension > Name: "NekkoWidget"
//  Then replace the generated files with this code.
//

import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct NekkoTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> NekkoEntry {
        NekkoEntry(date: Date(), catState: .sleeping)
    }

    func getSnapshot(in context: Context, completion: @escaping (NekkoEntry) -> Void) {
        completion(NekkoEntry(date: Date(), catState: .playing))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NekkoEntry>) -> Void) {
        var entries: [NekkoEntry] = []
        let currentDate = Date()

        for hourOffset in 0..<6 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let state = CatState.allCases.randomElement() ?? .sleeping
            entries.append(NekkoEntry(date: entryDate, catState: state))
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

// MARK: - Entry

struct NekkoEntry: TimelineEntry {
    let date: Date
    let catState: CatState
}

// MARK: - Cat States

enum CatState: String, CaseIterable {
    case sleeping = "sleeping"
    case playing = "playing"
    case eating = "eating"
    case reading = "reading"
    case coding = "coding"
    case listening = "listening"

    var emoji: String {
        switch self {
        case .sleeping: "😴"
        case .playing: "🎮"
        case .eating: "🍙"
        case .reading: "📖"
        case .coding: "💻"
        case .listening: "🎧"
        }
    }

    var label: String {
        switch self {
        case .sleeping: "すやすや..."
        case .playing: "あそんでる！"
        case .eating: "もぐもぐ"
        case .reading: "読書中"
        case .coding: "コーディング中"
        case .listening: "音楽きいてる♪"
        }
    }

    var sfSymbol: String {
        switch self {
        case .sleeping: "moon.zzz.fill"
        case .playing: "gamecontroller.fill"
        case .eating: "fork.knife"
        case .reading: "book.fill"
        case .coding: "laptopcomputer"
        case .listening: "headphones"
        }
    }
}

// MARK: - Widget View

struct NekkoWidgetEntryView: View {
    var entry: NekkoEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    private var smallWidget: some View {
        VStack(spacing: 8) {
            // Placeholder for pixel art cat - replace with actual image
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.orange.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: "cat.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
            }

            Text(entry.catState.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.orange.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "cat.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Nekko")
                    .font(.headline)
                Text(entry.catState.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: entry.catState.sfSymbol)
                        .font(.caption)
                    Text(entry.catState.emoji)
                        .font(.caption)
                }
                .foregroundStyle(.orange)
            }

            Spacer()
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Configuration

struct NekkoWidget: Widget {
    let kind: String = "NekkoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NekkoTimelineProvider()) { entry in
            NekkoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Nekko")
        .description("ドット絵の猫が色んなことをしています")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    NekkoWidget()
} timeline: {
    NekkoEntry(date: .now, catState: .sleeping)
    NekkoEntry(date: .now, catState: .playing)
    NekkoEntry(date: .now, catState: .coding)
}
