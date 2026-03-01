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
    @State private var isTranslating = false
    @State private var showLanguagePicker = false
    @State private var targetLanguage: SupportedLanguage = .english

    enum DetailTab: String, CaseIterable {
        case transcription = "記録"
        case summary = "要約"
        case translation = "翻訳"
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
                        .foregroundStyle(.blue)
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
                case .translation:
                    translationContent
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Transcription Tab

    private var transcriptionContent: some View {
        Group {
            if let segments = recording.decodedSegments, !segments.isEmpty {
                diarizedTranscriptionView(segments: segments)
            } else if let final_ = recording.finalTranscription, !final_.isEmpty {
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
                        .tint(.blue)
                        .disabled(isRetrying)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)
            }
        }
    }

    private func diarizedTranscriptionView(segments: [TranscriptionSegmentData]) -> some View {
        let uniqueSpeakers = Set(segments.compactMap(\.speaker)).sorted()
        let speakerIndexMap = Dictionary(uniqueKeysWithValues: uniqueSpeakers.enumerated().map { ($1, $0) })
        let hasSpeakers = !uniqueSpeakers.isEmpty

        return VStack(alignment: .leading, spacing: 12) {
            ForEach(segments) { segment in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if hasSpeakers {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .foregroundStyle(speakerColor(segment.speaker, index: speakerIndexMap[segment.speaker ?? ""] ?? 0))

                            Text(segment.speakerLabel)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(speakerColor(segment.speaker, index: speakerIndexMap[segment.speaker ?? ""] ?? 0))
                        }

                        if !segment.timeRange.isEmpty {
                            Text(segment.timeRange)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Text(segment.text)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding(.leading, hasSpeakers ? 20 : 0)
                }
            }
        }
    }

    private func speakerColor(_ speaker: String?, index: Int) -> Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .teal, .indigo, .mint]
        return colors[index % colors.count]
    }

    // MARK: - Summary Tab

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
                        .tint(.blue)
                        .disabled(isRetrying)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)
            }
        }
    }

    // MARK: - Translation Tab

    private var translationContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("翻訳先:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("翻訳先", selection: $targetLanguage) {
                    ForEach(availableTranslationLanguages, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .tint(.blue)

                Spacer()

                Button {
                    performTranslation()
                } label: {
                    if isTranslating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("翻訳", systemImage: "globe")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(isTranslating || recording.displayTranscription.isEmpty)
            }

            if let translation = recording.translation, !translation.isEmpty {
                if let langCode = recording.translationLanguage,
                   let lang = SupportedLanguage(rawValue: langCode) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.caption)
                        Text(lang.displayName)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                Text(translation)
                    .font(.body)
                    .textSelection(.enabled)
            } else if isTranslating {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("翻訳中...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("翻訳先の言語を選択して「翻訳」を押してください")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)
            }
        }
    }

    private var availableTranslationLanguages: [SupportedLanguage] {
        SupportedLanguage.allCases.filter { $0.rawValue != recording.language }
    }

    // MARK: - Audio Player

    private var audioPlayerBar: some View {
        HStack(spacing: 16) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
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
        if let translation = recording.translation {
            text += "\n\n■ 翻訳\n\(translation)"
        }
        return text
    }

    private func copyToClipboard() {
        switch selectedTab {
        case .transcription:
            UIPasteboard.general.string = recording.displayTranscription
        case .summary:
            UIPasteboard.general.string = recording.summary ?? ""
        case .translation:
            UIPasteboard.general.string = recording.translation ?? ""
        }
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
                let result = try await BackendAPIService.shared.transcribeWithSegments(
                    audioFileURL: audioURL,
                    language: recording.language
                )
                recording.finalTranscription = result.text

                if let segments = result.segments, !segments.isEmpty {
                    let encoder = JSONEncoder()
                    if let segmentsData = try? encoder.encode(segments) {
                        recording.segments = String(data: segmentsData, encoding: .utf8)
                    }
                }

                let summary = try await BackendAPIService.shared.summarize(
                    text: result.text,
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

    private func performTranslation() {
        isTranslating = true
        Task {
            do {
                let text = recording.displayTranscription
                let translation = try await BackendAPIService.shared.translate(
                    text: text,
                    fromLanguage: recording.language,
                    toLanguage: targetLanguage.rawValue
                )
                recording.translation = translation
                recording.translationLanguage = targetLanguage.rawValue
            } catch {
                print("Translation failed: \(error)")
            }
            isTranslating = false
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
                r.finalTranscription = "えっと、今録音テスト中です。このテストの音声なので、実際には使われない音声です。"
                r.segments = """
                [{"speaker":"speaker_0","start":0.0,"end":5.5,"text":"えっと、今録音テスト中です。"},{"speaker":"speaker_1","start":5.5,"end":10.0,"text":"このテストの音声なので、実際には使われない音声です。"}]
                """
                return r
            }()
        )
    }
    .modelContainer(for: Recording.self, inMemory: true)
}
