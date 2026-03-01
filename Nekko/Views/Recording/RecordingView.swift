//
//  RecordingView.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import SwiftData
import SwiftUI

struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = RecordingViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if viewModel.isRecording {
                        recordingHeader
                    }

                    AudioWaveformView(levels: viewModel.audioLevels)
                        .frame(height: 80)
                        .padding(.horizontal)
                        .padding(.top, viewModel.isRecording ? 8 : 40)

                    transcriptionArea

                    Spacer()

                    controlsArea
                }
            }
            .navigationTitle("Nekko")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.checkPermissions()
            }
            .alert(
                "エラー",
                isPresented: $viewModel.showError
            ) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var recordingHeader: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .opacity(animatingDot ? 1 : 0.3)

                Text("録音中")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(viewModel.formattedDuration)
                .font(.system(.title, design: .monospaced, weight: .medium))
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.1), value: viewModel.formattedDuration)
        }
        .padding(.top, 8)
    }

    @State private var animatingDot = true

    private var transcriptionArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if viewModel.isRecording {
                        realtimeTranscriptionContent
                            .onChange(of: viewModel.liveTranscription) {
                                withAnimation {
                                    proxy.scrollTo("bottom", anchor: .bottom)
                                }
                            }
                    } else {
                        idleContent
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)

                Color.clear
                    .frame(height: 1)
                    .id("bottom")
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
                animatingDot.toggle()
            }
        }
    }

    private var realtimeTranscriptionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.liveTranscription.isEmpty {
                HStack(spacing: 8) {
                    if viewModel.isRealtimeConnected {
                        ProgressView()
                            .controlSize(.small)
                        Text("音声を認識中...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                        Text("Mistral AIに接続中...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)
            } else {
                Text(viewModel.liveTranscription)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var idleContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            if viewModel.hasAPIKey {
                Text("録音ボタンを押して開始")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                Text("設定タブでAPIキーを入力してから\n録音を開始してください")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }

    private var controlsArea: some View {
        VStack(spacing: 20) {
            LanguagePickerView(selectedLanguage: $viewModel.selectedLanguage)
                .disabled(viewModel.isRecording)

            recordButton
                .padding(.bottom, 16)
        }
        .padding(.horizontal)
    }

    private var recordButton: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                viewModel.toggleRecording(modelContext: modelContext)
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)

                if viewModel.isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.red)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: 64, height: 64)
                }
            }
        }
        .sensoryFeedback(.impact, trigger: viewModel.isRecording)
        .disabled(!viewModel.permissionsGranted)
        .opacity(viewModel.permissionsGranted ? 1 : 0.5)
    }
}

#Preview {
    RecordingView()
        .modelContainer(for: Recording.self, inMemory: true)
}
