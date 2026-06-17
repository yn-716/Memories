import SwiftUI

struct HistoryView: View {
    // TODO: SwiftData導入後は永続化された下書き件数に差し替える。
    private let draftCount = 0
    private let draftLimit = 100

    var body: some View {
        ZStack {
            MemoriesTheme.background.ignoresSafeArea()

            VStack(spacing: 14) {
                MemoriesGlassPanel {
                    HStack {
                        Text("下書き")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(MemoriesTheme.textMain)

                        Spacer()

                        Text("\(draftCount)/\(draftLimit)")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(MemoriesTheme.accentDeep)
                    }
                    .padding(16)
                }

                MemoriesGlassPanel {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(MemoriesTheme.accentDeep)
                            .frame(width: 48, height: 48)
                            .background(MemoriesTheme.subBackground.opacity(0.82))
                            .clipShape(Circle())

                        Text("下書きはまだありません")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(MemoriesTheme.textMain)
                    }
                    .padding(24)
                }
            }
            .padding(24)
        }
        .navigationTitle("下書き")
        .navigationBarTitleDisplayMode(.inline)
        // TODO: SwiftDataによる下書き保存はPhase 2以降で実装する。
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
