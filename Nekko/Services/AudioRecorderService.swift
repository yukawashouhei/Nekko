//
//  AudioRecorderService.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import AVFoundation
import Foundation

final class AudioRecorderService {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private(set) var isRecording = false
    private var audioFileURL: URL?
    private var recordingStartTime: Date?

    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    var onAudioLevelUpdate: ((Float) -> Void)?

    var elapsedTime: TimeInterval {
        guard let start = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    func startRecording(fileName: String) throws -> URL {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        let documentsPath = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        )[0]
        let audioURL = documentsPath.appendingPathComponent("\(fileName).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: recordingFormat.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        audioFile = try AVAudioFile(forWriting: audioURL, settings: settings)
        audioFileURL = audioURL

        inputNode.installTap(
            onBus: 0, bufferSize: 1024, format: recordingFormat
        ) { [weak self] buffer, _ in
            guard let self else { return }

            try? self.audioFile?.write(from: buffer)

            let level = Self.calculateLevel(buffer: buffer)
            self.onAudioLevelUpdate?(level)
            self.onAudioBuffer?(buffer)
        }

        engine.prepare()
        try engine.start()

        self.audioEngine = engine
        isRecording = true
        recordingStartTime = Date()

        return audioURL
    }

    func stopRecording() -> (url: URL?, duration: TimeInterval) {
        let duration = elapsedTime

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        isRecording = false
        recordingStartTime = nil

        try? AVAudioSession.sharedInstance().setActive(false)

        return (audioFileURL, duration)
    }

    private static func calculateLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }

        var sum: Float = 0
        for i in 0..<frames {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(frames))
        let db = 20 * log10(max(rms, 1e-6))
        return max(0, min(1, (db + 60) / 60))
    }
}
