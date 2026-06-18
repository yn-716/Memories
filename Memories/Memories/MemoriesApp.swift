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
    @StateObject private var storeKitManager = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(storeKitManager)
                .environment(\.locale, Locale(identifier: appState.localeIdentifier))
                .task {
                    storeKitManager.configure(appState: appState)
                }
        }
    }
}
