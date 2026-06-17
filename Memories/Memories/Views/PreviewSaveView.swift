import SwiftUI
import UIKit

struct PreviewSaveView: View {
    let template: Template
    let editState: CardEditState
    let photoImage: UIImage?
    let draftID: UUID?
    let onDraftSaved: (UUID) -> Void
    let onDraftDeleted: () -> Void
    let onFinishWithoutDraft: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: UIImage?
    @State private var isProcessing = false
    @State private var outputAlert: PreviewOutputAlert?
    @State private var shareItem: ShareImageItem?
    @State private var showExistingDraftDecision = false
    @State private var showNewDraftDecision = false
    @State private var currentDraftID: UUID?

    init(
        template: Template,
        editState: CardEditState,
        photoImage: UIImage?,
        draftID: UUID?,
        onDraftSaved: @escaping (UUID) -> Void = { _ in },
        onDraftDeleted: @escaping () -> Void = {},
        onFinishWithoutDraft: @escaping () -> Void = {}
    ) {
        self.template = template
        self.editState = editState
        self.photoImage = photoImage
        self.draftID = draftID
        self.onDraftSaved = onDraftSaved
        self.onDraftDeleted = onDraftDeleted
        self.onFinishWithoutDraft = onFinishWithoutDraft
        _currentDraftID = State(initialValue: draftID)
    }

    var body: some View {
        ZStack {
            MemoriesTheme.background.ignoresSafeArea()

            GeometryReader { geometry in
                VStack(spacing: 18) {
                    Spacer(minLength: 10)

                    previewImage(in: geometry.size)

                    actionPanel
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if isProcessing {
                processingOverlay
            }
        }
        .navigationTitle("プレビュー")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            renderIfNeeded()
        }
        .alert(item: $outputAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: alert.message.map(Text.init),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("保存が完了しました。", isPresented: $showExistingDraftDecision) {
            Button("下書きを削除", role: .destructive) {
                deleteCurrentDraft()
            }

            Button("下書きを残す") {
                Task {
                    await updateCurrentDraftAfterPhotoSave()
                }
            }

            Button("編集を続ける", role: .cancel) {}
        } message: {
            Text("この下書きを削除しますか？\n写真に保存した画像は残ります。")
        }
        .alert("保存が完了しました。", isPresented: $showNewDraftDecision) {
            Button("下書き保存") {
                Task {
                    await createDraftAfterPhotoSave()
                }
            }

            Button("残さず終了", role: .destructive) {
                dismiss()
                onFinishWithoutDraft()
            }

            Button("編集を続ける", role: .cancel) {}
        } message: {
            Text("この編集内容を下書きに残しますか？\n下書きを残さなくても、写真に保存した画像は残ります。")
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.image])
        }
    }

    @ViewBuilder
    private func previewImage(in screenSize: CGSize) -> some View {
        if let renderedImage {
            let imageAspectRatio = renderedImage.size.width / max(renderedImage.size.height, 1)
            let maxWidth = max(180, screenSize.width - 40)
            let maxHeight = max(240, screenSize.height * 0.68)
            let previewWidth = min(maxWidth, maxHeight * imageAspectRatio)
            let previewHeight = previewWidth / imageAspectRatio

            Image(uiImage: renderedImage)
                .resizable()
                .scaledToFit()
                .frame(width: previewWidth, height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MemoriesTheme.border.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: MemoriesTheme.accentDeep.opacity(0.13), radius: 24, y: 14)
                .padding(.horizontal, 20)
        } else {
            MemoriesGlassPanel {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(MemoriesTheme.accentDeep)

                    Text("プレビューを作成中...")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textSub)
                }
                .frame(maxWidth: .infinity)
                .frame(height: max(260, screenSize.height * 0.55))
                .padding(20)
            }
            .padding(.horizontal, 20)
        }
    }

    private var actionPanel: some View {
        MemoriesGlassPanel {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    MemoriesPrimaryButton("写真に保存", systemImage: "square.and.arrow.down") {
                        Task {
                            await saveToPhotoLibrary()
                        }
                    }
                    .disabled(renderedImage == nil || isProcessing)

                    MemoriesSecondaryButton("共有する", systemImage: "square.and.arrow.up") {
                        prepareShare()
                    }
                    .disabled(renderedImage == nil || isProcessing)
                }

                MemoriesSecondaryButton("編集に戻る", systemImage: "chevron.left") {
                    dismiss()
                }
            }
            .padding(14)
        }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()

            ProgressView("処理中...")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MemoriesTheme.textMain)
                .tint(MemoriesTheme.accentDeep)
                .padding(18)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(MemoriesTheme.border.opacity(0.78), lineWidth: 1)
                }
        }
    }

    private func renderIfNeeded() {
        guard renderedImage == nil else {
            return
        }

        renderedImage = renderFinalImage()
        if renderedImage == nil {
            outputAlert = PreviewOutputAlert(title: "プレビューを作成できませんでした", message: "画像の生成に失敗しました。")
        }
    }

    @MainActor
    private func saveToPhotoLibrary() async {
        guard let image = preparedImage() else {
            outputAlert = PreviewOutputAlert(title: "保存できませんでした", message: "画像の生成に失敗しました。")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await PhotoLibrarySaver().save(image)
            if currentDraftID != nil {
                showExistingDraftDecision = true
            } else {
                showNewDraftDecision = true
            }
        } catch {
            outputAlert = PreviewOutputAlert(title: "保存できませんでした", message: error.localizedDescription)
        }
    }

    private func prepareShare() {
        guard let image = preparedImage() else {
            outputAlert = PreviewOutputAlert(title: "共有できませんでした", message: "画像の生成に失敗しました。")
            return
        }

        shareItem = ShareImageItem(image: image)
    }

    private func preparedImage() -> UIImage? {
        if let renderedImage {
            return renderedImage
        }

        let image = renderFinalImage()
        renderedImage = image
        return image
    }

    private func renderFinalImage() -> UIImage? {
        TemplateRenderer().render(
            configuration: TemplateRenderConfiguration(
                template: template,
                editState: editState,
                photoImage: photoImage,
                watermarkMode: .visible
            )
        )
    }

    private func deleteCurrentDraft() {
        guard let currentDraftID else {
            return
        }

        do {
            try DraftRepository.shared.deleteDraft(id: currentDraftID)
            self.currentDraftID = nil
            dismiss()
            onDraftDeleted()
        } catch {
            outputAlert = PreviewOutputAlert(title: "下書きを削除できませんでした", message: error.localizedDescription)
        }
    }

    @MainActor
    private func updateCurrentDraftAfterPhotoSave() async {
        guard let currentDraftID else {
            return
        }

        await saveDraftAfterPhotoSave(existingDraftID: currentDraftID)
    }

    @MainActor
    private func createDraftAfterPhotoSave() async {
        await saveDraftAfterPhotoSave(existingDraftID: nil)
    }

    @MainActor
    private func saveDraftAfterPhotoSave(existingDraftID: UUID?) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            let record = try DraftRepository.shared.save(
                template: template,
                editState: editState,
                photoImage: photoImage,
                existingDraftID: existingDraftID
            )
            currentDraftID = record.id
            onDraftSaved(record.id)
            outputAlert = PreviewOutputAlert(title: "下書きに保存しました", message: nil)
        } catch {
            outputAlert = PreviewOutputAlert(title: "下書き保存できませんでした", message: error.localizedDescription)
        }
    }
}

private struct PreviewOutputAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
}

#Preview {
    NavigationStack {
        PreviewSaveView(
            template: .previewPetLifelog,
            editState: Template.previewPetLifelog.previewEditState,
            photoImage: nil,
            draftID: nil
        )
    }
}
