import SwiftUI

struct PhotoInputView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)

            RoundedRectangle(cornerRadius: MemoriesTheme.cardRadius)
                .fill(MemoriesTheme.subBackground)
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 44, weight: .regular))
                            .foregroundStyle(MemoriesTheme.accentDeep)
                        Text("写真")
                            .font(.headline)
                            .foregroundStyle(MemoriesTheme.textMain)
                        Text("ペット写真を1枚選ぶ")
                            .font(.subheadline)
                            .foregroundStyle(MemoriesTheme.textSub)
                    }
                }
                .frame(maxWidth: 320)
                .aspectRatio(0.78, contentMode: .fit)
                .overlay {
                    RoundedRectangle(cornerRadius: MemoriesTheme.cardRadius)
                        .stroke(MemoriesTheme.border, lineWidth: 1)
                }

            MemoriesGlassPanel {
                VStack(spacing: 8) {
                    Text("ホームの「写真を選ぶ」から写真ライブラリを開けます。")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MemoriesTheme.textSub)
                        .multilineTextAlignment(.center)
                        .padding(16)
                }
            }

            Spacer()
        }
        .padding(24)
        .background(MemoriesTheme.background.ignoresSafeArea())
        .navigationTitle("写真を選ぶ")
        .navigationBarTitleDisplayMode(.inline)
        // TODO: PhotosPickerで写真ライブラリ選択をPhase 2以降で接続する。
    }
}

#Preview {
    NavigationStack {
        PhotoInputView()
    }
}
