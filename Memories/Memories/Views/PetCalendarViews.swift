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
            PetCalendarAquaBackdrop().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let repositoryError {
                        Text(repositoryError)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(MemoriesTheme.textSub)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PetCalendarAquaSurface(cornerRadius: 8))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    calendarInstruction

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
                            .background(PetCalendarAquaSurface(cornerRadius: 8))
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
                            .background(PetCalendarAquaSurface(cornerRadius: 8))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
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

    private var calendarInstruction: some View {
        Label(appState.t("calendar.tapDateInstruction"), systemImage: "hand.tap")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MemoriesTheme.textMain)
            .lineLimit(2)
            .minimumScaleFactor(0.86)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PetCalendarAquaSurface(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        let monthCells = cells
        let rowCount = max(1, monthCells.count / 7)

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

                    ForEach(monthCells) { cell in
                        PetCalendarDayCell(
                            cell: cell,
                            entry: entriesByID[cell.id],
                            thumbnail: thumbnail(for: entriesByID[cell.id]),
                            rowCount: rowCount
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
    let rowCount: Int

    var body: some View {
        let overlayStyle = entry?.overlayStyle ?? .default

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.clear)
                .background {
                    PetCalendarAquaSurface(
                        cornerRadius: 8,
                        isDimmed: !cell.isInDisplayedMonth || cell.isFuture
                    )
                }
                .overlay {
                    if let thumbnail {
                        PetCalendarPlacedImage(
                            image: thumbnail,
                            placement: entry?.photoPlacement ?? .default
                        )
                            .overlay(Color.black.opacity(0.12))
                    } else if cell.isInDisplayedMonth {
                        if overlayStyle.effectiveWeatherIcon == nil {
                            PetCalendarPawShape()
                                .fill(MemoriesTheme.accentDeep.opacity(cell.isFuture ? 0.06 : 0.14))
                                .frame(width: 28, height: 28)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
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

            PetCalendarWeatherIconLayer(
                style: overlayStyle,
                usesPhotoBackground: thumbnail != nil
            )
        }
        .aspectRatio(PetCalendarCellMetrics.aspectRatio(forRowCount: rowCount), contentMode: .fit)
        .opacity(cell.isFuture ? 0.44 : 1)
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
    static let defaultAspectRatio = PetCalendarGridMetrics.defaultCellAspectRatio
    static let cornerRadius: CGFloat = 8
    static let dateFontRatio: CGFloat = 0.24
    static let dateMinimumFont: CGFloat = 11
    static let dateInsetRatio: CGFloat = 0.08
    static let dateMinimumInset: CGFloat = 4
    static let weatherIconRatio: CGFloat = 0.32
    static let weatherIconInsetRatio: CGFloat = 0.10
    static let weatherIconMinimumSize: CGFloat = 15
    static let weatherIconMinimumInset: CGFloat = 4
    static let registeredFrame = Color(hex: "#93C8ED")

    static func aspectRatio(forRowCount rowCount: Int) -> CGFloat {
        PetCalendarGridMetrics.cellAspectRatio(forRowCount: rowCount)
    }
}

private struct PetCalendarWeatherIconLayer: View {
    let style: PetCalendarOverlayStyle
    let usesPhotoBackground: Bool

    var body: some View {
        GeometryReader { proxy in
            if let icon = style.effectiveWeatherIcon {
                let minSide = min(proxy.size.width, proxy.size.height)
                let iconSide = max(minSide * PetCalendarCellMetrics.weatherIconRatio, PetCalendarCellMetrics.weatherIconMinimumSize)
                let inset = max(minSide * PetCalendarCellMetrics.weatherIconInsetRatio, PetCalendarCellMetrics.weatherIconMinimumInset)
                let center = centerPoint(
                    for: style.weatherIconCorner,
                    size: proxy.size,
                    iconSide: iconSide,
                    inset: inset
                )

                Image(systemName: icon.symbolName)
                    .font(.system(size: iconSide * 0.74, weight: .bold, design: .rounded))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color(hex: style.accentColor.hex))
                    .shadow(color: usesPhotoBackground ? Color.black.opacity(0.34) : Color.white.opacity(0.78), radius: 2, y: 1)
                    .frame(width: iconSide, height: iconSide)
                    .position(center)
            }
        }
        .allowsHitTesting(false)
    }

    private func centerPoint(for corner: PetCalendarOverlayCorner, size: CGSize, iconSide: CGFloat, inset: CGFloat) -> CGPoint {
        let x: CGFloat
        let y: CGFloat

        switch corner {
        case .topLeft, .bottomLeft:
            x = inset + iconSide / 2
        case .topRight, .bottomRight:
            x = size.width - inset - iconSide / 2
        }

        switch corner {
        case .topLeft, .topRight:
            y = inset + iconSide / 2
        case .bottomLeft, .bottomRight:
            y = size.height - inset - iconSide / 2
        }

        return CGPoint(x: x, y: y)
    }
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
            let fontSize = max(minSide * PetCalendarCellMetrics.dateFontRatio, PetCalendarCellMetrics.dateMinimumFont)

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
                    .position(x: inset + fontSize * 0.46, y: inset + fontSize * 0.48)
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
                        Color.white.opacity(0.10),
                        Color.white.opacity(0.06),
                        Color(hex: "#EDF6FA").opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.34),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 12,
                    endRadius: 360
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.74),
                                Color(hex: "#DCEBF1").opacity(0.48),
                                MemoriesTheme.border.opacity(0.24)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.32), lineWidth: 0.8)
                    .blur(radius: 0.6)
                    .padding(1)
            }
            .shadow(color: MemoriesTheme.accentDeep.opacity(0.12), radius: 26, y: 14)
    }
}

private struct PetCalendarAquaBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "#F5FBFF"),
                Color(hex: "#F8FCFF"),
                Color(hex: "#EEF7FB"),
                Color(hex: "#FFFFFF")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.0),
                    Color.white.opacity(0.54),
                    Color(hex: "#BFEAF7").opacity(0.08),
                    Color.white.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .rotationEffect(.degrees(28))
            .offset(x: 120, y: -120)
        }
        .overlay(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.0),
                    Color(hex: "#D4EEF6").opacity(0.10),
                    Color.white.opacity(0.20),
                    Color.white.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .rotationEffect(.degrees(-24))
            .offset(x: -110, y: 160)
        }
    }
}

private struct PetCalendarAquaSurface: View {
    var cornerRadius: CGFloat
    var isDimmed = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isDimmed ? 0.04 : 0.10),
                        Color.white.opacity(isDimmed ? 0.03 : 0.07),
                        Color(hex: "#EDF6FA").opacity(isDimmed ? 0.04 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isDimmed ? 0.18 : 0.58),
                                Color(hex: "#D8E8EF").opacity(isDimmed ? 0.12 : 0.42)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isDimmed ? 0.12 : 0.28), lineWidth: 0.6)
                    .padding(1)
            }
    }
}

private struct PetCalendarSelectionSurface: View {
    var isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isSelected ? MemoriesTheme.accent.opacity(0.42) : Color.white.opacity(0.10))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? MemoriesTheme.accentDeep.opacity(0.86) : Color.white.opacity(0.42), lineWidth: isSelected ? 1.6 : 0.8)
            }
    }
}

private struct PetCalendarPhotoPickerButtonLabel: View {
    let title: String

    var body: some View {
        Label {
            Text(title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .layoutPriority(1)
        } icon: {
            Image(systemName: "photo")
                .font(.headline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .foregroundStyle(MemoriesTheme.accentDeep)
        .background(.ultraThinMaterial)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    MemoriesTheme.accent.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MemoriesTheme.accentDeep.opacity(0.42), lineWidth: 1.2)
        }
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
    let overlayStyle: PetCalendarOverlayStyle
    @Binding var placement: PhotoPlacement
    @Binding var dragStartPlacement: PhotoPlacement?
    @Binding var magnifyStartPlacement: PhotoPlacement?

    @EnvironmentObject private var appState: MemoriesAppState

    var body: some View {
        GeometryReader { proxy in
            let frameRect = CGRect(origin: .zero, size: proxy.size)

            ZStack {
                RoundedRectangle(cornerRadius: PetCalendarCellMetrics.cornerRadius, style: .continuous)
                    .fill(Color.clear)
                    .background {
                        PetCalendarAquaSurface(cornerRadius: PetCalendarCellMetrics.cornerRadius)
                    }

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
                } else if overlayStyle.effectiveWeatherIcon == nil {
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

                PetCalendarWeatherIconLayer(
                    style: overlayStyle,
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
        .aspectRatio(PetCalendarCellMetrics.defaultAspectRatio, contentMode: .fit)
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
    @State private var overlayStyle: PetCalendarOverlayStyle = .default
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
            PetCalendarAquaBackdrop().ignoresSafeArea()

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
                    overlayStyle: overlayStyle,
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
                        .background(PetCalendarAquaSurface(cornerRadius: 8))
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
                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                        PetCalendarPhotoPickerButtonLabel(title: choosePhotoTitle)
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing)

                    MemoriesPrimaryButton(appState.t("calendar.saveEntry"), systemImage: "checkmark") {
                        requestSave()
                    }
                    .disabled(isProcessing)
                }

                DatePicker(
                    "",
                    selection: $registrationDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()

                weatherIconPanel

                if existingEntry != nil {
                    MemoriesSecondaryButton(appState.t("calendar.deleteEntry"), systemImage: "trash") {
                        deleteEntry()
                    }
                }
            }
            .padding(16)
        }
    }

    private var weatherIconPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(appState.t("calendar.weatherIcon"), systemImage: "cloud.sun")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MemoriesTheme.textMain)

                Spacer()

                Toggle("", isOn: weatherIconVisibility)
                    .labelsHidden()
                    .tint(MemoriesTheme.accentDeep)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(PetCalendarWeatherIcon.allCases) { icon in
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            enableWeatherIconIfNeeded()
                            overlayStyle.weatherIcon = icon
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: icon.symbolName)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(Color(hex: overlayStyle.accentColor.hex))
                                .frame(height: 24)
                            Text(icon.displayName(language: appState.resolvedLanguage))
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            PetCalendarSelectionSurface(
                                isSelected: overlayStyle.effectiveWeatherIcon == icon
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .opacity(overlayStyle.isWeatherIconVisible ? 1 : 0.48)

            if overlayStyle.isWeatherIconVisible {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appState.t("calendar.position"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textSub)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        ForEach(PetCalendarOverlayCorner.allCases) { corner in
                            Button {
                                withAnimation(.easeInOut(duration: 0.16)) {
                                    overlayStyle.weatherIconCorner = corner
                                }
                            } label: {
                                Text(corner.displayName(language: appState.resolvedLanguage))
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(
                                        PetCalendarSelectionSurface(
                                            isSelected: overlayStyle.weatherIconCorner == corner
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(appState.t("calendar.color"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MemoriesTheme.textSub)

                    HStack(spacing: 8) {
                        ForEach(PetCalendarOverlayColorStyle.allCases) { colorStyle in
                            Button {
                                withAnimation(.easeInOut(duration: 0.16)) {
                                    overlayStyle.accentColor = colorStyle
                                }
                            } label: {
                                Circle()
                                    .fill(Color(hex: colorStyle.hex))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        Circle()
                                            .stroke(colorStyle == .white ? MemoriesTheme.border.opacity(0.7) : Color.clear, lineWidth: 1)
                                    }
                                    .padding(5)
                                    .background(
                                        Circle()
                                            .fill(overlayStyle.accentColor == colorStyle ? MemoriesTheme.accent.opacity(0.54) : Color.white.opacity(0.12))
                                    )
                                    .overlay {
                                        Circle()
                                            .stroke(overlayStyle.accentColor == colorStyle ? MemoriesTheme.accentDeep : Color.white.opacity(0.44), lineWidth: overlayStyle.accentColor == colorStyle ? 1.8 : 0.8)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(colorStyle.displayName(language: appState.resolvedLanguage))
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(PetCalendarAquaSurface(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var weatherIconVisibility: Binding<Bool> {
        Binding(
            get: { overlayStyle.isWeatherIconVisible },
            set: { isVisible in
                withAnimation(.easeInOut(duration: 0.16)) {
                    if isVisible {
                        enableWeatherIconIfNeeded()
                    } else {
                        overlayStyle.isWeatherIconVisible = false
                    }
                }
            }
        )
    }

    private func enableWeatherIconIfNeeded() {
        overlayStyle.isWeatherIconVisible = true
        if overlayStyle.weatherIcon == nil {
            overlayStyle.weatherIcon = .sunny
        }
        if overlayStyle.accentColor == .white {
            overlayStyle.accentColor = .blue
        }
    }

    private func loadExisting() {
        guard let repository else {
            return
        }
        existingEntry = repository.entry(for: registrationDate)
        photoPlacement = existingEntry?.photoPlacement ?? .default
        overlayStyle = existingEntry?.overlayStyle ?? .default
        if let existingEntry {
            selectedImage = repository.image(for: existingEntry)
        } else {
            selectedImage = nil
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
        if let existingEntry {
            overlayStyle = existingEntry.overlayStyle
        }
    }

    private func requestSave() {
        guard selectedImage != nil || overlayStyle.effectiveWeatherIcon != nil else {
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
                overlayStyle: overlayStyle,
                for: registrationDate,
                allowReplace: allowReplace,
                widgetSelectedMonth: registrationDate,
                widgetDisplayLanguage: appState.petCalendarDisplayLanguage,
                widgetShowsBranding: !appState.watermarkPolicy().snapshot.hasUnlimitedAccess
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
            try repository.deleteEntry(
                for: registrationDate,
                widgetSelectedMonth: registrationDate,
                widgetDisplayLanguage: appState.petCalendarDisplayLanguage,
                widgetShowsBranding: !appState.watermarkPolicy().snapshot.hasUnlimitedAccess
            )
            reloadWidgetTimelines()
            onSaved()
            dismiss()
        } catch {
            alert = PetCalendarAlert(title: appState.t("calendar.saveFailed"), message: error.localizedDescription)
        }
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
            PetCalendarAquaBackdrop().ignoresSafeArea()
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
        .background(PetCalendarAquaSurface(cornerRadius: 8))
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
                photoPlacement: entry.photoPlacement,
                overlayStyle: entry.overlayStyle
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
            PetCalendarAquaBackdrop().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    helpRow(systemImage: "rectangle.grid.2x2", text: appState.t("calendar.widgetHelpHome"))
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
                    .background(PetCalendarAquaSurface(cornerRadius: 8))
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
                .background(isSelected ? MemoriesTheme.accentDeep : Color.clear)
                .background {
                    if !isSelected {
                        PetCalendarAquaSurface(cornerRadius: 12)
                    }
                }
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
        let reload = {
            WidgetCenter.shared.reloadTimelines(ofKind: "MemoriesWidget")
        }

        reload()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            reload()
        }
    }
    #endif
}
