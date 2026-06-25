import PhotosUI
import SwiftUI
import UIKit

#if canImport(WidgetKit)
import WidgetKit
#endif

struct PetCalendarHomeView: View {
    var openTodayEditorOnAppear = false

    @EnvironmentObject private var appState: MemoriesAppState
    @State private var selectedMonth = PetCalendarDateRules.monthStart(for: Date())
    @State private var entries: [PetCalendarDayEntry] = []
    @State private var selectedDay: PetCalendarIdentifiedDate?
    @State private var showPreview = false
    @State private var showHelp = false
    @State private var didOpenInitialTodayEditor = false
    @State private var repositoryError: String?

    private var repository: PetCalendarRepository? {
        try? PetCalendarRepository()
    }

    var body: some View {
        ZStack {
            MemoriesTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let repositoryError {
                        Text(repositoryError)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(MemoriesTheme.textSub)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(MemoriesTheme.card.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    todayCTA

                    PetCalendarMonthView(
                        month: selectedMonth,
                        entries: entries,
                        displayLanguage: appState.petCalendarDisplayLanguage,
                        repository: repository,
                        onSelectDate: { date in
                            selectedDay = PetCalendarIdentifiedDate(date: date)
                        }
                    )

                    actionGrid
                }
                .padding(20)
                .frame(maxWidth: MemoriesLayoutMetrics.settingsMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(appState.t("calendar.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            reloadEntries()
            openTodayEditorIfNeeded()
        }
        .onChange(of: appState.petCalendarDisplayLanguage) { _, _ in
            reloadEntries()
        }
        .onChange(of: appState.entitlementRefreshID) { _, _ in
            reloadEntries()
        }
        .navigationDestination(item: $selectedDay) { value in
            PetCalendarDayEditorView(date: value.date) {
                reloadEntries()
            }
        }
        .navigationDestination(isPresented: $showPreview) {
            PetCalendarPreviewView(month: selectedMonth)
        }
        .navigationDestination(isPresented: $showHelp) {
            PetCalendarHelpView()
        }
    }

    private var header: some View {
        MemoriesGlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Button {
                        moveMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.semibold))
                            .frame(width: 42, height: 42)
                            .foregroundStyle(MemoriesTheme.accentDeep)
                            .background(MemoriesTheme.subBackground.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Text(PetCalendarDateRules.monthTitle(for: selectedMonth, language: appState.petCalendarDisplayLanguage))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MemoriesTheme.textMain)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Button {
                        moveMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.headline.weight(.semibold))
                            .frame(width: 42, height: 42)
                            .foregroundStyle(MemoriesTheme.accentDeep)
                            .background(MemoriesTheme.subBackground.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    summaryPill(
                        title: String(format: appState.t("calendar.registeredThisMonth"), summary.registeredCount),
                        systemImage: "photo.stack"
                    )
                    summaryPill(
                        title: String(format: appState.t("calendar.streak"), summary.currentStreak),
                        systemImage: "flame"
                    )
                }

                Picker(appState.t("calendar.displayLanguage"), selection: $appState.petCalendarDisplayLanguage) {
                    ForEach(PetCalendarDisplayLanguage.allCases) { language in
                        Text(language.displayName(in: appState.resolvedLanguage)).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
        }
    }

    private var todayCTA: some View {
        let hasToday = entries.contains { $0.id == PetCalendarDateRules.id(for: Date()) }
        return MemoriesPrimaryButton(
            hasToday ? appState.t("calendar.editToday") : appState.t("calendar.addToday"),
            systemImage: hasToday ? "square.and.pencil" : "plus"
        ) {
            selectedDay = PetCalendarIdentifiedDate(date: Date())
        }
    }

    private var actionGrid: some View {
        VStack(spacing: 10) {
            Button {
                showPreview = true
            } label: {
                HomeActionRow(title: appState.t("calendar.preview"), systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.plain)

            Button {
                showHelp = true
            } label: {
                HomeActionRow(title: appState.t("calendar.help"), systemImage: "questionmark.circle")
            }
            .buttonStyle(.plain)
        }
    }

    private var summary: PetCalendarMonthSummary {
        PetCalendarDateRules.summary(entries: entries, month: selectedMonth)
    }

    private func summaryPill(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(MemoriesTheme.textMain)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .background(MemoriesTheme.subBackground.opacity(0.68))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func moveMonth(by value: Int) {
        let calendar = PetCalendarDateRules.gregorianCalendar()
        selectedMonth = calendar.date(byAdding: .month, value: value, to: selectedMonth) ?? selectedMonth
        reloadEntries()
    }

    private func reloadEntries() {
        guard let repository else {
            repositoryError = PetCalendarRepositoryError.appGroupContainerUnavailable.localizedDescription
            return
        }
        repositoryError = nil
        entries = repository.loadEntries()
        try? repository.writeWidgetSnapshot(
            entries: entries,
            selectedMonth: selectedMonth,
            displayLanguage: appState.petCalendarDisplayLanguage,
            showsBranding: showsWidgetBranding
        )
        reloadWidgetTimelines()
    }

    private var showsWidgetBranding: Bool {
        !appState.watermarkPolicy().snapshot.hasUnlimitedAccess
    }

    private func openTodayEditorIfNeeded() {
        guard openTodayEditorOnAppear, !didOpenInitialTodayEditor else {
            return
        }
        didOpenInitialTodayEditor = true
        DispatchQueue.main.async {
            selectedDay = PetCalendarIdentifiedDate(date: Date())
        }
    }
}

struct PetCalendarMonthView: View {
    let month: Date
    let entries: [PetCalendarDayEntry]
    let displayLanguage: PetCalendarDisplayLanguage
    let repository: PetCalendarRepository?
    let onSelectDate: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        PetCalendarGlassPanel {
            VStack(spacing: 8) {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(PetCalendarDateRules.weekdaySymbols(language: displayLanguage), id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MemoriesTheme.accentDeep)
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                    }

                    ForEach(cells) { cell in
                        PetCalendarDayCell(
                            cell: cell,
                            entry: entriesByID[cell.id],
                            thumbnail: thumbnail(for: entriesByID[cell.id])
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard cell.isInDisplayedMonth, !cell.isFuture else {
                                return
                            }
                            onSelectDate(cell.date)
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    private var cells: [PetCalendarMonthCell] {
        PetCalendarDateRules.monthGrid(for: month)
    }

    private var entriesByID: [String: PetCalendarDayEntry] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    }

    private func thumbnail(for entry: PetCalendarDayEntry?) -> UIImage? {
        guard let entry else {
            return nil
        }
        return repository?.thumbnail(for: entry)
    }
}

private struct PetCalendarDayCell: View {
    let cell: PetCalendarMonthCell
    let entry: PetCalendarDayEntry?
    let thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(background)
                .overlay {
                    if let thumbnail {
                        PetCalendarPlacedImage(
                            image: thumbnail,
                            placement: entry?.photoPlacement ?? .default
                        )
                            .overlay(Color.black.opacity(0.12))
                    } else if cell.isInDisplayedMonth {
                        PetCalendarPawShape()
                            .fill(MemoriesTheme.accentDeep.opacity(cell.isFuture ? 0.06 : 0.14))
                            .frame(width: 28, height: 28)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(registeredFrameColor, lineWidth: entry == nil ? 1 : 1.5)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(cell.isToday ? MemoriesTheme.accentDeep : Color.clear, lineWidth: 2)
                }

            PetCalendarDateGuideLayer(
                dayNumber: cell.dayNumber,
                defaultDateColor: numberColor,
                isToday: false,
                usesPhotoBackground: thumbnail != nil
            )
        }
        .aspectRatio(PetCalendarCellMetrics.aspectRatio, contentMode: .fit)
        .opacity(cell.isFuture ? 0.44 : 1)
    }

    private var background: Color {
        if !cell.isInDisplayedMonth {
            return Color(hex: "#F7FBFF").opacity(0.16)
        }
        return entry == nil ? Color(hex: "#E7F0F8").opacity(cell.isFuture ? 0.32 : 0.56) : MemoriesTheme.card.opacity(0.82)
    }

    private var numberColor: Color {
        if !cell.isInDisplayedMonth {
            return MemoriesTheme.textSub.opacity(0.25)
        }
        return thumbnail == nil ? MemoriesTheme.textMain : .white
    }

    private var registeredFrameColor: Color {
        if entry != nil {
            return PetCalendarCellMetrics.registeredFrame
        }
        return MemoriesTheme.border.opacity(cell.isInDisplayedMonth ? 0.72 : 0.28)
    }
}

private enum PetCalendarCellMetrics {
    static let aspectRatio: CGFloat = 0.78
    static let cornerRadius: CGFloat = 8
    static let dateFontRatio: CGFloat = 0.16
    static let dateMinimumFont: CGFloat = 12
    static let dateMaximumFont: CGFloat = 18
    static let dateInsetRatio: CGFloat = 0.06
    static let dateMinimumInset: CGFloat = 5
    static let registeredFrame = Color(hex: "#93C8ED")
}

private struct PetCalendarDateGuideLayer: View {
    let dayNumber: Int
    let defaultDateColor: Color
    let isToday: Bool
    let usesPhotoBackground: Bool

    var body: some View {
        GeometryReader { proxy in
            let minSide = min(proxy.size.width, proxy.size.height)
            let inset = max(minSide * PetCalendarCellMetrics.dateInsetRatio, PetCalendarCellMetrics.dateMinimumInset)
            let dateTop = inset
            let fontSize = min(
                max(minSide * PetCalendarCellMetrics.dateFontRatio, PetCalendarCellMetrics.dateMinimumFont),
                PetCalendarCellMetrics.dateMaximumFont
            )

            ZStack(alignment: .topLeading) {
                if isToday {
                    RoundedRectangle(cornerRadius: PetCalendarCellMetrics.cornerRadius, style: .continuous)
                        .stroke(MemoriesTheme.accentDeep.opacity(0.92), lineWidth: 2)
                        .padding(2)
                }

                Text("\(dayNumber)")
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(defaultDateColor)
                    .shadow(color: usesPhotoBackground ? Color.black.opacity(0.30) : .clear, radius: 2, y: 1)
                    .position(x: inset + 6, y: dateTop + 8)
            }
        }
    }
}

private struct PetCalendarGlassPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(.ultraThinMaterial)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.34),
                        Color(hex: "#EAF5FF").opacity(0.24)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.68),
                                MemoriesTheme.border.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: MemoriesTheme.accentDeep.opacity(0.10), radius: 24, y: 12)
    }
}

private struct PetCalendarPlacedImage: View {
    let image: UIImage
    let placement: PhotoPlacement

    var body: some View {
        GeometryReader { proxy in
            let frameRect = CGRect(origin: .zero, size: proxy.size)
            let drawRect = PhotoPlacementLayout.drawRect(
                imageSize: image.size,
                frameRect: frameRect,
                placement: placement
            )

            Image(uiImage: image)
                .resizable()
                .frame(width: drawRect.width, height: drawRect.height)
                .position(x: drawRect.midX, y: drawRect.midY)
        }
        .clipped()
    }
}

private struct PetCalendarPhotoPlacementPreview: View {
    let image: UIImage?
    let date: Date
    let isToday: Bool
    @Binding var placement: PhotoPlacement
    @Binding var dragStartPlacement: PhotoPlacement?
    @Binding var magnifyStartPlacement: PhotoPlacement?

    @EnvironmentObject private var appState: MemoriesAppState

    var body: some View {
        GeometryReader { proxy in
            let frameRect = CGRect(origin: .zero, size: proxy.size)

            ZStack {
                RoundedRectangle(cornerRadius: PetCalendarCellMetrics.cornerRadius, style: .continuous)
                    .fill(Color(hex: "#E7F0F8").opacity(0.62))

                if let image {
                    let drawRect = PhotoPlacementLayout.drawRect(
                        imageSize: image.size,
                        frameRect: frameRect,
                        placement: placement
                    )

                    Image(uiImage: image)
                        .resizable()
                        .frame(width: drawRect.width, height: drawRect.height)
                        .position(x: drawRect.midX, y: drawRect.midY)
                } else {
                    VStack(spacing: 12) {
                        PetCalendarPawShape()
                            .fill(MemoriesTheme.accentDeep.opacity(0.14))
                            .frame(width: 78, height: 78)
                        Text(appState.t("calendar.choosePhoto"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(MemoriesTheme.textSub)
                    }
                }

                PetCalendarDateGuideLayer(
                    dayNumber: dayNumber,
                    defaultDateColor: image == nil ? MemoriesTheme.textMain : .white,
                    isToday: isToday,
                    usesPhotoBackground: image != nil
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: PetCalendarCellMetrics.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PetCalendarCellMetrics.cornerRadius, style: .continuous)
                    .stroke(image == nil ? MemoriesTheme.border.opacity(0.72) : PetCalendarCellMetrics.registeredFrame, lineWidth: image == nil ? 1 : 1.8)
            }
            .gesture(adjustmentGesture(frameRect: frameRect))
        }
        .aspectRatio(PetCalendarCellMetrics.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private func adjustmentGesture(frameRect: CGRect) -> some Gesture {
        let drag = DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard let image else {
                    return
                }
                let start = dragStartPlacement ?? placement
                dragStartPlacement = start
                placement = PhotoPlacementLayout.placement(
                    from: start,
                    applyingDrag: value.translation,
                    imageSize: image.size,
                    frameRect: frameRect
                )
            }
            .onEnded { _ in
                dragStartPlacement = nil
            }

        let magnification = MagnificationGesture()
            .onChanged { value in
                guard image != nil else {
                    return
                }
                let start = magnifyStartPlacement ?? placement
                magnifyStartPlacement = start
                placement = PhotoPlacement(
                    scale: start.scale * Double(value),
                    offsetX: start.offsetX,
                    offsetY: start.offsetY
                ).clamped
            }
            .onEnded { _ in
                magnifyStartPlacement = nil
            }

        return drag.simultaneously(with: magnification)
    }

    private var dayNumber: Int {
        PetCalendarDateRules.gregorianCalendar().component(.day, from: date)
    }
}

struct PetCalendarDayEditorView: View {
    let date: Date
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: MemoriesAppState
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedNewImage: UIImage?
    @State private var photoPlacement: PhotoPlacement = .default
    @State private var dragStartPlacement: PhotoPlacement?
    @State private var magnifyStartPlacement: PhotoPlacement?
    @State private var registrationDate: Date
    @State private var existingEntry: PetCalendarDayEntry?
    @State private var pendingPhoto: PendingPetCalendarPhoto?
    @State private var showDateMismatch = false
    @State private var showReplaceConfirmation = false
    @State private var alert: PetCalendarAlert?
    @State private var isProcessing = false

    init(date: Date, onSaved: @escaping () -> Void = {}) {
        self.date = date
        self.onSaved = onSaved
        _registrationDate = State(initialValue: PetCalendarDateRules.startOfDay(for: date))
    }

    private var repository: PetCalendarRepository? {
        try? PetCalendarRepository()
    }

    var body: some View {
        ZStack {
            MemoriesTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    imagePreview
                    editorPanel
                }
                .padding(20)
                .frame(maxWidth: MemoriesLayoutMetrics.settingsMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(PetCalendarDateRules.shortDateTitle(for: registrationDate, language: appState.petCalendarDisplayLanguage))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadExisting)
        .task(id: selectedPhotoItem) {
            await loadSelectedPhoto()
        }
        .confirmationDialog(appState.t("calendar.photoDateMismatchTitle"), isPresented: $showDateMismatch, presenting: pendingPhoto) { pending in
            Button(String(format: appState.t("calendar.registerTargetDate"), PetCalendarDateRules.shortDateTitle(for: registrationDate, language: appState.petCalendarDisplayLanguage))) {
                applyPendingPhoto(pending, date: registrationDate)
            }

            if let capturedAt = pending.capturedAt, PetCalendarDateRules.canRegisterPhoto(for: capturedAt) {
                Button(String(format: appState.t("calendar.registerCapturedDate"), PetCalendarDateRules.shortDateTitle(for: capturedAt, language: appState.petCalendarDisplayLanguage))) {
                    applyPendingPhoto(pending, date: capturedAt)
                }
            }

            Button(appState.t("common.cancel"), role: .cancel) {}
        } message: { pending in
            if let capturedAt = pending.capturedAt {
                Text(String(
                    format: appState.t("calendar.photoDateMismatchMessage"),
                    PetCalendarDateRules.shortDateTitle(for: capturedAt, language: appState.petCalendarDisplayLanguage),
                    PetCalendarDateRules.shortDateTitle(for: registrationDate, language: appState.petCalendarDisplayLanguage)
                ))
            }
        }
        .alert(appState.t("calendar.replaceTitle"), isPresented: $showReplaceConfirmation) {
            Button(appState.t("calendar.replace"), role: .destructive) {
                saveEntry(allowReplace: true)
            }
            Button(appState.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(appState.t("calendar.replaceMessage"))
        }
        .alert(item: $alert) { alert in
            Alert(title: Text(alert.title), message: alert.message.map(Text.init), dismissButton: .default(Text(appState.t("common.ok"))))
        }
    }

    private var imagePreview: some View {
        MemoriesGlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.t("calendar.adjustPhoto"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textMain)
                    Text(appState.t("calendar.adjustPhotoHint"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MemoriesTheme.textSub)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PetCalendarPhotoPlacementPreview(
                    image: selectedImage,
                    date: registrationDate,
                    isToday: PetCalendarDateRules.id(for: registrationDate) == PetCalendarDateRules.id(for: Date()),
                    placement: $photoPlacement,
                    dragStartPlacement: $dragStartPlacement,
                    magnifyStartPlacement: $magnifyStartPlacement
                )

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        photoPlacement = .default
                    }
                } label: {
                    Label(appState.t("calendar.resetPhotoPlacement"), systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.accentDeep)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(MemoriesTheme.subBackground.opacity(0.62))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(selectedImage == nil)
                .opacity(selectedImage == nil ? 0.45 : 1)
            }
            .padding(12)
        }
    }

    private var editorPanel: some View {
        let choosePhotoTitle = appState.t("calendar.choosePhoto")

        return MemoriesGlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    MemoriesPrimaryButtonLabel(title: choosePhotoTitle, systemImage: "photo")
                }
                .buttonStyle(.plain)

                DatePicker(
                    "",
                    selection: $registrationDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()

                HStack(spacing: 10) {
                    MemoriesPrimaryButton(appState.t("calendar.saveEntry"), systemImage: "checkmark") {
                        requestSave()
                    }
                    .disabled(isProcessing)

                    if existingEntry != nil {
                        MemoriesSecondaryButton(appState.t("calendar.deleteEntry"), systemImage: "trash") {
                            deleteEntry()
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func loadExisting() {
        guard let repository else {
            return
        }
        existingEntry = repository.entry(for: registrationDate)
        photoPlacement = existingEntry?.photoPlacement ?? .default
        if let existingEntry {
            selectedImage = repository.image(for: existingEntry)
        }
    }

    @MainActor
    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else {
            return
        }
        isProcessing = true
        defer {
            isProcessing = false
            self.selectedPhotoItem = nil
        }

        do {
            guard
                let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                alert = PetCalendarAlert(title: appState.t("calendar.saveFailed"), message: appState.t("home.photoLoadFailed"))
                return
            }

            let metadata = await PhotoMetadataReader().metadata(from: data, allowsLocationSuggestion: false)
            let pending = PendingPetCalendarPhoto(image: image, capturedAt: metadata.capturedAt)
            if let capturedAt = metadata.capturedAt,
               PetCalendarDateRules.id(for: capturedAt) != PetCalendarDateRules.id(for: registrationDate) {
                pendingPhoto = pending
                showDateMismatch = true
            } else {
                applyPendingPhoto(pending, date: registrationDate)
            }
        } catch {
            alert = PetCalendarAlert(title: appState.t("calendar.saveFailed"), message: error.localizedDescription)
        }
    }

    private func applyPendingPhoto(_ pending: PendingPetCalendarPhoto, date: Date) {
        registrationDate = PetCalendarDateRules.startOfDay(for: date)
        selectedImage = pending.image
        selectedNewImage = pending.image
        photoPlacement = .default
        existingEntry = repository?.entry(for: registrationDate)
    }

    private func requestSave() {
        guard selectedImage != nil else {
            alert = PetCalendarAlert(title: appState.t("calendar.saveFailed"), message: appState.t("calendar.noPhoto"))
            return
        }
        guard PetCalendarDateRules.canRegisterPhoto(for: registrationDate) else {
            alert = PetCalendarAlert(title: appState.t("calendar.saveFailed"), message: appState.t("calendar.futureDate"))
            return
        }
        if existingEntry != nil && selectedNewImage != nil {
            showReplaceConfirmation = true
            return
        }
        saveEntry(allowReplace: existingEntry != nil)
    }

    private func saveEntry(allowReplace: Bool) {
        guard let repository else {
            alert = PetCalendarAlert(title: appState.t("calendar.saveFailed"), message: PetCalendarRepositoryError.appGroupContainerUnavailable.localizedDescription)
            return
        }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let image = selectedNewImage ?? selectedImage
            _ = try repository.save(
                image: image,
                caption: "",
                photoPlacement: photoPlacement,
                for: registrationDate,
                allowReplace: allowReplace
            )
            try? repository.writeWidgetSnapshot(
                entries: repository.loadEntries(),
                selectedMonth: registrationDate,
                displayLanguage: appState.petCalendarDisplayLanguage,
                showsBranding: !appState.watermarkPolicy().snapshot.hasUnlimitedAccess
            )
            reloadWidgetTimelines()
            onSaved()
            dismiss()
        } catch {
            alert = PetCalendarAlert(title: appState.t("calendar.saveFailed"), message: error.localizedDescription)
        }
    }

    private func deleteEntry() {
        guard let repository else {
            return
        }
        do {
            try repository.deleteEntry(for: registrationDate)
            reloadWidgetTimelines()
            onSaved()
            dismiss()
        } catch {
            alert = PetCalendarAlert(title: appState.t("calendar.saveFailed"), message: error.localizedDescription)
        }
    }
}

struct PetCalendarImportView: View {
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: MemoriesAppState
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var groups: [PetCalendarImportGroup] = []
    @State private var alert: PetCalendarAlert?
    @State private var isProcessing = false

    private var repository: PetCalendarRepository? {
        try? PetCalendarRepository()
    }

    var body: some View {
        let batchAddTitle = appState.t("calendar.batchAdd")

        ZStack {
            MemoriesTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        MemoriesPrimaryButtonLabel(title: batchAddTitle, systemImage: "photo.on.rectangle.angled")
                    }
                    .buttonStyle(.plain)
                    .photosPicker(
                        isPresented: $showPhotoPicker,
                        selection: $selectedItems,
                        matching: .images,
                        photoLibrary: .shared()
                    )

                    if isProcessing {
                        ProgressView()
                            .tint(MemoriesTheme.accentDeep)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach($groups) { $group in
                        PetCalendarImportGroupView(group: $group)
                    }

                    if !plannedEntries.isEmpty {
                        MemoriesGlassPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(appState.t("calendar.registrationPlan"))
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(MemoriesTheme.textMain)

                                ForEach(plannedEntries) { plan in
                                    HStack {
                                        Text(PetCalendarDateRules.shortDateTitle(for: plan.date, language: appState.petCalendarDisplayLanguage))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(MemoriesTheme.textMain)
                                        Spacer()
                                        Text(plan.replacesExisting ? appState.t("calendar.replace") : appState.t("calendar.saveEntry"))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(MemoriesTheme.textSub)
                                    }
                                }
                            }
                            .padding(14)
                        }
                    }

                    if !groups.isEmpty {
                        MemoriesPrimaryButton(appState.t("calendar.saveEntry"), systemImage: "checkmark") {
                            savePlannedEntries()
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: MemoriesLayoutMetrics.settingsMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(appState.t("calendar.batchAdd"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedItems) {
            await loadSelectedItems()
        }
        .alert(item: $alert) { alert in
            Alert(title: Text(alert.title), message: alert.message.map(Text.init), dismissButton: .default(Text(appState.t("common.ok"))))
        }
    }

    private var plannedEntries: [PetCalendarImportPlannedEntry] {
        PetCalendarImportPlanner().plannedEntries(from: groups)
    }

    @MainActor
    private func loadSelectedItems() async {
        guard !selectedItems.isEmpty else {
            return
        }

        isProcessing = true
        defer {
            isProcessing = false
            selectedItems = []
        }

        do {
            var payloads: [(data: Data, image: UIImage)] = []
            for item in selectedItems {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    payloads.append((data, image))
                }
            }

            let planner = PetCalendarImportPlanner()
            let candidates = await planner.makeCandidates(from: payloads)
            groups = planner.groups(
                for: candidates,
                existingEntries: repository?.loadEntries() ?? []
            )
        } catch {
            alert = PetCalendarAlert(title: appState.t("calendar.saveFailed"), message: error.localizedDescription)
        }
    }

    private func savePlannedEntries() {
        guard let repository else {
            alert = PetCalendarAlert(title: appState.t("calendar.saveFailed"), message: PetCalendarRepositoryError.appGroupContainerUnavailable.localizedDescription)
            return
        }

        let planner = PetCalendarImportPlanner()
        let plans = planner.plannedEntries(from: groups)
        guard !plans.isEmpty else {
            alert = PetCalendarAlert(title: appState.t("calendar.saveFailed"), message: appState.t("calendar.batchEmpty"))
            return
        }

        do {
            for plan in plans {
                _ = try repository.save(
                    image: plan.candidate.image,
                    caption: "",
                    for: plan.date,
                    allowReplace: plan.replacesExisting
                )
            }
            reloadWidgetTimelines()
            onSaved()
            dismiss()
        } catch {
            alert = PetCalendarAlert(title: appState.t("calendar.saveFailed"), message: error.localizedDescription)
        }
    }
}

private struct PetCalendarImportGroupView: View {
    @Binding var group: PetCalendarImportGroup
    @EnvironmentObject private var appState: MemoriesAppState

    var body: some View {
        MemoriesGlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textMain)
                    Spacer()
                    if group.requiresUserDecision {
                        Text(appState.t("calendar.registrationPlan"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MemoriesTheme.textSub)
                    }
                }

                if group.date == nil {
                    DatePicker(
                        appState.t("calendar.manualDate"),
                        selection: manualDateBinding,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                }

                if group.isFutureDate {
                    Text(appState.t("calendar.batchFuture"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }

                if group.candidates.count > 1 {
                    Picker(appState.t("calendar.chooseRepresentative"), selection: Binding(
                        get: { group.selectedCandidateID ?? group.candidates.first?.id },
                        set: { group.selectedCandidateID = $0 }
                    )) {
                        ForEach(group.candidates) { candidate in
                            Text(candidateTitle(candidate)).tag(Optional(candidate.id))
                        }
                    }
                    .pickerStyle(.menu)
                }

                if let existingEntry = group.existingEntry {
                    Picker(appState.t("calendar.replaceTitle"), selection: $group.action) {
                        Text(appState.t("calendar.keepExisting")).tag(PetCalendarImportGroupAction.keepExisting)
                        Text(appState.t("calendar.replace")).tag(PetCalendarImportGroupAction.replaceExisting)
                    }
                    .pickerStyle(.segmented)

                    Text(existingEntry.id)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MemoriesTheme.textSub)
                }
            }
            .padding(14)
        }
    }

    private var title: String {
        guard let date = group.date else {
            return appState.t("calendar.batchNeedsDate")
        }
        return PetCalendarDateRules.shortDateTitle(for: date, language: appState.petCalendarDisplayLanguage)
    }

    private var manualDateBinding: Binding<Date> {
        Binding {
            group.date ?? Date()
        } set: { newValue in
            group.date = PetCalendarDateRules.startOfDay(for: newValue)
            group.isFutureDate = !PetCalendarDateRules.canRegisterPhoto(for: newValue)
            if var first = group.candidates.first {
                first.manualDate = newValue
                group.candidates[0] = first
            }
        }
    }

    private func candidateTitle(_ candidate: PetCalendarImportCandidate) -> String {
        if let capturedAt = candidate.capturedAt {
            return PetCalendarDateRules.shortDateTitle(for: capturedAt, language: appState.petCalendarDisplayLanguage)
        }
        return appState.t("calendar.manualDate")
    }
}

struct PetCalendarPreviewView: View {
    let month: Date

    @EnvironmentObject private var appState: MemoriesAppState
    @State private var renderedImage: UIImage?
    @State private var watermarkOption: WatermarkExportOption = .withWatermark
    @State private var hasAppliedInitialOption = false
    @State private var hasUserSelectedOption = false
    @State private var alert: PetCalendarAlert?
    @State private var shareItem: ShareImageItem?
    @State private var isProcessing = false
    @State private var showWatermarklessShareConfirmation = false

    private var repository: PetCalendarRepository? {
        try? PetCalendarRepository()
    }

    var body: some View {
        ZStack {
            MemoriesTheme.background.ignoresSafeArea()
            VStack(spacing: 12) {
                previewImage
                actionPanel
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: MemoriesLayoutMetrics.previewMaxWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(appState.t("calendar.outputTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            applyInitialWatermarkOptionIfNeeded()
            renderCalendar()
        }
        .onChange(of: watermarkOption) { _, _ in
            renderedImage = nil
            renderCalendar()
        }
        .onChange(of: appState.entitlementRefreshID) { _, _ in
            applyInitialWatermarkOptionIfNeeded()
        }
        .alert(item: $alert) { alert in
            Alert(title: Text(alert.title), message: alert.message.map(Text.init), dismissButton: .default(Text(appState.t("common.ok"))))
        }
        .alert(appState.t("preview.confirmShareTitle"), isPresented: $showWatermarklessShareConfirmation) {
            Button(appState.t("preview.shareAction")) {
                openShareSheet(consumesFreeWatermarkAllowance: true)
            }
            Button(appState.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(appState.t("preview.confirmShareMessage"))
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.image]) { completed, error in
                handleShareCompletion(for: item, completed: completed, error: error)
            }
        }
    }

    private var previewImage: some View {
        Group {
            if let renderedImage {
                Image(uiImage: renderedImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(MemoriesTheme.border.opacity(0.86), lineWidth: 1)
                    }
                    .padding(20)
            } else {
                ProgressView(appState.t("preview.creating"))
                    .tint(MemoriesTheme.accentDeep)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var actionPanel: some View {
        MemoriesGlassPanel {
            VStack(spacing: 10) {
                watermarkPicker

                HStack(spacing: 10) {
                    MemoriesPrimaryButton(appState.t("calendar.saveCalendar"), systemImage: "square.and.arrow.down") {
                        Task { await saveToPhotoLibrary() }
                    }
                    .disabled(renderedImage == nil || isProcessing)

                    MemoriesSecondaryButton(appState.t("calendar.shareCalendar"), systemImage: "square.and.arrow.up") {
                        prepareShare()
                    }
                    .disabled(renderedImage == nil || isProcessing)
                }
            }
            .padding(12)
        }
    }

    private var watermarkPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.t("preview.watermark"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(MemoriesTheme.textSub)

            HStack(spacing: 8) {
                CalendarWatermarkButton(
                    title: appState.t("calendar.withWatermark"),
                    isSelected: watermarkOption == .withWatermark,
                    isEnabled: true
                ) {
                    selectWatermarkOption(.withWatermark)
                }

                CalendarWatermarkButton(
                    title: appState.t("calendar.withoutWatermark"),
                    isSelected: watermarkOption == .withoutWatermark,
                    isEnabled: CalendarWatermarkExportRules.canSelect(.withoutWatermark, snapshot: watermarkAccessSnapshot)
                ) {
                    selectWatermarkOption(.withoutWatermark)
                }
            }
        }
        .padding(12)
        .background(MemoriesTheme.card.opacity(0.48))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func renderCalendar() {
        guard let repository else {
            alert = PetCalendarAlert(title: appState.t("preview.renderFailed"), message: PetCalendarRepositoryError.appGroupContainerUnavailable.localizedDescription)
            return
        }

        let entries = repository.loadEntries().map { entry in
            PetCalendarRenderEntry(
                date: entry.date,
                thumbnail: repository.image(for: entry) ?? repository.thumbnail(for: entry),
                photoPlacement: entry.photoPlacement
            )
        }
        renderedImage = PetCalendarRenderer().render(
            configuration: PetCalendarRenderConfiguration(
                month: month,
                entries: entries,
                displayLanguage: appState.petCalendarDisplayLanguage,
                watermarkMode: watermarkOption.watermarkMode
            )
        )
    }

    @MainActor
    private func saveToPhotoLibrary() async {
        guard ensureCanExportSelectedWatermark(), let image = preparedImage() else {
            return
        }
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await PhotoLibrarySaver().save(image)
            guard consumeAllowanceIfNeeded() else {
                alert = PetCalendarAlert(title: appState.t("preview.freeUpdateFailed"), message: appState.t("preview.todayUsed"))
                return
            }
            alert = PetCalendarAlert(title: appState.t("calendar.outputSaved"), message: nil)
        } catch {
            alert = PetCalendarAlert(title: appState.t("calendar.outputSaveFailed"), message: error.localizedDescription)
        }
    }

    private func prepareShare() {
        guard ensureCanExportSelectedWatermark() else {
            return
        }
        if CalendarWatermarkExportRules.shouldConsumeAllowance(afterSuccessfulOutput: watermarkOption, snapshot: watermarkAccessSnapshot) {
            showWatermarklessShareConfirmation = true
            return
        }
        openShareSheet(consumesFreeWatermarkAllowance: false)
    }

    private func openShareSheet(consumesFreeWatermarkAllowance: Bool) {
        guard let image = preparedImage() else {
            alert = PetCalendarAlert(title: appState.t("calendar.outputShareFailed"), message: appState.t("preview.imageGenerateFailed"))
            return
        }
        shareItem = ShareImageItem(image: image, consumesFreeWatermarkAllowance: consumesFreeWatermarkAllowance)
    }

    private func handleShareCompletion(for item: ShareImageItem, completed: Bool, error: Error?) {
        if let error {
            alert = PetCalendarAlert(title: appState.t("calendar.outputShareFailed"), message: error.localizedDescription)
            return
        }
        guard completed, item.consumesFreeWatermarkAllowance else {
            return
        }
        guard appState.watermarkPolicy().consumeIfNeeded(for: .withoutWatermark) else {
            alert = PetCalendarAlert(title: appState.t("preview.freeUpdateFailed"), message: appState.t("preview.todayUsed"))
            return
        }
        watermarkOption = .withWatermark
    }

    private func preparedImage() -> UIImage? {
        if let renderedImage {
            return renderedImage
        }
        renderCalendar()
        return renderedImage
    }

    private var watermarkAccessSnapshot: WatermarkAccessSnapshot {
        appState.watermarkPolicy().snapshot
    }

    private func selectWatermarkOption(_ option: WatermarkExportOption) {
        guard CalendarWatermarkExportRules.canSelect(option, snapshot: watermarkAccessSnapshot) else {
            alert = PetCalendarAlert(title: appState.t("preview.freeUsedTitle"), message: appState.t("preview.freeUsedMessage"))
            watermarkOption = .withWatermark
            return
        }
        hasUserSelectedOption = true
        watermarkOption = option
    }

    private func applyInitialWatermarkOptionIfNeeded() {
        guard !hasUserSelectedOption else {
            return
        }
        if !hasAppliedInitialOption || watermarkAccessSnapshot.hasUnlimitedAccess {
            watermarkOption = CalendarWatermarkExportRules.initialOption(for: watermarkAccessSnapshot)
            hasAppliedInitialOption = true
        }
    }

    private func ensureCanExportSelectedWatermark() -> Bool {
        guard CalendarWatermarkExportRules.canSelect(watermarkOption, snapshot: watermarkAccessSnapshot) else {
            alert = PetCalendarAlert(title: appState.t("preview.freeUsedTitle"), message: appState.t("preview.freeUsedMessage"))
            watermarkOption = .withWatermark
            return false
        }
        return true
    }

    private func consumeAllowanceIfNeeded() -> Bool {
        guard CalendarWatermarkExportRules.shouldConsumeAllowance(afterSuccessfulOutput: watermarkOption, snapshot: watermarkAccessSnapshot) else {
            return true
        }
        let didConsume = appState.watermarkPolicy().consumeIfNeeded(for: .withoutWatermark)
        if didConsume {
            watermarkOption = .withWatermark
        }
        return didConsume
    }
}

struct PetCalendarHelpView: View {
    @EnvironmentObject private var appState: MemoriesAppState

    var body: some View {
        ZStack {
            MemoriesTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    helpRow(systemImage: "rectangle.grid.2x2", text: appState.t("calendar.widgetHelpHome"))
                    helpRow(systemImage: "lock.rectangle", text: appState.t("calendar.widgetHelpLock"))
                    helpRow(systemImage: "plus.app", text: appState.t("calendar.widgetHelpAdd"))
                    helpRow(systemImage: "hand.tap", text: appState.t("calendar.widgetHelpTap"))
                }
                .padding(20)
                .frame(maxWidth: MemoriesLayoutMetrics.settingsMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(appState.t("calendar.widgetHelpTitle"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func helpRow(systemImage: String, text: String) -> some View {
        MemoriesGlassPanel {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.accentDeep)
                    .frame(width: 36, height: 36)
                    .background(MemoriesTheme.subBackground.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MemoriesTheme.textMain)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }
}

struct PetCalendarPawShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let side = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        let toe = side * 0.18
        let toeCenters = [
            CGPoint(x: origin.x + side * 0.24, y: origin.y + side * 0.28),
            CGPoint(x: origin.x + side * 0.42, y: origin.y + side * 0.20),
            CGPoint(x: origin.x + side * 0.58, y: origin.y + side * 0.20),
            CGPoint(x: origin.x + side * 0.76, y: origin.y + side * 0.28)
        ]
        for point in toeCenters {
            path.addEllipse(in: CGRect(x: point.x - toe / 2, y: point.y - toe / 2, width: toe, height: toe * 1.12))
        }
        path.addRoundedRect(in: CGRect(
            x: origin.x + side * 0.30,
            y: origin.y + side * 0.46,
            width: side * 0.40,
            height: side * 0.36
        ), cornerSize: CGSize(
            width: side * 0.18,
            height: side * 0.18
        ))
        return path
    }
}

private struct CalendarWatermarkButton: View {
    let title: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(isSelected ? .white : MemoriesTheme.accentDeep)
                .background(isSelected ? MemoriesTheme.accentDeep : MemoriesTheme.subBackground.opacity(0.54))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

private struct PetCalendarIdentifiedDate: Identifiable, Hashable {
    var date: Date
    var id: String { PetCalendarDateRules.id(for: date) }
}

private struct PendingPetCalendarPhoto: Identifiable {
    let id = UUID()
    var image: UIImage
    var capturedAt: Date?
}

private struct PetCalendarAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String?
}

private func reloadWidgetTimelines() {
    #if canImport(WidgetKit)
    if #available(iOS 14.0, *) {
        WidgetCenter.shared.reloadTimelines(ofKind: "MemoriesWidget")
    }
    #endif
}
