//
//  RecordDetailView.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import AVFoundation
import SwiftData
import SwiftUI

struct RecordDetailView: View {
    @Bindable var recording: Recording
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showShareSheet = false
    @State private var selectedTab: DetailTab = .transcription
    @State private var isRetrying = false

    enum DetailTab: String, CaseIterable {
        case transcription = "記録"
        case summary = "要約"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            Picker("表示", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            contentSection

            if recording.audioFileName != nil {
                audioPlayerBar
            }
        }
        .navigationTitle(recording.formattedDate)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                }

                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let language = SupportedLanguage(rawValue: recording.language) {
                    Label(language.displayName, systemImage: "globe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(recording.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if recording.isProcessing {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Mistral AIで処理中...")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var contentSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch selectedTab {
                case .transcription:
                    transcriptionContent
                case .summary:
                    summaryContent
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var transcriptionContent: some View {
        Group {
            if let final_ = recording.finalTranscription, !final_.isEmpty {
                Text(final_)
                    .font(.body)
                    .textSelection(.enabled)
            } else if recording.isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Mistral AIで文字起こし中...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.document")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("文字起こしデータがありません")
                        .foregroundStyle(.tertiary)
                        .italic()

                    if recording.audioFileName != nil && NetworkMonitor.shared.isConnected {
                        Button("文字起こしを実行") {
                            retryTranscription()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(isRetrying)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)
            }
        }
    }

    private var summaryContent: some View {
        Group {
            if let summary = recording.summary, !summary.isEmpty {
                Text(summary)
                    .font(.body)
                    .textSelection(.enabled)
            } else if recording.isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("要約を生成中...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.document")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("要約がありません")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)

                    if recording.finalTranscription != nil {
                        Button("要約を生成") {
                            retrySummarization()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(isRetrying)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)
            }
        }
    }

    private var audioPlayerBar: some View {
        HStack(spacing: 16) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading) {
                Text(recording.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private var shareText: String {
        var text = "【\(recording.title)】\n\n"
        if let summary = recording.summary {
            text += "■ 要約\n\(summary)\n\n"
        }
        text += "■ 文字起こし\n\(recording.displayTranscription)"
        return text
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = recording.displayTranscription
    }

    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.stop()
            isPlaying = false
        } else {
            guard let fileName = recording.audioFileName else { return }
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            )[0]
            let fileURL = documentsPath.appendingPathComponent(fileName)

            do {
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
                audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                audioPlayer?.play()
                isPlaying = true
            } catch {
                print("Playback error: \(error)")
            }
        }
    }

    private func retryTranscription() {
        guard let audioFileName = recording.audioFileName else { return }
        isRetrying = true
        recording.isProcessing = true
        Task {
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            )[0]
            let audioURL = documentsPath.appendingPathComponent(audioFileName)
            do {
                let transcription = try await BackendAPIService.shared.transcribe(
                    audioFileURL: audioURL,
                    language: recording.language
                )
                recording.finalTranscription = transcription

                let summary = try await BackendAPIService.shared.summarize(
                    text: transcription,
                    language: recording.language
                )
                recording.summary = summary
            } catch {
                print("Transcription retry failed: \(error)")
            }
            recording.isProcessing = false
            isRetrying = false
        }
    }

    private func retrySummarization() {
        isRetrying = true
        recording.isProcessing = true
        Task {
            do {
                let text = recording.displayTranscription
                let summary = try await BackendAPIService.shared.summarize(
                    text: text,
                    language: recording.language
                )
                recording.summary = summary
            } catch {
                print("Summarization failed: \(error)")
            }
            recording.isProcessing = false
            isRetrying = false
        }
    }
}

#Preview {
    NavigationStack {
        RecordDetailView(
            recording: {
                let r = Recording(
                    title: "2月 28日, 19:01",
                    language: "ja",
                    duration: 125,
                    audioFileName: nil
                )
                r.finalTranscription = "えっと、今録音テスト中です。このテストの音声なので、実際には使われない音声です。とねっこのテスト用に今録音しています。"
                return r
            }()
        )
    }
    .modelContainer(for: Recording.self, inMemory: true)
}
