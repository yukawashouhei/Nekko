//
//  SettingsView.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("nekko_mistral_api_key") private var apiKey = ""
    @AppStorage("nekko_backend_url") private var backendURL = "http://localhost:8080"
    @State private var isAPIKeyVisible = false

    var body: some View {
        NavigationStack {
            List {
                usageSection
                mistralSection
                backendSection
                aboutSection
            }
            .navigationTitle("設定")
        }
    }

    // MARK: - Usage Section

    private var usageSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("今月の使用量")
                        .font(.headline)
                    Spacer()
                    Text("\(UsageTracker.shared.usedMinutesThisMonth) / 600 分")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: UsageTracker.shared.usageRatio)
                    .tint(progressColor)

                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text("残り \(UsageTracker.shared.remainingMinutes) 分")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            if UsageTracker.shared.usageRatio > 0.8 {
                premiumBanner
            }
        } header: {
            Text("利用状況")
        }
    }

    private var progressColor: Color {
        let ratio = UsageTracker.shared.usageRatio
        if ratio > 0.9 { return .red }
        if ratio > 0.7 { return .orange }
        return .green
    }

    private var premiumBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nekko Premium")
                    .font(.subheadline.weight(.semibold))
                Text("無制限に録音・文字起こし")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("アップグレード") {
                // Placeholder
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Mistral API Section

    private var mistralSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mistral API キー")
                    .font(.subheadline)

                HStack {
                    if isAPIKeyVisible {
                        TextField("sk-...", text: $apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("sk-...", text: $apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    Button {
                        isAPIKeyVisible.toggle()
                    } label: {
                        Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)

            HStack(spacing: 6) {
                Image(systemName: apiKey.isEmpty ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(apiKey.isEmpty ? .red : .green)
                    .font(.caption)

                Text(apiKey.isEmpty ? "APIキーが未設定です" : "APIキーが設定済みです")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Mistral AI")
        } footer: {
            Text("リアルタイム文字起こしに使用されるAPIキーです。Mistral AIのダッシュボードから取得できます。")
        }
    }

    // MARK: - Backend Section

    private var backendSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("バックエンドURL")
                    .font(.subheadline)

                TextField("http://localhost:8080", text: $backendURL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .font(.system(.body, design: .monospaced))
            }
            .padding(.vertical, 4)
        } header: {
            Text("サーバー設定")
        } footer: {
            Text("バッチ文字起こし・要約・翻訳に使用するNekkoBackendサーバーのURLです。実機で使用する場合は、同じネットワーク上のMacのIPアドレスに変更してください。")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("バージョン")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("AIモデル (リアルタイム)")
                Spacer()
                Text("Voxtral Mini Realtime")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("AIモデル (文字起こし)")
                Spacer()
                Text("Voxtral Mini")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("AIモデル (要約・翻訳)")
                Spacer()
                Text("Mistral Small")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://mistral.ai")!) {
                HStack {
                    Text("Powered by Mistral AI")
                        .foregroundStyle(.blue)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        } header: {
            Text("Nekko について")
        }
    }
}

#Preview {
    SettingsView()
}
