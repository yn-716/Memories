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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = MemoriesAppState()
    @StateObject private var storeKitManager = StoreKitManager()
    @StateObject private var announcementStore = AnnouncementStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(storeKitManager)
                .environmentObject(announcementStore)
                .environment(\.locale, Locale(identifier: appState.localeIdentifier))
                .task {
                    _ = try? MediaFileManager.shared.cleanupTemporaryFiles()
                    DraftRepository.shared.cleanupOrphanedFiles()
                    storeKitManager.configure(appState: appState)
                    await storeKitManager.ensureFreshEntitlements()
                    await announcementStore.refreshIfNeeded()
                    refreshPetCalendarWidgetSnapshot()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else {
                        return
                    }
                    Task {
                        _ = try? MediaFileManager.shared.cleanupTemporaryFiles()
                        await announcementStore.refreshIfNeeded()
                    }
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
