//
//  AudioWaveformView.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import SwiftUI

struct AudioWaveformView: View {
    let levels: [Float]
    private let barCount = 60

    var body: some View {
        Canvas { context, size in
            let barWidth = size.width / CGFloat(barCount)
            let gap: CGFloat = 1.5
            let maxHeight = size.height * 0.9
            let midY = size.height / 2

            let displayLevels: [Float]
            if levels.count >= barCount {
                displayLevels = Array(levels.suffix(barCount))
            } else {
                displayLevels =
                    Array(repeating: Float(0), count: barCount - levels.count)
                    + levels
            }

            for (index, level) in displayLevels.enumerated() {
                let height = max(2, CGFloat(level) * maxHeight)
                let x = CGFloat(index) * barWidth + gap / 2
                let rect = CGRect(
                    x: x,
                    y: midY - height / 2,
                    width: max(1, barWidth - gap),
                    height: height
                )
                let path = Path(roundedRect: rect, cornerRadius: 1)
                let opacity = 0.3 + Double(level) * 0.7
                context.fill(
                    path,
                    with: .color(.orange.opacity(opacity))
                )
            }
        }
    }
}

#Preview {
    AudioWaveformView(
        levels: (0..<60).map { _ in Float.random(in: 0...1) }
    )
    .frame(height: 80)
    .padding()
    .background(.black)
}
