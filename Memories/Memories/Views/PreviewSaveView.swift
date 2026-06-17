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
    @State private var watermarkOption: WatermarkExportOption = .withWatermark
    @State private var entitlementState: EntitlementState = .free
    @State private var showWatermarklessShareConfirmation = false

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
                let bottomPadding = max(14, geometry.safeAreaInsets.bottom + 8)

                VStack(spacing: 12) {
                    Spacer(minLength: 4)

                    previewImage(in: geometry.size)

                    actionPanel
                        .padding(.horizontal, 20)
                        .padding(.bottom, bottomPadding)
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
        .onChange(of: watermarkOption) { _, _ in
            renderedImage = nil
            renderIfNeeded()
        }
        .alert(item: $outputAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: alert.message.map(Text.init),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("透かしなしで共有しますか？", isPresented: $showWatermarklessShareConfirmation) {
            Button("共有する") {
                openShareSheet(consumesFreeWatermarkAllowance: true)
            }

            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("本日の無料分を使用します。")
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
            ShareSheet(items: [item.image]) { completed, error in
                handleShareCompletion(for: item, completed: completed, error: error)
            }
        }
    }

    @ViewBuilder
    private func previewImage(in screenSize: CGSize) -> some View {
        if let renderedImage {
            let imageAspectRatio = renderedImage.size.width / max(renderedImage.size.height, 1)
            let maxWidth = max(180, screenSize.width - 40)
            let reservedPanelHeight: CGFloat = 318
            let maxHeight = max(240, min(screenSize.height * 0.58, screenSize.height - reservedPanelHeight))
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
                watermarkPicker

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
            .padding(12)
        }
    }

    private var watermarkPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ウォーターマーク")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textSub)

                Spacer()

                Text(watermarkStatusText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textSub)
            }

            HStack(spacing: 8) {
                WatermarkOptionButton(
                    title: "あり",
                    subtitle: "無制限",
                    systemImage: "checkmark.seal",
                    isSelected: watermarkOption == .withWatermark,
                    isEnabled: true
                ) {
                    selectWatermarkOption(.withWatermark)
                }

                WatermarkOptionButton(
                    title: "なし",
                    subtitle: watermarkAccessSnapshot.withoutWatermarkStatusText,
                    systemImage: "seal",
                    isSelected: watermarkOption == .withoutWatermark,
                    isEnabled: watermarkAccessSnapshot.canExportWithoutWatermark
                ) {
                    selectWatermarkOption(.withoutWatermark)
                }
            }
        }
        .padding(12)
        .background(MemoriesTheme.card.opacity(0.48))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(MemoriesTheme.border.opacity(0.72), lineWidth: 1)
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
        guard ensureCanExportSelectedWatermark() else {
            return
        }

        guard let image = preparedImage() else {
            outputAlert = PreviewOutputAlert(title: "保存できませんでした", message: "画像の生成に失敗しました。")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await PhotoLibrarySaver().save(image)
            guard consumeWatermarkAllowanceIfNeeded() else {
                outputAlert = PreviewOutputAlert(title: "保存しました", message: "ウォーターマークなしの本日分は使用済みです。")
                return
            }

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
        guard ensureCanExportSelectedWatermark() else {
            return
        }

        if shouldConsumeFreeWatermarkAllowance(for: watermarkOption) {
            showWatermarklessShareConfirmation = true
            return
        }

        openShareSheet(consumesFreeWatermarkAllowance: false)
    }

    private func openShareSheet(consumesFreeWatermarkAllowance: Bool) {
        guard let image = preparedImage() else {
            outputAlert = PreviewOutputAlert(title: "共有できませんでした", message: "画像の生成に失敗しました。")
            return
        }

        shareItem = ShareImageItem(
            image: image,
            consumesFreeWatermarkAllowance: consumesFreeWatermarkAllowance
        )
    }

    private func handleShareCompletion(for item: ShareImageItem, completed: Bool, error: Error?) {
        if let error {
            outputAlert = PreviewOutputAlert(title: "共有できませんでした", message: error.localizedDescription)
            return
        }

        guard completed, item.consumesFreeWatermarkAllowance else {
            return
        }

        guard consumeFreeWatermarkAllowanceAfterSuccessfulOutput() else {
            outputAlert = PreviewOutputAlert(title: "無料枠を更新できませんでした", message: "ウォーターマークなしの本日分は使用済みです。")
            return
        }
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
                watermarkMode: watermarkOption.watermarkMode
            )
        )
    }

    private var watermarkAccessPolicy: WatermarkAccessPolicy {
        // TODO: Replace the free default with StoreKit-backed entitlement state.
        WatermarkAccessPolicy(entitlementState: entitlementState)
    }

    private var watermarkAccessSnapshot: WatermarkAccessSnapshot {
        watermarkAccessPolicy.snapshot
    }

    private var watermarkStatusText: String {
        if watermarkAccessSnapshot.hasUnlimitedAccess {
            return "ウォーターマークなし無制限"
        }

        return "なしは1日1回"
    }

    private func selectWatermarkOption(_ option: WatermarkExportOption) {
        guard option == .withWatermark || watermarkAccessSnapshot.canExportWithoutWatermark else {
            outputAlert = PreviewOutputAlert(title: "本日の無料枠を使用済みです", message: "ウォーターマークあり保存は無制限で使えます。")
            watermarkOption = .withWatermark
            return
        }

        watermarkOption = option
    }

    private func ensureCanExportSelectedWatermark() -> Bool {
        guard watermarkAccessPolicy.canExport(option: watermarkOption) else {
            outputAlert = PreviewOutputAlert(title: "本日の無料枠を使用済みです", message: "ウォーターマークあり保存は無制限で使えます。")
            watermarkOption = .withWatermark
            return false
        }

        return true
    }

    private func consumeWatermarkAllowanceIfNeeded() -> Bool {
        guard shouldConsumeFreeWatermarkAllowance(for: watermarkOption) else {
            return true
        }

        return consumeFreeWatermarkAllowanceAfterSuccessfulOutput()
    }

    private func shouldConsumeFreeWatermarkAllowance(for option: WatermarkExportOption) -> Bool {
        option == .withoutWatermark && !watermarkAccessSnapshot.hasUnlimitedAccess
    }

    private func consumeFreeWatermarkAllowanceAfterSuccessfulOutput() -> Bool {
        let didConsume = watermarkAccessPolicy.consumeIfNeeded(for: .withoutWatermark)
        if didConsume {
            watermarkOption = .withWatermark
            renderedImage = nil
            renderIfNeeded()
        }

        return didConsume
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

private struct WatermarkOptionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.48)
    }

    private var foregroundColor: Color {
        if isSelected {
            return MemoriesTheme.accentDeep
        }

        return MemoriesTheme.textSub
    }

    private var backgroundColor: Color {
        if isSelected {
            return MemoriesTheme.accent.opacity(0.18)
        }

        return MemoriesTheme.card.opacity(0.48)
    }

    private var borderColor: Color {
        if isSelected {
            return MemoriesTheme.accent.opacity(0.68)
        }

        return MemoriesTheme.border.opacity(0.72)
    }
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
