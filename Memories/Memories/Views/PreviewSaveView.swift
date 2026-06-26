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
    @EnvironmentObject private var appState: MemoriesAppState
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @State private var renderedImage: UIImage?
    @State private var isProcessing = false
    @State private var outputAlert: PreviewOutputAlert?
    @State private var shareItem: ShareImageItem?
    @State private var showExistingDraftDecision = false
    @State private var showNewDraftDecision = false
    @State private var currentDraftID: UUID?
    @State private var watermarkOption: WatermarkExportOption = .withWatermark
    @State private var showWatermarklessShareConfirmation = false
    @State private var showPurchase = false
    @State private var showDraftLimitAlert = false
    @State private var showDraftsFromLimit = false
    @State private var hasAppliedInitialWatermarkOption = false
    @State private var hasUserSelectedWatermarkOption = false

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
                .frame(maxWidth: MemoriesLayoutMetrics.previewMaxWidth, maxHeight: .infinity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if isProcessing {
                processingOverlay
            }
        }
        .navigationTitle(appState.t("preview.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshEntitlementsForWatermarkDecisionIfNeeded()
            applyInitialWatermarkOptionIfNeeded()
            renderIfNeeded()
        }
        .onChange(of: watermarkOption) { _, _ in
            renderedImage = nil
            renderIfNeeded()
        }
        .onChange(of: appState.entitlementRefreshID) { _, _ in
            applyInitialWatermarkOptionIfNeeded()
        }
        .alert(item: $outputAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: alert.message.map(Text.init),
                dismissButton: .default(Text(appState.t("common.ok")))
            )
        }
        .alert(appState.t("preview.confirmShareTitle"), isPresented: $showWatermarklessShareConfirmation) {
            Button(appState.t("preview.shareAction")) {
                Task {
                    await openShareSheet(consumesFreeWatermarkAllowance: true)
                }
            }

            Button(appState.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(appState.t("preview.confirmShareMessage"))
        }
        .alert(appState.t("preview.saveComplete"), isPresented: $showExistingDraftDecision) {
            Button(appState.t("preview.keepDraft")) {
                Task {
                    await updateCurrentDraftAfterPhotoSave()
                }
            }

            Button(appState.t("preview.deleteDraft"), role: .destructive) {
                deleteCurrentDraft()
            }

            Button(appState.t("preview.returnToPreview"), role: .cancel) {}
        } message: {
            Text(appState.t("preview.keepExistingDraftQuestion"))
        }
        .alert(appState.t("preview.saveComplete"), isPresented: $showNewDraftDecision) {
            Button(appState.t("preview.saveDraft")) {
                Task {
                    await createDraftAfterPhotoSave()
                }
            }

            Button(appState.t("preview.finishNoDraft"), role: .destructive) {
                dismiss()
                onFinishWithoutDraft()
            }

            Button(appState.t("preview.returnToPreview"), role: .cancel) {}
        } message: {
            Text(appState.t("preview.saveNewDraftQuestion"))
        }
        .alert(appState.t("drafts.full.title"), isPresented: $showDraftLimitAlert) {
            Button(appState.t("drafts.manage")) {
                showDraftsFromLimit = true
            }

            Button(appState.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(String(format: appState.t("drafts.full.message"), appState.draftLimit))
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.image]) { completed, error in
                handleShareCompletion(for: item, completed: completed, error: error)
            }
        }
        .sheet(isPresented: $showPurchase) {
            PurchaseView()
        }
        .navigationDestination(isPresented: $showDraftsFromLimit) {
            DraftsView()
        }
    }

    @ViewBuilder
    private func previewImage(in screenSize: CGSize) -> some View {
        if let renderedImage {
            let imageAspectRatio = renderedImage.size.width / max(renderedImage.size.height, 1)
            let maxWidth = max(180, min(screenSize.width, MemoriesLayoutMetrics.previewMaxWidth) - 40)
            let reservedPanelHeight: CGFloat = 352
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

                    Text(appState.t("preview.creating"))
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
                    MemoriesPrimaryButton(appState.t("preview.savePhoto"), systemImage: "square.and.arrow.down") {
                        Task {
                            await saveToPhotoLibrary()
                        }
                    }
                    .disabled(renderedImage == nil || isProcessing)

            MemoriesSecondaryButton(appState.t("preview.share"), systemImage: "square.and.arrow.up") {
                Task {
                    await prepareShare()
                }
            }
                    .disabled(renderedImage == nil || isProcessing)
                }

                MemoriesSecondaryButton(appState.t("preview.backToEdit"), systemImage: "chevron.left") {
                    dismiss()
                }
            }
            .padding(12)
        }
    }

    private var watermarkPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(appState.t("preview.watermark"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textSub)

                Spacer()

                Text(watermarkStatusText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textSub)
            }

            HStack(spacing: 8) {
                WatermarkOptionButton(
                    title: appState.t("preview.withWatermark"),
                    subtitle: appState.t("common.unlimited"),
                    systemImage: "checkmark.seal",
                    isSelected: watermarkOption == .withWatermark,
                    isEnabled: true
                ) {
                    selectWatermarkOption(.withWatermark)
                }

                WatermarkOptionButton(
                    title: appState.t("preview.withoutWatermark"),
                    subtitle: withoutWatermarkOptionSubtitle,
                    systemImage: "seal",
                    isSelected: watermarkOption == .withoutWatermark,
                    isEnabled: watermarkAccessSnapshot.canExportWithoutWatermark
                ) {
                    selectWatermarkOption(.withoutWatermark)
                }
            }

            paidAccessRow
        }
        .padding(12)
        .background(MemoriesTheme.card.opacity(0.48))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(MemoriesTheme.border.opacity(0.72), lineWidth: 1)
        }
    }

    private var paidAccessRow: some View {
        HStack(spacing: 10) {
            Image(systemName: paidAccessIconName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MemoriesTheme.accentDeep)
                .frame(width: 26, height: 26)
                .background(MemoriesTheme.subBackground.opacity(0.78))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(paidAccessTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(paidAccessSubtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(MemoriesTheme.textSub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }

            Spacer(minLength: 0)

            if shouldShowPurchaseLink {
                Button {
                    showPurchase = true
                } label: {
                    Text(paidAccessButtonTitle)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .foregroundStyle(MemoriesTheme.accentDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(MemoriesTheme.border.opacity(0.72), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(MemoriesTheme.subBackground.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(MemoriesTheme.border.opacity(0.58), lineWidth: 1)
        }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()

            ProgressView(appState.t("preview.processing"))
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
            outputAlert = PreviewOutputAlert(title: appState.t("preview.renderFailed"), message: appState.t("preview.imageGenerateFailed"))
        }
    }

    @MainActor
    private func saveToPhotoLibrary() async {
        guard await ensureCanExportSelectedWatermark() else {
            return
        }

        guard let image = preparedImage() else {
            outputAlert = PreviewOutputAlert(title: appState.t("preview.saveFailed"), message: appState.t("preview.imageGenerateFailed"))
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await PhotoLibrarySaver().save(image)
            guard consumeWatermarkAllowanceIfNeeded() else {
                outputAlert = PreviewOutputAlert(title: appState.t("preview.saveComplete"), message: appState.t("preview.todayUsed"))
                return
            }

            if currentDraftID != nil {
                showExistingDraftDecision = true
            } else {
                showNewDraftDecision = true
            }
        } catch {
            outputAlert = PreviewOutputAlert(title: appState.t("preview.saveFailed"), message: error.localizedDescription)
        }
    }

    @MainActor
    private func prepareShare() async {
        guard await ensureCanExportSelectedWatermark() else {
            return
        }

        if shouldConsumeFreeWatermarkAllowance(for: watermarkOption) {
            showWatermarklessShareConfirmation = true
            return
        }

        await openShareSheet(consumesFreeWatermarkAllowance: false)
    }

    @MainActor
    private func openShareSheet(consumesFreeWatermarkAllowance: Bool) async {
        if consumesFreeWatermarkAllowance {
            guard await ensureCanExportSelectedWatermark() else {
                return
            }
        }

        guard let image = preparedImage() else {
            outputAlert = PreviewOutputAlert(title: appState.t("preview.shareFailed"), message: appState.t("preview.imageGenerateFailed"))
            return
        }

        shareItem = ShareImageItem(
            image: image,
            consumesFreeWatermarkAllowance: consumesFreeWatermarkAllowance
        )
    }

    private func handleShareCompletion(for item: ShareImageItem, completed: Bool, error: Error?) {
        if let error {
            outputAlert = PreviewOutputAlert(title: appState.t("preview.shareFailed"), message: error.localizedDescription)
            return
        }

        guard completed, item.consumesFreeWatermarkAllowance else {
            return
        }

        guard consumeFreeWatermarkAllowanceAfterSuccessfulOutput() else {
            outputAlert = PreviewOutputAlert(title: appState.t("preview.freeUpdateFailed"), message: appState.t("preview.todayUsed"))
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
        appState.watermarkPolicy()
    }

    private var watermarkAccessSnapshot: WatermarkAccessSnapshot {
        watermarkAccessPolicy.snapshot
    }

    private var watermarkStatusText: String {
        if watermarkAccessSnapshot.hasUnlimitedAccess {
            return appState.t("preview.withoutUnlimited")
        }

        return appState.t("preview.withoutOnce")
    }

    private var withoutWatermarkOptionSubtitle: String {
        if watermarkAccessSnapshot.hasUnlimitedAccess {
            return appState.t("common.unlimited")
        }

        if watermarkAccessSnapshot.remainingFreeExportsToday > 0 {
            return String(format: appState.t("preview.remainingToday"), watermarkAccessSnapshot.remainingFreeExportsToday)
        }

        return appState.t("common.used")
    }

    private var paidAccessIconName: String {
        if watermarkAccessSnapshot.hasUnlimitedAccess {
            return "checkmark.seal"
        }

        return watermarkAccessSnapshot.remainingFreeExportsToday > 0 ? "sparkles" : "seal"
    }

    private var paidAccessTitle: String {
        let entitlement = appState.effectiveEntitlementState
        if entitlement.hasLifetimePass {
            return appState.t("preview.lifetimeActive")
        }

        if let expiry = entitlement.sevenDayPassExpiresAt, expiry > Date() {
            return appState.t("preview.sevenDayActive")
        }

        if watermarkAccessSnapshot.remainingFreeExportsToday > 0 {
            return appState.t("preview.todayAvailable")
        }

        return appState.t("preview.todayUsed")
    }

    private var paidAccessSubtitle: String {
        let entitlement = appState.effectiveEntitlementState
        if entitlement.hasLifetimePass {
            return appState.t("preview.canSaveWithout")
        }

        if let expiry = entitlement.sevenDayPassExpiresAt, expiry > Date() {
            return String(format: appState.t("preview.activeUntil"), appState.formattedDateTime(expiry))
        }

        if watermarkAccessSnapshot.remainingFreeExportsToday > 0 {
            return appState.t("preview.needMore")
        }

        return appState.t("preview.purchaseWithout")
    }

    private var shouldShowPurchaseLink: Bool {
        !watermarkAccessSnapshot.hasUnlimitedAccess
    }

    private var paidAccessButtonTitle: String {
        watermarkAccessSnapshot.remainingFreeExportsToday > 0
            ? appState.t("preview.viewPasses")
            : appState.t("preview.purchaseWithout")
    }

    private func selectWatermarkOption(_ option: WatermarkExportOption) {
        guard option == .withWatermark || watermarkAccessSnapshot.canExportWithoutWatermark else {
            outputAlert = PreviewOutputAlert(title: appState.t("preview.freeUsedTitle"), message: appState.t("preview.freeUsedMessage"))
            watermarkOption = .withWatermark
            return
        }

        hasUserSelectedWatermarkOption = true
        watermarkOption = option
    }

    private func applyInitialWatermarkOptionIfNeeded() {
        guard !hasUserSelectedWatermarkOption else {
            return
        }

        if watermarkAccessSnapshot.hasUnlimitedAccess {
            watermarkOption = .withoutWatermark
            hasAppliedInitialWatermarkOption = true
            return
        }

        guard !hasAppliedInitialWatermarkOption else {
            return
        }

        watermarkOption = .withWatermark
        hasAppliedInitialWatermarkOption = true
    }

    @MainActor
    private func ensureCanExportSelectedWatermark() async -> Bool {
        if watermarkOption == .withoutWatermark {
            await refreshEntitlementsForWatermarkDecisionIfNeeded()
        }

        guard watermarkAccessPolicy.canExport(option: watermarkOption) else {
            outputAlert = PreviewOutputAlert(title: appState.t("preview.freeUsedTitle"), message: appState.t("preview.freeUsedMessage"))
            watermarkOption = .withWatermark
            return false
        }

        return true
    }

    @MainActor
    private func refreshEntitlementsForWatermarkDecisionIfNeeded() async {
        await storeKitManager.ensureFreshEntitlements()
        if !watermarkAccessSnapshot.canExportWithoutWatermark, watermarkOption == .withoutWatermark {
            watermarkOption = .withWatermark
        }
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
            outputAlert = PreviewOutputAlert(title: appState.t("preview.draftDeleteFailed"), message: error.localizedDescription)
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
        guard canSaveDraft(existingDraftID: nil) else {
            showDraftLimitAlert = true
            return
        }

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
                existingDraftID: existingDraftID,
                draftLimit: appState.draftLimit
            )
            currentDraftID = record.id
            onDraftSaved(record.id)
            outputAlert = PreviewOutputAlert(title: appState.t("editor.draftSaved"), message: nil)
        } catch {
            outputAlert = PreviewOutputAlert(title: appState.t("editor.draftSaveFailed"), message: error.localizedDescription)
        }
    }

    private func canSaveDraft(existingDraftID: UUID?) -> Bool {
        if existingDraftID != nil {
            return true
        }

        return DraftRepository.shared.loadDrafts().count < appState.draftLimit
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
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
        .environmentObject(MemoriesAppState())
        .environmentObject(StoreKitManager())
    }
}
