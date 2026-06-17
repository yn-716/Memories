import SwiftUI
import UIKit

struct ExportView: View {
    let template: Template
    let editState: CardEditState
    let photoImage: UIImage?

    @State private var renderedImage: UIImage?
    @State private var statusMessage: String?

    var body: some View {
        VStack(spacing: 18) {
            if let renderedImage {
                Image(uiImage: renderedImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(MemoriesTheme.border.opacity(0.78), lineWidth: 1)
                    }
                    .shadow(color: MemoriesTheme.accentDeep.opacity(0.12), radius: 18, y: 10)
                    .padding(.horizontal, 22)
            } else {
                ProgressView()
                    .tint(MemoriesTheme.accentDeep)
            }

            MemoriesGlassPanel {
                VStack(spacing: 12) {
                    MemoriesPrimaryButton("写真に保存", systemImage: "square.and.arrow.down") {
                        statusMessage = "写真への保存は次のフェーズで実装します。"
                    }

                    MemoriesSecondaryButton("共有する", systemImage: "square.and.arrow.up") {
                        statusMessage = "共有は次のフェーズで実装します。"
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(MemoriesTheme.textSub)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 8)
        }
        .padding(.top, 20)
        .background(MemoriesTheme.background.ignoresSafeArea())
        .navigationTitle("保存")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            renderedImage = renderPreviewImage()
        }
        // TODO: 写真フォルダ保存と共有シート本実装をPhase 2以降で接続する。
    }

    private func renderPreviewImage() -> UIImage? {
        TemplateRenderer().render(
            configuration: TemplateRenderConfiguration(
                template: template,
                editState: editState,
                photoImage: photoImage
            )
        )
    }
}

#Preview {
    NavigationStack {
        ExportView(
            template: .previewPetLifelog,
            editState: Template.previewPetLifelog.previewEditState,
            photoImage: nil
        )
    }
}
