//
//  MainTabView.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import SwiftData
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("録音", systemImage: "mic.fill") {
                RecordingView()
            }

            Tab("記録", systemImage: "doc.text.fill") {
                RecordsListView()
            }

            Tab("設定", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tint(.orange)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: Recording.self, inMemory: true)
}
