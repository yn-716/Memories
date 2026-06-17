import SwiftUI

struct SettingsView: View {
    @State private var showDebugResetAlert = false
    #if DEBUG
    @State private var debugRemainingFreeExports = DailyWatermarkFreeExportStore.shared.remainingExports()
    #endif

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

            #if DEBUG
            Section("DEBUG") {
                VStack(alignment: .leading, spacing: 8) {
                    Button("透かしなし無料枠をリセット") {
                        DailyWatermarkFreeExportStore.shared.resetTodayUsage()
                        debugRemainingFreeExports = DailyWatermarkFreeExportStore.shared.remainingExports()
                        showDebugResetAlert = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.accentDeep)

                    Text(debugFreeExportStatusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textMain)

                    Text("本日の無料分を未使用状態に戻します。Releaseビルドには表示されません。")
                        .font(.caption)
                        .foregroundStyle(MemoriesTheme.textSub)
                }
                .padding(.vertical, 4)
                .onAppear {
                    debugRemainingFreeExports = DailyWatermarkFreeExportStore.shared.remainingExports()
                }
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(MemoriesTheme.background.ignoresSafeArea())
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .alert("透かしなし無料枠をリセットしました", isPresented: $showDebugResetAlert) {
            Button("OK", role: .cancel) {}
        }
        // TODO: 課金、CloudKit、詳細設定はPhase 2以降で実装する。
    }

    #if DEBUG
    private var debugFreeExportStatusText: String {
        if debugRemainingFreeExports > 0 {
            return "現在: 本日あと\(debugRemainingFreeExports)回"
        }

        return "現在: 本日分を使用済み"
    }
    #endif
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
