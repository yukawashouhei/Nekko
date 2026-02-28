//
//  NekkoApp.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import SwiftData
import SwiftUI

@main
struct NekkoApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: Recording.self)
    }
}
