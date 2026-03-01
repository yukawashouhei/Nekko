//
//  RecordingViewModel.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import AVFoundation
import Foundation
import SwiftData

@Observable
final class RecordingViewModel {
    var selectedLanguage: SupportedLanguage = .japanese
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var audioLevels: [Float] = []
    var errorMessage: String?
    var showError = false
    var permissionsGranted = false
    var liveTranscription: String { realtimeService.transcription }
    var isRealtimeConnected: Bool { realtimeService.isConnected }

    private var audioRecorder = AudioRecorderService()
    private let realtimeService = MistralRealtimeService()
    private var displayTimer: Timer?
    private var currentAudioFileName: String?
    private var currentAudioURL: URL?

    var formattedDuration: String {
        let hours = Int(recordingDuration) / 3600
        let minutes = (Int(recordingDuration) % 3600) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var hasAPIKey: Bool {
        realtimeService.hasAPIKey
    }

    func checkPermissions() async {
        let micGranted = await AVAudioApplication.requestRecordPermission()

        await MainActor.run {
            permissionsGranted = micGranted
            if !permissionsGranted {
                errorMessage = "マイクの権限が必要です。設定アプリから許可してください。"
                showError = true
            }
        }
    }

    func toggleRecording(modelContext: ModelContext) {
        if isRecording {
            stopRecording(modelContext: modelContext)
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard !UsageTracker.shared.isLimitReached else {
            errorMessage = "今月の利用上限（600分）に達しました。プレミアムプランにアップグレードしてください。"
            showError = true
            return
        }

        guard realtimeService.hasAPIKey else {
            errorMessage = "Mistral APIキーが設定されていません。設定タブから入力してください。"
            showError = true
            return
        }

        audioLevels = Array(repeating: 0, count: 60)
        recordingDuration = 0

        let fileName = "nekko_\(Int(Date().timeIntervalSince1970))"
        currentAudioFileName = fileName
        let language = selectedLanguage.rawValue

        Task {
            await realtimeService.start(language: language)

            if let realtimeError = realtimeService.error {
                await MainActor.run {
                    errorMessage = realtimeError
                    showError = true
                }
                return
            }

            await MainActor.run {
                do {
                    self.audioRecorder.onAudioLevelUpdate = { [weak self] level in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.audioLevels.append(level)
                            if self.audioLevels.count > 60 {
                                self.audioLevels.removeFirst()
                            }
                        }
                    }

                    self.audioRecorder.onAudioBuffer = { [weak self] buffer in
                        self?.realtimeService.processAudioBuffer(buffer)
                    }

                    let audioURL = try self.audioRecorder.startRecording(fileName: fileName)
                    self.currentAudioURL = audioURL
                    self.isRecording = true

                    self.displayTimer = Timer.scheduledTimer(
                        withTimeInterval: 0.1, repeats: true
                    ) { [weak self] _ in
                        guard let self else { return }
                        self.recordingDuration = self.audioRecorder.elapsedTime
                    }
                } catch {
                    self.errorMessage = "録音を開始できませんでした: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }

    private func stopRecording(modelContext: ModelContext) {
        displayTimer?.invalidate()
        displayTimer = nil

        let result = audioRecorder.stopRecording()
        let duration = result.duration
        let fileName = currentAudioFileName.map { "\($0).m4a" }
        let language = selectedLanguage.rawValue
        let realtimeText = realtimeService.transcription

        isRecording = false

        Task {
            await realtimeService.stop()
        }

        UsageTracker.shared.addUsage(seconds: duration)

        let title = generateTitle()
        let recording = Recording(
            title: title,
            language: language,
            duration: duration,
            audioFileName: fileName,
            liveTranscription: realtimeText
        )

        modelContext.insert(recording)

        if NetworkMonitor.shared.isConnected {
            recording.isProcessing = true
            Task {
                await processWithMistral(recording: recording, modelContext: modelContext)
            }
        }

        audioLevels = Array(repeating: 0, count: 60)
    }

    private func generateTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月 d日, HH:mm"
        return formatter.string(from: Date())
    }

    @MainActor
    private func processWithMistral(recording: Recording, modelContext: ModelContext) async {
        guard let audioFileName = recording.audioFileName else {
            recording.isProcessing = false
            return
        }

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
            print("Mistral processing failed: \(error.localizedDescription)")
        }

        recording.isProcessing = false
    }
}
