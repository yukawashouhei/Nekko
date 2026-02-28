//
//  SettingsView.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import SwiftUI

struct SettingsView: View {
    @State private var backendURL = BackendAPIService.shared.backendURL

    var body: some View {
        NavigationStack {
            List {
                usageSection
                serverSection
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
                    Text("\(UsageTracker.shared.usedMinutesThisMonth) / 700 分")
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
        } footer: {
            Text("無料プランでは1ヶ月あたり700分の録音が可能です。")
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
            .tint(.orange)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Server Section

    private var serverSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("バックエンドURL")
                    .font(.subheadline)
                TextField("http://localhost:8080", text: $backendURL)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: backendURL) { _, newValue in
                        BackendAPIService.shared.backendURL = newValue
                    }
            }
            .padding(.vertical, 4)
        } header: {
            Text("サーバー設定")
        } footer: {
            Text("Mistral API通信用のバックエンドサーバーのURLを設定します。")
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
                Text("AIモデル (文字起こし)")
                Spacer()
                Text("Voxtral Mini")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("AIモデル (要約)")
                Spacer()
                Text("Mistral Small")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://mistral.ai")!) {
                HStack {
                    Text("Powered by Mistral AI")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
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
