//
//  RecordsListView.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import SwiftData
import SwiftUI

struct RecordsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]
    @State private var searchText = ""

    private var filteredRecordings: [Recording] {
        if searchText.isEmpty { return recordings }
        return recordings.filter {
            $0.displayTranscription.localizedCaseInsensitiveContains(searchText)
                || $0.title.localizedCaseInsensitiveContains(searchText)
                || ($0.summary ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if recordings.isEmpty {
                    emptyState
                } else {
                    recordingsList
                }
            }
            .navigationTitle("記録")
            .searchable(text: $searchText, prompt: "録音を検索")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("録音がありません", systemImage: "waveform")
        } description: {
            Text("録音タブから音声を録音すると、ここに表示されます。")
        }
    }

    private var recordingsList: some View {
        List {
            ForEach(filteredRecordings) { recording in
                NavigationLink(destination: RecordDetailView(recording: recording)) {
                    RecordingRowView(recording: recording)
                }
            }
            .onDelete(perform: deleteRecordings)
        }
        .listStyle(.plain)
    }

    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = filteredRecordings[index]
            if let fileName = recording.audioFileName {
                let documentsPath = FileManager.default.urls(
                    for: .documentDirectory, in: .userDomainMask
                )[0]
                let fileURL = documentsPath.appendingPathComponent(fileName)
                try? FileManager.default.removeItem(at: fileURL)
            }
            modelContext.delete(recording)
        }
    }
}

// MARK: - Row View

struct RecordingRowView: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(recording.formattedDate)
                    .font(.headline)
                Spacer()
                Text(recording.durationLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(recording.displayTranscription.prefix(100) + (recording.displayTranscription.count > 100 ? "..." : ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                if let language = SupportedLanguage(rawValue: recording.language) {
                    Label(language.displayName, systemImage: "globe")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if recording.isProcessing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("処理中...")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                } else if recording.finalTranscription != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RecordsListView()
        .modelContainer(for: Recording.self, inMemory: true)
}
