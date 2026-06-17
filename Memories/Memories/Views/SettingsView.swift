import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text("1.0")
                        .foregroundStyle(MemoriesTheme.textSub)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MemoriesTheme.background.ignoresSafeArea())
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        // TODO: 課金、CloudKit、詳細設定はPhase 2以降で実装する。
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
