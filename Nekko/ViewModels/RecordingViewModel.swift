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

    private var audioRecorder = AudioRecorderService()
    private var displayTimer: Timer?
    private var currentAudioFileName: String?
    private var currentAudioURL: URL?

    var formattedDuration: String {
        let hours = Int(recordingDuration) / 3600
        let minutes = (Int(recordingDuration) % 3600) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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

        audioLevels = Array(repeating: 0, count: 60)
        recordingDuration = 0

        let fileName = "nekko_\(Int(Date().timeIntervalSince1970))"
        currentAudioFileName = fileName

        do {
            audioRecorder.onAudioLevelUpdate = { [weak self] level in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.audioLevels.append(level)
                    if self.audioLevels.count > 60 {
                        self.audioLevels.removeFirst()
                    }
                }
            }

            let audioURL = try audioRecorder.startRecording(fileName: fileName)
            currentAudioURL = audioURL

            isRecording = true

            displayTimer = Timer.scheduledTimer(
                withTimeInterval: 0.1, repeats: true
            ) { [weak self] _ in
                guard let self else { return }
                self.recordingDuration = self.audioRecorder.elapsedTime
            }
        } catch {
            errorMessage = "録音を開始できませんでした: \(error.localizedDescription)"
            showError = true
        }
    }

    private func stopRecording(modelContext: ModelContext) {
        displayTimer?.invalidate()
        displayTimer = nil

        let result = audioRecorder.stopRecording()
        let duration = result.duration
        let fileName = currentAudioFileName.map { "\($0).m4a" }
        let language = selectedLanguage.rawValue

        isRecording = false

        UsageTracker.shared.addUsage(seconds: duration)

        let title = generateTitle()
        let recording = Recording(
            title: title,
            language: language,
            duration: duration,
            audioFileName: fileName
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
            print("Mistral processing failed: \(error.localizedDescription)")
        }

        recording.isProcessing = false
    }
}
