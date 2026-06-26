//
//  MemoriesApp.swift
//  Memories
//
//  Created by Nishimura Yo on 2026/06/16.
//

import SwiftUI

#if canImport(WidgetKit)
import WidgetKit
#endif

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
                    await storeKitManager.ensureFreshEntitlements()
                    refreshPetCalendarWidgetSnapshot()
                }
        }
    }

    @MainActor
    private func refreshPetCalendarWidgetSnapshot() {
        guard let repository = try? PetCalendarRepository() else {
            return
        }

        try? repository.writeWidgetSnapshot(
            selectedMonth: Date(),
            displayLanguage: appState.petCalendarDisplayLanguage,
            showsBranding: !appState.watermarkPolicy().snapshot.hasUnlimitedAccess
        )
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "MemoriesWidget")
        #endif
    }
}
