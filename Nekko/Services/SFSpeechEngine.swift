//
//  SFSpeechEngine.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import AVFoundation
import Foundation
import Speech

/// SFSpeechRecognizer ベースの文字起こしエンジン。
/// Apple の約60秒制限を回避するため、50秒ごとにセグメント確定→新タスク開始を自動で行う。
final class SFSpeechEngine: TranscriptionEngine {

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var locale: Locale?
    private var onPartialResult: (@Sendable (String) -> Void)?
    private var restartTimer: Timer?

    private var accumulatedText = ""
    private var currentSegmentText = ""
    private var isRunning = false
    private var pendingBuffers: [AVAudioPCMBuffer] = []
    private var isRestarting = false

    private let segmentInterval: TimeInterval = 50

    func start(locale: Locale, onPartialResult: @escaping @Sendable (String) -> Void) {
        self.locale = locale
        self.onPartialResult = onPartialResult
        self.accumulatedText = ""
        self.currentSegmentText = ""
        self.isRunning = true

        speechRecognizer = SFSpeechRecognizer(locale: locale)

        guard let speechRecognizer, speechRecognizer.isAvailable else { return }

        startNewTask()
        scheduleRestartTimer()
    }

    func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        if isRestarting {
            pendingBuffers.append(buffer)
            return
        }
        recognitionRequest?.append(buffer)
    }

    @discardableResult
    func stop() async -> String {
        isRunning = false
        restartTimer?.invalidate()
        restartTimer = nil

        let finalSegment = await finalizeCurrentTask()
        let trimmed = finalSegment.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            if !accumulatedText.isEmpty { accumulatedText += " " }
            accumulatedText += trimmed
        }

        cleanup()
        return accumulatedText
    }

    // MARK: - Internal

    private func startNewTask() {
        guard let speechRecognizer, speechRecognizer.isAvailable else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        self.recognitionRequest = request
        self.currentSegmentText = ""

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self, self.isRunning else { return }

            if let result {
                self.currentSegmentText = result.bestTranscription.formattedString
                self.emitFullText()
            }

            if let error {
                print("[SFSpeechEngine] Recognition error: \(error.localizedDescription)")
                if self.isRunning && !self.isRestarting {
                    self.handleSegmentEnd()
                }
            }
        }
    }

    private func emitFullText() {
        var full = accumulatedText
        let segment = currentSegmentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !segment.isEmpty {
            if !full.isEmpty { full += " " }
            full += segment
        }
        onPartialResult?(full)
    }

    private func scheduleRestartTimer() {
        restartTimer?.invalidate()
        restartTimer = Timer.scheduledTimer(withTimeInterval: segmentInterval, repeats: true) { [weak self] _ in
            guard let self, self.isRunning else { return }
            self.handleSegmentEnd()
        }
    }

    /// 現在のセグメントを確定し、蓄積テキストに加え、新タスクを開始する
    private func handleSegmentEnd() {
        guard !isRestarting else { return }
        isRestarting = true

        let segment = currentSegmentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !segment.isEmpty {
            if !accumulatedText.isEmpty { accumulatedText += " " }
            accumulatedText += segment
        }
        currentSegmentText = ""

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        startNewTask()

        for buffer in pendingBuffers {
            recognitionRequest?.append(buffer)
        }
        pendingBuffers.removeAll()
        isRestarting = false

        scheduleRestartTimer()
    }

    private func finalizeCurrentTask() async -> String {
        guard recognitionRequest != nil else { return currentSegmentText }

        return await withCheckedContinuation { continuation in
            var didResume = false

            recognitionRequest?.endAudio()

            let timeout = DispatchWorkItem { [weak self] in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: self?.currentSegmentText ?? "")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: timeout)

            let existingTask = recognitionTask
            recognitionTask = nil

            if let task = existingTask {
                let capturedText = currentSegmentText
                task.finish()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    guard !didResume else { return }
                    didResume = true
                    timeout.cancel()
                    continuation.resume(returning: capturedText)
                }
            } else {
                timeout.cancel()
                if !didResume {
                    didResume = true
                    continuation.resume(returning: currentSegmentText)
                }
            }
        }
    }

    private func cleanup() {
        restartTimer?.invalidate()
        restartTimer = nil
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        speechRecognizer = nil
        locale = nil
        onPartialResult = nil
        pendingBuffers.removeAll()
    }
}
