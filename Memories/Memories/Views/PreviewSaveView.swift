import AVKit
import SwiftUI
import UIKit

struct PreviewSaveView: View {
    let template: Template
    let editState: CardEditState
    let media: EditableMedia?
    let draftID: UUID?
    let onDraftSaved: (UUID) -> Void
    let onDraftDeleted: () -> Void
    let onFinishWithoutDraft: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: MemoriesAppState
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @State private var renderedImage: UIImage?
    @State private var renderedVideoURL: URL?
    @State private var isProcessing = false
    @State private var outputAlert: PreviewOutputAlert?
    @State private var shareItem: ShareMediaItem?
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
        media: EditableMedia?,
        draftID: UUID?,
        onDraftSaved: @escaping (UUID) -> Void = { _ in },
        onDraftDeleted: @escaping () -> Void = {},
        onFinishWithoutDraft: @escaping () -> Void = {}
    ) {
        self.template = template
        self.editState = editState
        self.media = media
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
            await prepareOutputIfNeeded()
        }
        .onChange(of: watermarkOption) { _, _ in
            guard isOutputReady else {
                return
            }
            Task {
                await regenerateOutputForWatermarkChange()
            }
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
            ShareSheet(items: [item.item]) { completed, error in
                handleShareCompletion(for: item, completed: completed, error: error)
            }
        }
        .sheet(isPresented: $showPurchase) {
            PurchaseView()
        }
        .navigationDestination(isPresented: $showDraftsFromLimit) {
            DraftsView()
        }
        .onDisappear {
            MediaFileManager.shared.removeTemporaryFileIfPossible(at: renderedVideoURL)
            renderedVideoURL = nil
            _ = try? MediaFileManager.shared.cleanupTemporaryFiles()
        }
    }

    @ViewBuilder
    private func previewImage(in screenSize: CGSize) -> some View {
        if media?.kind == .video, let renderedVideoURL {
            let videoAspectRatio = outputAspectRatio
            let maxWidth = max(180, min(screenSize.width, MemoriesLayoutMetrics.previewMaxWidth) - 40)
            let reservedPanelHeight: CGFloat = 352
            let maxHeight = max(240, min(screenSize.height * 0.58, screenSize.height - reservedPanelHeight))
            let previewWidth = min(maxWidth, maxHeight * videoAspectRatio)
            let previewHeight = previewWidth / videoAspectRatio

            PreviewLoopingVideoPlayerView(url: renderedVideoURL)
                .frame(width: previewWidth, height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MemoriesTheme.border.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: MemoriesTheme.accentDeep.opacity(0.13), radius: 24, y: 14)
                .padding(.horizontal, 20)
        } else if let renderedImage {
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
                    MemoriesPrimaryButton(appState.t("preview.saveMedia"), systemImage: "square.and.arrow.down") {
                        Task {
                            await saveToPhotoLibrary()
                        }
                    }
                    .disabled(!isOutputReady || isProcessing)

            MemoriesSecondaryButton(appState.t("preview.share"), systemImage: "square.and.arrow.up") {
                Task {
                    await prepareShare()
                }
            }
                    .disabled(!isOutputReady || isProcessing)
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
                MemoriesWatermarkOptionButton(
                    title: appState.t("preview.withWatermark"),
                    subtitle: appState.t("common.unlimited"),
                    systemImage: "checkmark.seal",
                    isSelected: watermarkOption == .withWatermark,
                    isEnabled: true
                ) {
                    selectWatermarkOption(.withWatermark)
                }

                MemoriesWatermarkOptionButton(
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

    @MainActor
    private func prepareOutputIfNeeded() async {
        if isOutputReady {
            return
        }

        if media?.kind == .video {
            if let renderedVideoURL, !FileManager.default.fileExists(atPath: renderedVideoURL.path) {
                self.renderedVideoURL = nil
            }
            await exportVideoIfNeeded()
        } else {
            renderedImage = renderFinalImage()
            if renderedImage == nil {
                outputAlert = PreviewOutputAlert(title: appState.t("preview.renderFailed"), message: appState.t("preview.imageGenerateFailed"))
            }
        }
    }

    @MainActor
    private func exportVideoIfNeeded() async {
        if let renderedVideoURL, FileManager.default.fileExists(atPath: renderedVideoURL.path) {
            return
        }

        guard let media else {
            outputAlert = PreviewOutputAlert(title: appState.t("preview.renderFailed"), message: appState.t("preview.videoGenerateFailed"))
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            renderedVideoURL = try await exportVideo(media: media)
        } catch {
            outputAlert = PreviewOutputAlert(title: appState.t("preview.renderFailed"), message: error.localizedDescription)
        }
    }

    @MainActor
    private func regenerateOutputForWatermarkChange() async {
        if media?.kind == .video {
            guard let media else {
                outputAlert = PreviewOutputAlert(title: appState.t("preview.renderFailed"), message: appState.t("preview.videoGenerateFailed"))
                return
            }

            let previousURL = renderedVideoURL
            isProcessing = true
            defer { isProcessing = false }

            do {
                let newURL = try await exportVideo(media: media)
                renderedVideoURL = newURL
                MediaFileManager.shared.removeTemporaryFileIfPossible(at: previousURL)
            } catch {
                outputAlert = PreviewOutputAlert(title: appState.t("preview.renderFailed"), message: error.localizedDescription)
            }
        } else {
            renderedImage = renderFinalImage()
            if renderedImage == nil {
                outputAlert = PreviewOutputAlert(title: appState.t("preview.renderFailed"), message: appState.t("preview.imageGenerateFailed"))
            }
        }
    }

    private func exportVideo(media: EditableMedia) async throws -> URL {
        try await VideoTemplateExporter().export(
            media: media,
            template: template,
            editState: editState,
            watermarkMode: watermarkOption.watermarkMode
        )
    }

    @MainActor
    private func saveToPhotoLibrary() async {
        guard await ensureCanExportSelectedWatermark() else {
            return
        }

        await prepareOutputIfNeeded()

        isProcessing = true
        defer { isProcessing = false }

        do {
            if media?.kind == .video {
                guard let renderedVideoURL else {
                    outputAlert = PreviewOutputAlert(title: appState.t("preview.saveFailed"), message: appState.t("preview.videoGenerateFailed"))
                    return
                }
                try await PhotoLibrarySaver().saveVideo(at: renderedVideoURL)
            } else {
                guard let image = preparedImage() else {
                    outputAlert = PreviewOutputAlert(title: appState.t("preview.saveFailed"), message: appState.t("preview.imageGenerateFailed"))
                    return
                }
                try await PhotoLibrarySaver().save(image)
            }
            guard consumeWatermarkAllowanceIfNeeded() else {
                outputAlert = PreviewOutputAlert(title: appState.t("preview.saveComplete"), message: appState.t("preview.todayUsed"))
                return
            }

            ReviewRequestManager.shared.recordSuccessfulSaveAndRequestReviewIfEligible()

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

        await prepareOutputIfNeeded()

        do {
            if media?.kind == .video {
                guard let renderedVideoURL else {
                    outputAlert = PreviewOutputAlert(title: appState.t("preview.shareFailed"), message: appState.t("preview.videoGenerateFailed"))
                    return
                }
                let shareURL = try MediaFileManager.shared.copyTemporaryShareFile(from: renderedVideoURL)
                shareItem = ShareMediaItem(
                    item: shareURL,
                    consumesFreeWatermarkAllowance: consumesFreeWatermarkAllowance,
                    cleanupURL: shareURL
                )
            } else {
                guard let image = preparedImage() else {
                    outputAlert = PreviewOutputAlert(title: appState.t("preview.shareFailed"), message: appState.t("preview.imageGenerateFailed"))
                    return
                }
                shareItem = ShareMediaItem(
                    item: image,
                    consumesFreeWatermarkAllowance: consumesFreeWatermarkAllowance,
                    cleanupURL: nil
                )
            }
        } catch {
            outputAlert = PreviewOutputAlert(title: appState.t("preview.shareFailed"), message: error.localizedDescription)
        }
    }

    private func handleShareCompletion(for item: ShareMediaItem, completed: Bool, error: Error?) {
        MediaFileManager.shared.removeTemporaryFileIfPossible(at: item.cleanupURL)

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
                photoImage: media?.image,
                watermarkMode: watermarkOption.watermarkMode
            )
        )
    }

    private var isOutputReady: Bool {
        if media?.kind == .video {
            guard let renderedVideoURL else {
                return false
            }
            return FileManager.default.fileExists(atPath: renderedVideoURL.path)
        }
        return renderedImage != nil
    }

    private var outputAspectRatio: CGFloat {
        if let ticketAspectRatio = TicketCardLayout.aspectRatio(for: template.renderStyle) {
            return ticketAspectRatio
        }

        let size = media?.contentSize ?? renderedImage?.size ?? template.defaultAspectRatio.outputSize
        guard size.width > 0, size.height > 0 else {
            return template.defaultAspectRatio.value
        }

        return size.width / size.height
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
        guard watermarkOption != option else {
            return
        }

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
                media: media,
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

private struct PreviewLoopingVideoPlayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PreviewLoopingVideoPlayerUIView {
        let view = PreviewLoopingVideoPlayerUIView()
        view.configure(url: url)
        return view
    }

    func updateUIView(_ uiView: PreviewLoopingVideoPlayerUIView, context: Context) {
        uiView.configure(url: url)
    }
}

private final class PreviewLoopingVideoPlayerUIView: UIView {
    private var currentURL: URL?
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    func configure(url: URL) {
        guard currentURL != url else {
            return
        }

        currentURL = url
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: item)
        queuePlayer.isMuted = false
        queuePlayer.actionAtItemEnd = .none
        player = queuePlayer
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        playerLayer.player = queuePlayer
        playerLayer.videoGravity = .resizeAspect
        queuePlayer.play()
    }
}

#Preview {
    NavigationStack {
        PreviewSaveView(
            template: .previewPetLifelog,
            editState: Template.previewPetLifelog.previewEditState,
            media: nil,
            draftID: nil
        )
        .environmentObject(MemoriesAppState())
        .environmentObject(StoreKitManager())
    }
}
