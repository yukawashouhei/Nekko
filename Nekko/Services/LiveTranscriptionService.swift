//
//  LiveTranscriptionService.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import AVFoundation
import Foundation
import Speech

// MARK: - Transcription Engine Protocol

protocol TranscriptionEngine: AnyObject {
    func start(locale: Locale, onPartialResult: @escaping @Sendable (String) -> Void)
    func appendBuffer(_ buffer: AVAudioPCMBuffer)
    func stop() async -> String
}

// MARK: - LiveTranscriptionService

/// 文字起こしエンジンの優先度切り替えとライフサイクルを管理する。
/// 優先度: iOS 26 SpeechAnalyzer (デバイスが対応していれば) > SFSpeechRecognizer
final class LiveTranscriptionService {

    private var engine: TranscriptionEngine?
    private var storedLocale: Locale?
    private var storedOnPartialResult: (@Sendable (String) -> Void)?

    static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    static func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    /// 最適なエンジンを選択して文字起こしを開始する
    func startTranscription(
        locale: Locale,
        onPartialResult: @escaping @Sendable (String) -> Void
    ) {
        stopTranscription()

        storedLocale = locale
        storedOnPartialResult = onPartialResult

        if #available(iOS 26, *) {
            let analyzerEngine = SpeechAnalyzerEngine()
            analyzerEngine.onSetupFailed = { [weak self] in
                print("[LiveTranscriptionService] SpeechAnalyzer unavailable, falling back to SFSpeechRecognizer")
                self?.fallbackToSFSpeech()
            }
            engine = analyzerEngine
            engine?.start(locale: locale, onPartialResult: onPartialResult)
        } else {
            engine = SFSpeechEngine()
            engine?.start(locale: locale, onPartialResult: onPartialResult)
        }
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        engine?.appendBuffer(buffer)
    }

    /// 文字起こしを停止（fire-and-forget）
    func stopTranscription() {
        let currentEngine = engine
        engine = nil
        storedLocale = nil
        storedOnPartialResult = nil
        if let currentEngine {
            Task { @MainActor in
                await currentEngine.stop()
            }
        }
    }

    /// 停止して最終テキストを非同期で取得する
    func stopAndGetFinalText() async -> String {
        guard let engine else { return "" }
        let text = await engine.stop()
        self.engine = nil
        self.storedLocale = nil
        self.storedOnPartialResult = nil
        return text
    }

    // MARK: - Fallback

    private func fallbackToSFSpeech() {
        guard let locale = storedLocale, let callback = storedOnPartialResult else { return }

        let sfEngine = SFSpeechEngine()
        engine = sfEngine
        sfEngine.start(locale: locale, onPartialResult: callback)
    }
}
