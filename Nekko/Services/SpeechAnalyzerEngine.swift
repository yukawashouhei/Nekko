//
//  SpeechAnalyzerEngine.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//
//  iOS 26+ SpeechAnalyzer/SpeechTranscriber ベースの文字起こしエンジン。
//  時間制限なしで長時間の文字起こしが可能。
//

import AVFoundation
import Foundation
import Speech

@available(iOS 26, *)
final class SpeechAnalyzerEngine: TranscriptionEngine {

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var audioConverter: AVAudioConverter?
    private var bestFormat: AVAudioFormat?
    private var currentLocale: Locale?

    private var accumulatedText = ""
    private var currentPartialText = ""
    private var onPartialResult: (@Sendable (String) -> Void)?
    private var isRunning = false
    private var isSetupComplete = false
    private var pendingBuffers: [AVAudioPCMBuffer] = []

    /// セットアップ失敗時に呼ばれるコールバック（フォールバック用）
    var onSetupFailed: (() -> Void)?

    func start(locale: Locale, onPartialResult: @escaping @Sendable (String) -> Void) {
        self.onPartialResult = onPartialResult
        self.accumulatedText = ""
        self.currentPartialText = ""
        self.isRunning = true
        self.isSetupComplete = false
        self.pendingBuffers = []

        Task {
            do {
                try await setupAndStart(locale: locale)
                self.isSetupComplete = true
                flushPendingBuffers()
            } catch {
                print("[SpeechAnalyzerEngine] Setup failed: \(error.localizedDescription)")
                self.isRunning = false
                self.onSetupFailed?()
            }
        }
    }

    func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRunning else { return }

        if !isSetupComplete {
            pendingBuffers.append(buffer)
            return
        }

        feedBuffer(buffer)
    }

    @discardableResult
    func stop() async -> String {
        isRunning = false

        inputContinuation?.finish()
        inputContinuation = nil

        if let analyzer {
            try? await analyzer.finalize(through: nil)
        }

        resultsTask?.cancel()
        resultsTask = nil

        if let analyzer {
            await analyzer.cancelAndFinishNow()
        }

        if let currentLocale {
            await AssetInventory.release(reservedLocale: currentLocale)
        }

        let finalText = buildFullText()

        analyzer = nil
        transcriber = nil
        audioConverter = nil
        bestFormat = nil
        currentLocale = nil
        onPartialResult = nil
        pendingBuffers.removeAll()

        return finalText
    }

    // MARK: - Setup

    private func setupAndStart(locale: Locale) async throws {
        guard SpeechTranscriber.isAvailable else {
            throw SpeechAnalyzerError.notAvailable
        }

        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw SpeechAnalyzerError.localeNotSupported
        }

        self.currentLocale = supportedLocale

        let transcriber = SpeechTranscriber(
            locale: supportedLocale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        self.transcriber = transcriber

        try await ensureAssets(for: transcriber, locale: supportedLocale)

        let analyzer = SpeechAnalyzer(
            modules: [transcriber],
            options: .init(priority: .userInitiated, modelRetention: .processLifetime)
        )
        self.analyzer = analyzer

        self.bestFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

        startResultsCollection(transcriber: transcriber)

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputContinuation = continuation
        try await analyzer.start(inputSequence: stream)
    }

    private func ensureAssets(for transcriber: SpeechTranscriber, locale: Locale) async throws {
        let installed = await SpeechTranscriber.installedLocales
        let isInstalled = installed.contains { $0.identifier(.bcp47) == locale.identifier(.bcp47) }

        if !isInstalled {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
        }
    }

    private func startResultsCollection(transcriber: SpeechTranscriber) {
        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    guard let self, self.isRunning else { break }

                    let text = String(result.text.characters)

                    if result.isFinal {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            if !self.accumulatedText.isEmpty { self.accumulatedText += " " }
                            self.accumulatedText += trimmed
                        }
                        self.currentPartialText = ""
                    } else {
                        self.currentPartialText = text
                    }

                    self.emitFullText()
                }
            } catch {
                if !(error is CancellationError) {
                    print("[SpeechAnalyzerEngine] Results stream error: \(error)")
                }
            }
        }
    }

    // MARK: - Buffer Management

    private func flushPendingBuffers() {
        for buffer in pendingBuffers {
            feedBuffer(buffer)
        }
        pendingBuffers.removeAll()
    }

    private func feedBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let inputContinuation else { return }

        let format = bestFormat ?? buffer.format
        var convertedBuffer = buffer

        if buffer.format != format {
            do {
                convertedBuffer = try convertBuffer(buffer, to: format)
            } catch {
                print("[SpeechAnalyzerEngine] Buffer conversion failed: \(error)")
                return
            }
        }

        let input = AnalyzerInput(buffer: convertedBuffer)
        inputContinuation.yield(input)
    }

    // MARK: - Helpers

    private func emitFullText() {
        let full = buildFullText()
        onPartialResult?(full)
    }

    private func buildFullText() -> String {
        var full = accumulatedText
        let partial = currentPartialText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !partial.isEmpty {
            if !full.isEmpty { full += " " }
            full += partial
        }
        return full
    }

    private func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        guard inputFormat != format else { return buffer }

        if audioConverter == nil || audioConverter?.outputFormat != format {
            audioConverter = AVAudioConverter(from: inputFormat, to: format)
            audioConverter?.primeMethod = .none
        }

        guard let audioConverter else {
            throw SpeechAnalyzerError.audioConverterFailed
        }

        let sampleRateRatio = audioConverter.outputFormat.sampleRate / audioConverter.inputFormat.sampleRate
        let scaledInputFrameLength = Double(buffer.frameLength) * sampleRateRatio
        let frameCapacity = AVAudioFrameCount(scaledInputFrameLength.rounded(.up))

        guard let conversionBuffer = AVAudioPCMBuffer(
            pcmFormat: audioConverter.outputFormat,
            frameCapacity: frameCapacity
        ) else {
            throw SpeechAnalyzerError.audioConverterFailed
        }

        var nsError: NSError?
        var bufferProcessed = false

        let status = audioConverter.convert(to: conversionBuffer, error: &nsError) { _, inputStatusPointer in
            defer { bufferProcessed = true }
            inputStatusPointer.pointee = bufferProcessed ? .noDataNow : .haveData
            return bufferProcessed ? nil : buffer
        }

        guard status != .error else {
            throw SpeechAnalyzerError.audioConverterFailed
        }

        return conversionBuffer
    }
}

@available(iOS 26, *)
enum SpeechAnalyzerError: LocalizedError {
    case notAvailable
    case localeNotSupported
    case audioConverterFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable: "SpeechTranscriber is not available on this device"
        case .localeNotSupported: "The selected language is not supported"
        case .audioConverterFailed: "Failed to convert audio buffer"
        }
    }
}
