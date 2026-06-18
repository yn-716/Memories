import SwiftUI
import UIKit

struct EditorView: View {
    let template: Template
    let photoImage: UIImage?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: MemoriesAppState
    @State private var editState: CardEditState
    @State private var lastPersistedEditState: CardEditState
    @State private var currentDraftID: UUID?
    @State private var selectedTab: EditorPanelTab = .text
    @State private var selectedTextTarget: TextEditTarget = .main
    @State private var selectedIconSection: IconEditSection = .theme
    @State private var selectedAppearanceSection: AppearanceEditSection = .font
    @State private var showBackConfirmation = false
    @State private var showDateEditSheet = false
    @State private var isPreparingOutput = false
    @State private var outputAlert: OutputAlert?
    @State private var previewRoute: PreviewRoute?
    @State private var showDraftLimitAlert = false
    @State private var showDraftsFromLimit = false

    init(
        template: Template,
        photoImage: UIImage? = nil,
        initialEditState: CardEditState? = nil,
        draftID: UUID? = nil
    ) {
        let initialState = if let initialEditState {
            initialEditState
        } else if photoImage == nil {
            template.previewEditState
        } else {
            CardEditState.newCard(
                defaultLayout: template.defaultLayout,
                fontRole: template.overlayStyle.defaultFontRole,
                textColor: template.overlayStyle.defaultTextColor
            )
        }

        self.template = template
        self.photoImage = photoImage
        _editState = State(initialValue: initialState)
        _lastPersistedEditState = State(initialValue: initialState)
        _currentDraftID = State(initialValue: draftID)
    }

    var body: some View {
        GeometryReader { geometry in
            let panelHeight = editorPanelHeight(for: geometry.size)

            VStack(spacing: 0) {
                previewArea
                    .frame(height: max(geometry.size.height - panelHeight, 280))

                editorPanel
                    .frame(height: panelHeight)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(maxWidth: MemoriesLayoutMetrics.editorMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(MemoriesTheme.background.ignoresSafeArea())
        .navigationTitle(appState.t("editor.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    handleBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.accentDeep)
                        .frame(width: 36, height: 32)
                        .background(.ultraThinMaterial)
                        .background(MemoriesTheme.card.opacity(0.46))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(MemoriesTheme.border.opacity(0.82), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    Button {
                        Task {
                            await saveDraft()
                        }
                    } label: {
                        Text(appState.t("editor.saveDraft"))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                            .foregroundStyle(MemoriesTheme.accentDeep)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .background(MemoriesTheme.card.opacity(0.42))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(MemoriesTheme.border.opacity(0.72), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isPreparingOutput)

                    Button {
                        previewRoute = PreviewRoute(
                            template: template,
                            editState: editState,
                            photoImage: photoImage,
                            draftID: currentDraftID
                        )
                    } label: {
                        Text(appState.t("editor.preview"))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [MemoriesTheme.accentDeep.opacity(0.92), MemoriesTheme.accent.opacity(0.72)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(.white.opacity(0.26), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isPreparingOutput)
                }
            }
        }
        .confirmationDialog(
            appState.t("editor.unsaved.title"),
            isPresented: $showBackConfirmation,
            titleVisibility: .visible
        ) {
            Button(appState.t("editor.saveDraft")) {
                Task {
                    await saveDraft(shouldDismissAfterSave: true)
                }
            }

            Button(appState.t("editor.discard"), role: .destructive) {
                dismiss()
            }

            Button(appState.t("editor.continue"), role: .cancel) {}
        } message: {
            Text(appState.t("editor.unsaved.message"))
        }
        .alert(item: $outputAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: alert.message.map(Text.init),
                dismissButton: .default(Text(appState.t("common.ok")))
            )
        }
        .alert(appState.t("drafts.full.title"), isPresented: $showDraftLimitAlert) {
            Button(appState.t("drafts.manage")) {
                showDraftsFromLimit = true
            }

            Button(appState.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(String(format: appState.t("drafts.full.message"), appState.draftLimit))
        }
        .sheet(isPresented: $showDateEditSheet) {
            DateEditSheet(editState: editState) { payload in
                editState.dateMode = payload.dateMode
                editState.selectedDate = payload.selectedDate
                editState.startDate = payload.startDate
                editState.endDate = payload.endDate
                editState.customDateText = payload.customDateText
            }
        }
        .navigationDestination(item: $previewRoute) { route in
            PreviewSaveView(
                template: route.template,
                editState: route.editState,
                photoImage: route.photoImage,
                draftID: route.draftID
            ) { draftID in
                currentDraftID = draftID
                lastPersistedEditState = editState
            } onDraftDeleted: {
                currentDraftID = nil
                lastPersistedEditState = editState
                previewRoute = nil
                DispatchQueue.main.async {
                    dismiss()
                }
            } onFinishWithoutDraft: {
                previewRoute = nil
                DispatchQueue.main.async {
                    dismiss()
                }
            }
        }
        .navigationDestination(isPresented: $showDraftsFromLimit) {
            DraftsView()
        }
        .overlay {
            if isPreparingOutput {
                ZStack {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()

                    ProgressView(appState.t("editor.savingDraft"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textMain)
                        .tint(MemoriesTheme.accentDeep)
                        .padding(18)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(MemoriesTheme.border.opacity(0.78), lineWidth: 1)
                        }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var previewArea: some View {
        GeometryReader { proxy in
            let maxWidth = max(120, proxy.size.width - 48)
            let maxHeight = max(160, proxy.size.height - 38)
            let previewWidth = min(maxWidth, maxHeight * photoAspectRatio)
            let previewHeight = previewWidth / photoAspectRatio

            ZStack {
                MemoriesTheme.background

                TemplateCanvasPreview(
                    template: template,
                    editState: editState,
                    photoImage: photoImage,
                    aspectRatio: photoAspectRatio
                )
                .frame(width: previewWidth, height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MemoriesTheme.border.opacity(0.78), lineWidth: 1)
                }
                .shadow(color: MemoriesTheme.accentDeep.opacity(0.12), radius: 22, y: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var editorPanel: some View {
        MemoriesGlassPanel {
            VStack(spacing: 10) {
                tabBar

                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 7) {
            ForEach(EditorPanelTab.allCases) { tab in
                MemoriesPillTab(title: tab.title(language: appState.resolvedLanguage), isSelected: selectedTab == tab) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedTab = tab
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .text:
            textTab
        case .icon:
            iconTab
        case .appearance:
            appearanceTab
        case .position:
            positionTab
        }
    }

    private var textTab: some View {
        let target = selectedTextTarget

        return VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 6) {
                Text(appState.t("editor.textItems"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textSub)

                HStack(spacing: 6) {
                    ForEach(TextEditTarget.allCases) { target in
                        SubItemChip(
                            title: target.title(language: appState.resolvedLanguage),
                            isSelected: selectedTextTarget == target
                        ) {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                selectedTextTarget = target
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 10) {
                    Label(target.editorTitle(language: appState.resolvedLanguage), systemImage: target.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textMain)

                    Spacer()

                    CompactVisibilityToggle(isOn: visibilityBinding(for: target))
                }

                Text(target.hint(language: appState.resolvedLanguage))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(MemoriesTheme.textSub)
                    .lineLimit(1)

                if target == .date {
                    dateEditor
                } else {
                    textFieldEditor(for: target)
                }
            }
            .padding(12)
            .background(MemoriesTheme.card.opacity(0.52))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MemoriesTheme.border.opacity(0.62), lineWidth: 1)
            }
        }
    }

    private func textFieldEditor(for target: TextEditTarget) -> some View {
        let text = textBinding(for: target)

        return VStack(spacing: 7) {
            TextField(target.placeholder(language: appState.resolvedLanguage), text: text)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MemoriesTheme.textMain)
                .lineLimit(1)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(MemoriesTheme.card.opacity(0.76))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(MemoriesTheme.border.opacity(0.72), lineWidth: 1)
                }

            HStack {
                Spacer()

                Text(String(format: appState.t("editor.characterGuide"), text.wrappedValue.count, target.characterLimit))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textSub)
            }
        }
    }

    private var dateEditor: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(editState.displayDateText.trimmedForEditor.isEmpty ? appState.t("editor.empty") : editState.displayDateText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(editState.dateMode.displayName(language: appState.resolvedLanguage))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textSub)
            }

            Spacer()

            Button {
                showDateEditSheet = true
            } label: {
                Label(appState.t("common.change"), systemImage: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.accentDeep)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial)
                    .background(MemoriesTheme.card.opacity(0.62))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(MemoriesTheme.border.opacity(0.78), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(MemoriesTheme.card.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(MemoriesTheme.border.opacity(0.74), lineWidth: 1)
        }
    }

    private var iconTab: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                CompactPanelChip(
                    title: appState.t("editor.theme"),
                    systemImage: "pawprint",
                    isSelected: selectedIconSection == .theme
                ) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedIconSection = .theme
                    }
                }

                CompactPanelChip(
                    title: appState.t("editor.weather"),
                    systemImage: "sun.max",
                    isSelected: selectedIconSection == .weather
                ) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedIconSection = .weather
                    }
                }
            }

            HStack(spacing: 10) {
                Label(selectedIconSection.title(language: appState.resolvedLanguage), systemImage: selectedIconSection.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)

                Spacer()

                CompactVisibilityToggle(isOn: iconVisibilityBinding)
            }

            if selectedIconSection == .theme {
                LazyVGrid(columns: iconColumns(count: 5), spacing: 7) {
                    ForEach(ThemeIconType.allCases) { icon in
                        CompactIconOptionButton(
                            title: icon.displayName.localized(for: appState.resolvedLanguage),
                            systemImage: icon.symbolName,
                            assetName: icon.assetName,
                            isSelected: editState.selectedThemeIcon == icon
                        ) {
                            editState.selectedThemeIcon = icon
                        }
                    }
                }
            } else {
                LazyVGrid(columns: iconColumns(count: 5), spacing: 7) {
                    ForEach(WeatherType.allCases) { weather in
                        CompactIconOptionButton(
                            title: weather.editorDisplayName(language: appState.resolvedLanguage),
                            systemImage: weather.symbolName ?? "minus.circle",
                            assetName: weather.assetName,
                            isSelected: editState.selectedWeather == weather
                        ) {
                            editState.selectedWeather = weather
                        }
                    }
                }
            }
        }
    }

    private var appearanceTab: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                CompactPanelChip(
                    title: appState.t("editor.font"),
                    systemImage: "textformat",
                    isSelected: selectedAppearanceSection == .font
                ) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedAppearanceSection = .font
                    }
                }

                CompactPanelChip(
                    title: appState.t("editor.color"),
                    systemImage: "paintpalette",
                    isSelected: selectedAppearanceSection == .color
                ) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedAppearanceSection = .color
                    }
                }
            }

            if selectedAppearanceSection == .font {
                LazyVGrid(columns: iconColumns(count: 5), spacing: 8) {
                    ForEach(FontRole.allCases) { fontRole in
                        CompactTextOptionButton(
                            title: fontRole.displayName,
                            sample: "Aa",
                            isSelected: editState.selectedFontRole == fontRole
                        ) {
                            editState.selectedFontRole = fontRole
                        }
                        .font(fontRole.font(size: 13, weight: .semibold))
                    }
                }
            } else {
                LazyVGrid(columns: iconColumns(count: 3), spacing: 8) {
                    ForEach(TextColorOption.allCases) { colorOption in
                        CompactColorOptionButton(
                            title: colorOption.displayName(language: appState.resolvedLanguage),
                            color: colorOption.color,
                            isSelected: editState.selectedTextColor == colorOption
                        ) {
                            editState.selectedTextColor = colorOption
                        }
                    }
                }
            }
        }
    }

    private var positionTab: some View {
        LazyVGrid(columns: iconColumns(count: 2), spacing: 10) {
            ForEach(OverlayPosition.allCases) { position in
                PositionPresetButton(
                    position: position,
                    isSelected: editState.selectedPosition == position
                ) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        editState.selectedPosition = position
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    private var iconVisibilityBinding: Binding<Bool> {
        switch selectedIconSection {
        case .theme:
            return $editState.visibilitySettings.showThemeIcon
        case .weather:
            return $editState.visibilitySettings.showWeather
        }
    }

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { editState.selectedDate },
            set: { editState.selectedDate = CardEditState.normalizedDate($0) }
        )
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { editState.startDate },
            set: { newValue in
                let normalized = CardEditState.normalizedDate(newValue)
                editState.startDate = normalized
                if editState.endDate < normalized {
                    editState.endDate = normalized
                }
            }
        )
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: { max(editState.startDate, editState.endDate) },
            set: { newValue in
                let normalized = CardEditState.normalizedDate(newValue)
                editState.endDate = max(editState.startDate, normalized)
            }
        )
    }

    private var hasUnsavedChanges: Bool {
        editState != lastPersistedEditState
    }

    private var photoAspectRatio: CGFloat {
        guard let photoImage, photoImage.size.width > 0, photoImage.size.height > 0 else {
            return template.defaultAspectRatio.value
        }

        return photoImage.size.width / photoImage.size.height
    }

    private func handleBack() {
        if hasUnsavedChanges {
            showBackConfirmation = true
        } else {
            dismiss()
        }
    }

    private func textBinding(for target: TextEditTarget) -> Binding<String> {
        switch target {
        case .main:
            return $editState.mainText
        case .sub:
            return $editState.subText
        case .location:
            return $editState.locationText
        case .date:
            return .constant(editState.displayDateText)
        }
    }

    private func visibilityBinding(for target: TextEditTarget) -> Binding<Bool> {
        switch target {
        case .main:
            return $editState.visibilitySettings.showMainText
        case .sub:
            return $editState.visibilitySettings.showSubText
        case .location:
            return $editState.visibilitySettings.showLocation
        case .date:
            return $editState.visibilitySettings.showDate
        }
    }

    private func normalizeDateRange() {
        editState.selectedDate = CardEditState.normalizedDate(editState.selectedDate)
        editState.startDate = CardEditState.normalizedDate(editState.startDate)
        editState.endDate = max(editState.startDate, CardEditState.normalizedDate(editState.endDate))
    }

    @MainActor
    private func saveDraft(shouldDismissAfterSave: Bool = false) async {
        guard canSaveDraft(existingDraftID: currentDraftID) else {
            showDraftLimitAlert = true
            return
        }

        isPreparingOutput = true
        defer { isPreparingOutput = false }

        do {
            let record = try DraftRepository.shared.save(
                template: template,
                editState: editState,
                photoImage: photoImage,
                existingDraftID: currentDraftID,
                draftLimit: appState.draftLimit
            )
            currentDraftID = record.id
            lastPersistedEditState = editState

            if shouldDismissAfterSave {
                dismiss()
            } else {
                outputAlert = OutputAlert(title: appState.t("editor.draftSaved"), message: nil)
            }
        } catch {
            outputAlert = OutputAlert(title: appState.t("editor.draftSaveFailed"), message: error.localizedDescription)
        }
    }

    private func iconColumns(count: Int) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 7), count: count)
    }

    private func editorPanelHeight(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.36, 252), size.height * 0.4)
    }

    private func canSaveDraft(existingDraftID: UUID?) -> Bool {
        if existingDraftID != nil {
            return true
        }

        return DraftRepository.shared.loadDrafts().count < appState.draftLimit
    }
}

private struct OutputAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
}

private struct PreviewRoute: Identifiable, Hashable {
    let id = UUID()
    let template: Template
    let editState: CardEditState
    let photoImage: UIImage?
    let draftID: UUID?

    static func == (lhs: PreviewRoute, rhs: PreviewRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct DateEditPayload {
    let dateMode: CardDateMode
    let selectedDate: Date
    let startDate: Date
    let endDate: Date
    let customDateText: String
}

private struct DateEditSheet: View {
    let onApply: (DateEditPayload) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: MemoriesAppState
    @State private var tempDateMode: CardDateMode
    @State private var tempSelectedDate: Date
    @State private var tempStartDate: Date
    @State private var tempEndDate: Date
    @State private var tempCustomDateText: String

    init(editState: CardEditState, onApply: @escaping (DateEditPayload) -> Void) {
        self.onApply = onApply
        _tempDateMode = State(initialValue: editState.dateMode)
        _tempSelectedDate = State(initialValue: editState.selectedDate)
        _tempStartDate = State(initialValue: editState.startDate)
        _tempEndDate = State(initialValue: max(editState.startDate, editState.endDate))
        _tempCustomDateText = State(initialValue: editState.customDateText)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MemoriesTheme.background.ignoresSafeArea()

                VStack(spacing: 14) {
                    dateEditPanel

                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 14)
                .frame(maxWidth: MemoriesLayoutMetrics.sheetMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(appState.t("date.select"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents(presentationDetents)
        .presentationDragIndicator(.visible)
    }

    private var dateEditPanel: some View {
        MemoriesGlassPanel {
            VStack(alignment: .leading, spacing: 13) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(appState.t("date.edit"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textMain)

                    Text(appState.t("date.notApplied"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MemoriesTheme.textSub)
                }

                modePicker

                dateInput

                displayPreviewRow
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            MemoriesSecondaryButton(appState.t("common.cancel")) {
                dismiss()
            }

            MemoriesPrimaryButton(appState.t("common.apply"), systemImage: "checkmark") {
                applyDate()
            }
        }
    }

    private var displayPreviewRow: some View {
        HStack {
            Text(appState.t("date.preview"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(MemoriesTheme.textSub)

            Spacer()

            Text(tempDisplayText.trimmedForEditor.isEmpty ? appState.t("editor.empty") : tempDisplayText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MemoriesTheme.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(MemoriesTheme.card.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MemoriesTheme.border.opacity(0.7), lineWidth: 1)
        }
    }

    private var presentationDetents: Set<PresentationDetent> {
        switch tempDateMode {
        case .single:
            return [.height(660), .large]
        case .range:
            return [.height(430), .large]
        case .custom:
            return [.height(360), .medium]
        }
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(CardDateMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        tempDateMode = mode
                        normalizeRange()
                    }
                } label: {
                    Text(mode.displayName(language: appState.resolvedLanguage))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(tempDateMode == mode ? MemoriesTheme.accentDeep : MemoriesTheme.textSub)
                        .background(tempDateMode == mode ? MemoriesTheme.accent.opacity(0.16) : MemoriesTheme.card.opacity(0.44))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(
                                    tempDateMode == mode ? MemoriesTheme.accent.opacity(0.6) : MemoriesTheme.border.opacity(0.62),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var dateInput: some View {
        switch tempDateMode {
        case .single:
            VStack(alignment: .leading, spacing: 8) {
                Text(appState.t("date.single"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textSub)

                DatePicker("日付", selection: $tempSelectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.graphical)
                    .tint(MemoriesTheme.accentDeep)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(MemoriesTheme.card.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(MemoriesTheme.border.opacity(0.72), lineWidth: 1)
                    }
            }

        case .range:
            VStack(alignment: .leading, spacing: 10) {
                Text(appState.t("date.range"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textSub)

                datePickerRow(title: appState.t("date.start"), selection: tempStartDateBinding)
                datePickerRow(title: appState.t("date.end"), selection: tempEndDateBinding)
            }

        case .custom:
            VStack(alignment: .leading, spacing: 8) {
                TextField("Spring 2026 / First Cafe Day / Today", text: $tempCustomDateText)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MemoriesTheme.textMain)
                    .lineLimit(1)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 12)
                    .background(MemoriesTheme.card.opacity(0.68))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(MemoriesTheme.border.opacity(0.8), lineWidth: 1)
                    }

                HStack {
                    Spacer()

                    Text(String(format: appState.t("editor.characterGuide"), tempCustomDateText.count, 30))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textSub)
                }
            }
        }
    }

    private func datePickerRow(title: String, selection: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MemoriesTheme.textMain)

            Spacer()

            DatePicker(title, selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(MemoriesTheme.accentDeep)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(MemoriesTheme.card.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MemoriesTheme.border.opacity(0.74), lineWidth: 1)
        }
    }

    private var tempStartDateBinding: Binding<Date> {
        Binding(
            get: { tempStartDate },
            set: { newValue in
                tempStartDate = CardEditState.normalizedDate(newValue)
                if tempEndDate < tempStartDate {
                    tempEndDate = tempStartDate
                }
            }
        )
    }

    private var tempEndDateBinding: Binding<Date> {
        Binding(
            get: { max(tempStartDate, tempEndDate) },
            set: { newValue in
                tempEndDate = max(tempStartDate, CardEditState.normalizedDate(newValue))
            }
        )
    }

    private var tempDisplayText: String {
        switch tempDateMode {
        case .single:
            return CardEditState.formatted(tempSelectedDate)
        case .range:
            return "\(CardEditState.formatted(tempStartDate)) - \(CardEditState.formatted(max(tempStartDate, tempEndDate)))"
        case .custom:
            return tempCustomDateText
        }
    }

    private func normalizeRange() {
        tempSelectedDate = CardEditState.normalizedDate(tempSelectedDate)
        tempStartDate = CardEditState.normalizedDate(tempStartDate)
        tempEndDate = max(tempStartDate, CardEditState.normalizedDate(tempEndDate))
    }

    private func applyDate() {
        normalizeRange()
        onApply(
            DateEditPayload(
                dateMode: tempDateMode,
                selectedDate: CardEditState.normalizedDate(tempSelectedDate),
                startDate: tempStartDate,
                endDate: max(tempStartDate, tempEndDate),
                customDateText: tempCustomDateText
            )
        )
        dismiss()
    }
}

private enum EditorPanelTab: CaseIterable, Identifiable {
    case text
    case icon
    case appearance
    case position

    var id: Self { self }

    func title(language: ResolvedAppLanguage) -> String {
        switch self {
        case .text:
            return MemoriesLocalization.text("editor.text", language: language)
        case .icon:
            return MemoriesLocalization.text("editor.icon", language: language)
        case .appearance:
            return MemoriesLocalization.text("editor.appearance", language: language)
        case .position:
            return MemoriesLocalization.text("editor.position", language: language)
        }
    }
}

private enum TextEditTarget: CaseIterable, Identifiable {
    case main
    case sub
    case location
    case date

    var id: Self { self }

    func title(language: ResolvedAppLanguage) -> String {
        switch self {
        case .main:
            return MemoriesLocalization.text("editor.main", language: language)
        case .sub:
            return MemoriesLocalization.text("editor.sub", language: language)
        case .location:
            return MemoriesLocalization.text("editor.location", language: language)
        case .date:
            return MemoriesLocalization.text("editor.date", language: language)
        }
    }

    func editorTitle(language: ResolvedAppLanguage) -> String {
        switch self {
        case .main:
            return MemoriesLocalization.text("editor.mainText", language: language)
        case .sub:
            return MemoriesLocalization.text("editor.subText", language: language)
        case .location:
            return MemoriesLocalization.text("editor.location", language: language)
        case .date:
            return MemoriesLocalization.text("editor.date", language: language)
        }
    }

    func placeholder(language: ResolvedAppLanguage) -> String {
        switch self {
        case .main:
            return MemoriesLocalization.text("editor.mainPlaceholder", language: language)
        case .sub:
            return MemoriesLocalization.text("editor.subPlaceholder", language: language)
        case .location:
            return MemoriesLocalization.text("editor.locationPlaceholder", language: language)
        case .date:
            return "2026.06.17"
        }
    }

    func hint(language: ResolvedAppLanguage) -> String {
        switch self {
        case .main:
            return MemoriesLocalization.text("editor.mainHint", language: language)
        case .sub:
            return MemoriesLocalization.text("editor.subHint", language: language)
        case .location:
            return MemoriesLocalization.text("editor.locationHint", language: language)
        case .date:
            return MemoriesLocalization.text("editor.dateHint", language: language)
        }
    }

    var characterLimit: Int {
        switch self {
        case .main:
            return 30
        case .sub:
            return 40
        case .location:
            return 30
        case .date:
            return 0
        }
    }

    var systemImage: String {
        switch self {
        case .main:
            return "textformat.size"
        case .sub:
            return "textformat"
        case .location:
            return "mappin"
        case .date:
            return "calendar"
        }
    }
}

private enum IconEditSection {
    case theme
    case weather

    func title(language: ResolvedAppLanguage) -> String {
        switch self {
        case .theme:
            return MemoriesLocalization.text("editor.themeIcon", language: language)
        case .weather:
            return MemoriesLocalization.text("editor.weatherIcon", language: language)
        }
    }

    var systemImage: String {
        switch self {
        case .theme:
            return "pawprint"
        case .weather:
            return "sun.max"
        }
    }
}

private enum AppearanceEditSection {
    case font
    case color
}

private struct CompactPanelChip: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2.weight(.semibold))
                }

                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : MemoriesTheme.textMain)
            .background(isSelected ? MemoriesTheme.accentDeep.opacity(0.82) : MemoriesTheme.card.opacity(0.46))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? .white.opacity(0.18) : MemoriesTheme.border.opacity(0.72), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SubItemChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? MemoriesTheme.accentDeep : MemoriesTheme.textSub)
                .background(isSelected ? MemoriesTheme.accent.opacity(0.14) : MemoriesTheme.card.opacity(0.34))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? MemoriesTheme.accent.opacity(0.48) : MemoriesTheme.border.opacity(0.42),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
    }
}

private struct CompactVisibilityToggle: View {
    @EnvironmentObject private var appState: MemoriesAppState
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(appState.t("editor.display"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(MemoriesTheme.textSub)
        }
        .toggleStyle(.switch)
        .tint(MemoriesTheme.accentDeep)
        .fixedSize()
    }
}

private struct CompactIconOptionButton: View {
    let title: String
    let systemImage: String
    let assetName: String?
    let isSelected: Bool
    let action: () -> Void

    init(
        title: String,
        systemImage: String,
        assetName: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.assetName = assetName
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                MemoriesTemplateIcon(assetName: assetName, fallbackSystemName: systemImage)
                    .frame(width: 17, height: 17)

                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? MemoriesTheme.accentDeep : MemoriesTheme.textMain)
            .background(isSelected ? MemoriesTheme.accent.opacity(0.16) : MemoriesTheme.card.opacity(0.46))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? MemoriesTheme.accent.opacity(0.62) : MemoriesTheme.border.opacity(0.7), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CompactTextOptionButton: View {
    let title: String
    let sample: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(sample)
                    .font(.headline.weight(.semibold))

                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? MemoriesTheme.accentDeep : MemoriesTheme.textMain)
            .background(isSelected ? MemoriesTheme.accent.opacity(0.16) : MemoriesTheme.card.opacity(0.46))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? MemoriesTheme.accent.opacity(0.62) : MemoriesTheme.border.opacity(0.7), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CompactColorOptionButton: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Circle()
                    .fill(color)
                    .frame(width: 15, height: 15)
                    .overlay {
                        Circle()
                            .stroke(MemoriesTheme.border.opacity(0.9), lineWidth: 1)
                    }

                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? MemoriesTheme.accentDeep : MemoriesTheme.textMain)
            .background(isSelected ? MemoriesTheme.accent.opacity(0.16) : MemoriesTheme.card.opacity(0.46))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? MemoriesTheme.accent.opacity(0.62) : MemoriesTheme.border.opacity(0.7), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PositionPresetButton: View {
    @EnvironmentObject private var appState: MemoriesAppState

    let position: OverlayPosition
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(MemoriesTheme.subBackground.opacity(isSelected ? 0.95 : 0.62))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(MemoriesTheme.border.opacity(0.72), lineWidth: 1)
                        }

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isSelected ? MemoriesTheme.accentDeep : MemoriesTheme.accent)
                        .frame(width: 18, height: 12)
                        .padding(7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
                }
                .frame(width: 58, height: 46)

                Text(position.displayName(language: appState.resolvedLanguage))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? MemoriesTheme.accentDeep : MemoriesTheme.textMain)

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(isSelected ? MemoriesTheme.card.opacity(0.72) : MemoriesTheme.card.opacity(0.44))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(isSelected ? MemoriesTheme.accent.opacity(0.7) : MemoriesTheme.border.opacity(0.64), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private extension WeatherType {
    func editorDisplayName(language: ResolvedAppLanguage) -> String {
        switch self {
        case .none:
            return displayName.localized(for: language)
        default:
            return displayName.localized(for: language)
        }
    }
}

private extension String {
    var trimmedForEditor: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    NavigationStack {
        EditorView(template: .previewPetLifelog)
            .environmentObject(MemoriesAppState())
    }
}
