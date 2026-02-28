//
//  RecordingViewModel.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import AVFoundation
import Foundation
import Speech
import SwiftData

@Observable
final class RecordingViewModel {
    var selectedLanguage: SupportedLanguage = .japanese
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var liveTranscription = ""
    var audioLevels: [Float] = []
    var errorMessage: String?
    var showError = false
    var permissionsGranted = false

    private var audioRecorder = AudioRecorderService()
    private var transcriptionService = LiveTranscriptionService()
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
        let micGranted = await LiveTranscriptionService.requestMicrophonePermission()
        let speechStatus = await LiveTranscriptionService.requestAuthorization()

        await MainActor.run {
            permissionsGranted = micGranted && speechStatus == .authorized
            if !permissionsGranted {
                errorMessage = "マイクと音声認識の権限が必要です。設定アプリから許可してください。"
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
            errorMessage = "今月の利用上限（700分）に達しました。プレミアムプランにアップグレードしてください。"
            showError = true
            return
        }

        liveTranscription = ""
        audioLevels = Array(repeating: 0, count: 60)
        recordingDuration = 0

        let fileName = "nekko_\(Int(Date().timeIntervalSince1970))"
        currentAudioFileName = fileName

        do {
            audioRecorder.onAudioBuffer = { [weak self] buffer in
                self?.transcriptionService.appendAudioBuffer(buffer)
            }

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

            transcriptionService.startTranscription(
                locale: selectedLanguage.sfSpeechLocale
            ) { [weak self] text in
                Task { @MainActor [weak self] in
                    self?.liveTranscription = text
                }
            }

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
        transcriptionService.stopTranscription()

        isRecording = false

        UsageTracker.shared.addUsage(seconds: result.duration)

        let title = generateTitle()
        let recording = Recording(
            title: title,
            language: selectedLanguage.rawValue,
            duration: result.duration,
            audioFileName: currentAudioFileName.map { "\($0).m4a" },
            liveTranscription: liveTranscription
        )

        modelContext.insert(recording)

        if NetworkMonitor.shared.isConnected {
            recording.isProcessing = true
            Task {
                await processWithMistral(recording: recording, modelContext: modelContext)
            }
        }

        liveTranscription = ""
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
