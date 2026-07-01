//
//  ContentView.swift
//  Memories
//
//  Created by Nishimura Yo on 2026/06/16.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        HomeView()
    }
}

#Preview {
    ContentView()
        .environmentObject(MemoriesAppState())
        .environmentObject(StoreKitManager())
        .environmentObject(AnnouncementStore())
}
