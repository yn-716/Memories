import SwiftUI
import UIKit

struct EditorView: View {
    let template: Template
    let photoImage: UIImage?

    private let initialEditState: CardEditState

    @Environment(\.dismiss) private var dismiss
    @State private var editState: CardEditState
    @State private var selectedTab: EditorPanelTab = .text
    @State private var selectedTextTarget: TextEditTarget = .main
    @State private var selectedIconSection: IconEditSection = .theme
    @State private var selectedAppearanceSection: AppearanceEditSection = .font
    @State private var showBackConfirmation = false
    @State private var showDraftUnavailableAlert = false

    init(template: Template, photoImage: UIImage? = nil) {
        let initialState = if photoImage == nil {
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
        self.initialEditState = initialState
        _editState = State(initialValue: initialState)
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
        }
        .background(MemoriesTheme.background.ignoresSafeArea())
        .navigationTitle("編集")
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
                NavigationLink {
                    ExportView(
                        template: template,
                        editState: editState,
                        photoImage: photoImage
                    )
                } label: {
                    Text("保存")
                        .font(.subheadline.weight(.semibold))
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
            }
        }
        .confirmationDialog(
            "この編集内容を下書きに保存しますか？",
            isPresented: $showBackConfirmation,
            titleVisibility: .visible
        ) {
            Button("下書き保存") {
                // TODO: SwiftData下書き保存を接続するまでは、保存済みと誤認される仮挙動を入れない。
                showDraftUnavailableAlert = true
            }

            Button("破棄して戻る", role: .destructive) {
                dismiss()
            }

            Button("編集を続ける", role: .cancel) {}
        } message: {
            Text("下書き保存は明示操作のみです。")
        }
        .alert("まだ下書き保存できません", isPresented: $showDraftUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("現時点では下書きは保存されません。")
        }
        .scrollDismissesKeyboard(.interactively)
        // TODO: 写真フォルダ保存、共有、SwiftData下書き保存はPhase 2以降で接続する。
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
                MemoriesPillTab(title: tab.title, isSelected: selectedTab == tab) {
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
                Text("文字項目")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textSub)

                HStack(spacing: 6) {
                    ForEach(TextEditTarget.allCases) { target in
                        SubItemChip(
                            title: target.title,
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
                    Label(target.editorTitle, systemImage: target.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textMain)

                    Spacer()

                    CompactVisibilityToggle(isOn: visibilityBinding(for: target))
                }

                Text(target.hint)
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
            TextField(target.placeholder, text: text)
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

                Text("\(text.wrappedValue.count) / \(target.characterLimit) 文字目安")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textSub)
            }
        }
    }

    private var dateEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                ForEach(CardDateMode.allCases) { mode in
                    SubItemChip(
                        title: mode.displayName,
                        isSelected: editState.dateMode == mode
                    ) {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            editState.dateMode = mode
                            normalizeDateRange()
                        }
                    }
                }

                Spacer()

                Text(editState.displayDateText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textSub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if editState.dateMode == .single {
                compactDatePicker(title: "日付", selection: selectedDateBinding)
            } else if editState.dateMode == .range {
                HStack(spacing: 8) {
                    compactDatePicker(title: "開始", selection: startDateBinding)
                    compactDatePicker(title: "終了", selection: endDateBinding)
                }
            } else {
                VStack(spacing: 7) {
                    TextField("Spring 2026 / First Cafe Day / Today", text: $editState.customDateText)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MemoriesTheme.textMain)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(MemoriesTheme.card.opacity(0.68))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(MemoriesTheme.border.opacity(0.82), lineWidth: 1)
                        }

                    HStack {
                        Spacer()

                        Text("\(editState.customDateText.count) / 30 文字目安")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(MemoriesTheme.textSub)
                    }
                }
            }
        }
    }

    private func compactDatePicker(title: String, selection: Binding<Date>) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MemoriesTheme.textSub)

            DatePicker(title, selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(MemoriesTheme.accentDeep)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(MemoriesTheme.card.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MemoriesTheme.border.opacity(0.72), lineWidth: 1)
        }
    }

    private var iconTab: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                CompactPanelChip(
                    title: "テーマ",
                    systemImage: "pawprint",
                    isSelected: selectedIconSection == .theme
                ) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedIconSection = .theme
                    }
                }

                CompactPanelChip(
                    title: "天気",
                    systemImage: "sun.max",
                    isSelected: selectedIconSection == .weather
                ) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedIconSection = .weather
                    }
                }
            }

            HStack(spacing: 10) {
                Label(selectedIconSection.title, systemImage: selectedIconSection.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)

                Spacer()

                CompactVisibilityToggle(isOn: iconVisibilityBinding)
            }

            if selectedIconSection == .theme {
                LazyVGrid(columns: iconColumns(count: 5), spacing: 7) {
                    ForEach(ThemeIconType.allCases) { icon in
                        CompactIconOptionButton(
                            title: icon.displayName.ja,
                            systemImage: icon.symbolName,
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
                            title: weather.editorDisplayName,
                            systemImage: weather.symbolName ?? "minus.circle",
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
                    title: "フォント",
                    systemImage: "textformat",
                    isSelected: selectedAppearanceSection == .font
                ) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedAppearanceSection = .font
                    }
                }

                CompactPanelChip(
                    title: "色",
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
                            title: colorOption.displayName,
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
        editState != initialEditState
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

    private func iconColumns(count: Int) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 7), count: count)
    }

    private func editorPanelHeight(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.36, 252), size.height * 0.4)
    }
}

private enum EditorPanelTab: CaseIterable, Identifiable {
    case text
    case icon
    case appearance
    case position

    var id: Self { self }

    var title: String {
        switch self {
        case .text:
            return "文字"
        case .icon:
            return "アイコン"
        case .appearance:
            return "見た目"
        case .position:
            return "配置"
        }
    }
}

private enum TextEditTarget: CaseIterable, Identifiable {
    case main
    case sub
    case location
    case date

    var id: Self { self }

    var title: String {
        switch self {
        case .main:
            return "メイン"
        case .sub:
            return "サブ"
        case .location:
            return "場所"
        case .date:
            return "日付"
        }
    }

    var editorTitle: String {
        switch self {
        case .main:
            return "メインテキスト"
        case .sub:
            return "サブテキスト"
        case .location:
            return "場所"
        case .date:
            return "日付"
        }
    }

    var placeholder: String {
        switch self {
        case .main:
            return "My Pet / 今日の散歩 / Cafe Day"
        case .sub:
            return "犬種・猫種 / 年齢 / 今日のテーマ"
        case .location:
            return "Park / Cafe / Home"
        case .date:
            return "2026.06.17"
        }
    }

    var hint: String {
        switch self {
        case .main:
            return "名前や、写真のタイトル"
        case .sub:
            return "写真の詳細"
        case .location:
            return "写真の場所やシーン"
        case .date:
            return "写真の日付や期間"
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

    var title: String {
        switch self {
        case .theme:
            return "テーマアイコン"
        case .weather:
            return "天気アイコン"
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
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text("表示")
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
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))

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

                Text(position.displayName)
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
    var editorDisplayName: String {
        switch self {
        case .none:
            return "未選択"
        default:
            return displayName.ja
        }
    }
}

#Preview {
    NavigationStack {
        EditorView(template: .previewPetLifelog)
    }
}
