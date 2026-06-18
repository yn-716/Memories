//
//  MemoriesApp.swift
//  Memories
//
//  Created by Nishimura Yo on 2026/06/16.
//

import SwiftUI

@main
struct MemoriesApp: App {
    @StateObject private var appState = MemoriesAppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environment(\.locale, Locale(identifier: appState.localeIdentifier))
        }
    }
}
