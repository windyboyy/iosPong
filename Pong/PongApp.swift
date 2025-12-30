//
//  PongApp.swift
//  Pong
//
//  Created by 张金琛 on 2025/12/12.
//

import SwiftUI

@main
struct PongApp: App {
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageManager)
        }
    }
}
