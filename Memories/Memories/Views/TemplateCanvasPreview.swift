import SwiftUI
import UIKit

struct TemplateCanvasPreview: View {
    let template: Template
    let editState: CardEditState
    let photoImage: UIImage?
    let aspectRatio: CGFloat
    let isPhotoAdjustmentActive: Bool
    let onPhotoPlacementChanged: ((PhotoPlacement) -> Void)?

    @State private var dragStartPlacement: PhotoPlacement?
    @State private var magnifyStartPlacement: PhotoPlacement?

    init(
        template: Template,
        editState: CardEditState,
        photoImage: UIImage?,
        aspectRatio: CGFloat,
        isPhotoAdjustmentActive: Bool = false,
        onPhotoPlacementChanged: ((PhotoPlacement) -> Void)? = nil
    ) {
        self.template = template
        self.editState = editState
        self.photoImage = photoImage
        self.aspectRatio = aspectRatio
        self.isPhotoAdjustmentActive = isPhotoAdjustmentActive
        self.onPhotoPlacementChanged = onPhotoPlacementChanged
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack(alignment: .topLeading) {
                if template.renderStyle.isTicket {
                    ticketPreview(size: size)
                } else {
                    simpleCardPreview(size: size)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: MemoriesTheme.cardRadius))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    @ViewBuilder
    private func simpleCardPreview(size: CGSize) -> some View {
        let frameRect = CGRect(origin: .zero, size: size)

        ZStack(alignment: .topLeading) {
            photoLayer(frameRect: frameRect, canvasSize: size)

            overlayContent(size: size)
                .padding(CardOverlayLayout.inset(for: size))
                .frame(width: size.width, height: size.height, alignment: editState.selectedPosition.alignment)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .gesture(photoAdjustmentGesture(frameRect: frameRect))
    }

    @ViewBuilder
    private func ticketPreview(size: CGSize) -> some View {
        if let layout = TicketCardLayout.layout(for: template.renderStyle, canvasSize: size) {
            ZStack(alignment: .topLeading) {
                Color(uiColor: TicketTypography.background)
                    .frame(width: size.width, height: size.height)

                photoLayer(frameRect: layout.photoFrame, canvasSize: size)

                Image(layout.frameAssetName)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size.width, height: size.height)

                ticketOverlayContent(layout: layout, size: size)

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: layout.photoFrame.width, height: layout.photoFrame.height)
                    .position(x: layout.photoFrame.midX, y: layout.photoFrame.midY)
                    .gesture(photoAdjustmentGesture(frameRect: layout.photoFrame))
            }
            .frame(width: size.width, height: size.height)
        } else {
            simpleCardPreview(size: size)
        }
    }

    @ViewBuilder
    private func photoLayer(frameRect: CGRect, canvasSize: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            if let photoImage {
                let drawRect = PhotoPlacementLayout.drawRect(
                    imageSize: photoImage.size,
                    frameRect: CGRect(origin: .zero, size: frameRect.size),
                    placement: editState.photoPlacement
                )

                Image(uiImage: photoImage)
                    .resizable()
                    .frame(width: drawRect.width, height: drawRect.height)
                    .position(x: drawRect.midX, y: drawRect.midY)
            } else {
                LinearGradient(
                    colors: [
                        Color(hex: template.overlayStyle.photoPlaceholderStartColor),
                        Color(hex: template.overlayStyle.photoPlaceholderEndColor)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: min(canvasSize.width, canvasSize.height) * 0.14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.36))
                }
            }
        }
        .frame(width: frameRect.width, height: frameRect.height)
        .clipped()
        .position(x: frameRect.midX, y: frameRect.midY)
    }

    private func photoAdjustmentGesture(frameRect: CGRect) -> some Gesture {
        let drag = DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard isPhotoAdjustmentActive, let photoImage else {
                    return
                }

                let start = dragStartPlacement ?? editState.photoPlacement
                dragStartPlacement = start
                let nextPlacement = PhotoPlacementLayout.placement(
                    from: start,
                    applyingDrag: value.translation,
                    imageSize: photoImage.size,
                    frameRect: frameRect
                )
                onPhotoPlacementChanged?(nextPlacement)
            }
            .onEnded { _ in
                dragStartPlacement = nil
            }

        let magnification = MagnificationGesture()
            .onChanged { value in
                guard isPhotoAdjustmentActive else {
                    return
                }

                let start = magnifyStartPlacement ?? editState.photoPlacement
                magnifyStartPlacement = start
                let nextPlacement = PhotoPlacement(
                    scale: min(max(start.scale * Double(value), 1), 3),
                    offsetX: start.offsetX,
                    offsetY: start.offsetY
                ).clamped
                onPhotoPlacementChanged?(nextPlacement)
            }
            .onEnded { _ in
                magnifyStartPlacement = nil
            }

        return drag.simultaneously(with: magnification)
    }

    private func ticketOverlayContent(layout: TicketCardLayout, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            ticketText(
                editState.ticketTitle,
                color: Color(uiColor: TicketTypography.mainInk),
                font: .system(size: ticketTitleFontSize(size: size), weight: .heavy, design: .monospaced),
                rect: layout.ticketTitleRect,
                kerning: 1.2
            )

            if shouldShowMainText {
                ticketText(
                    editState.mainText,
                    color: Color(uiColor: TicketTypography.mainInk),
                    font: .system(size: ticketMainFontSize(size: size), weight: .bold, design: .monospaced),
                    rect: layout.mainTextRect
                )
            }

            ticketMetaBox(label: "DATE", value: editState.displayDateText, isVisible: editState.visibilitySettings.showDate, rect: layout.dateBoxRect, size: size)
            ticketMetaBox(label: "PLACE", value: editState.locationText, isVisible: editState.visibilitySettings.showLocation, rect: layout.locationBoxRect, size: size)
        }
    }

    private func ticketText(_ text: String, color: Color, font: Font, rect: CGRect, kerning: CGFloat = 0) -> some View {
        Text(text)
            .font(font)
            .kerning(kerning)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: rect.width, height: rect.height, alignment: .leading)
            .position(x: rect.midX, y: rect.midY)
    }

    private func ticketMetaBox(label: String, value: String, isVisible: Bool, rect: CGRect, size: CGSize) -> some View {
        let textRects = TicketCardLayout.labelValueRects(in: rect, canvasSize: size)

        return ZStack(alignment: .topLeading) {
            Text(label)
                .font(.system(size: min(size.width, size.height) * 0.015, weight: .semibold, design: .monospaced))
                .kerning(1.1)
                .foregroundStyle(Color(uiColor: TicketTypography.labelInk))
                .lineLimit(1)
                .frame(width: textRects.label.width, height: textRects.label.height, alignment: .leading)
                .position(x: textRects.label.midX - rect.minX, y: textRects.label.midY - rect.minY)

            if isVisible && !value.trimmedForDisplay.isEmpty {
                Text(value)
                    .font(.system(size: min(size.width, size.height) * 0.024, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(uiColor: TicketTypography.mainInk))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .frame(width: textRects.value.width, height: textRects.value.height, alignment: .leading)
                    .position(x: textRects.value.midX - rect.minX, y: textRects.value.midY - rect.minY)
            }
        }
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .position(x: rect.midX, y: rect.midY)
    }

    @ViewBuilder
    private func ticketIconRow(layout: TicketCardLayout, size: CGSize) -> some View {
        let iconSize = TicketCardLayout.iconSize(for: template.renderStyle, canvasSize: size)

        HStack(spacing: iconSize * 0.14) {
            if editState.visibilitySettings.showThemeIcon {
                MemoriesTemplateIcon(
                    assetName: editState.selectedThemeIcon.assetName,
                    fallbackSystemName: editState.selectedThemeIcon.symbolName
                )
                .frame(width: iconSize, height: iconSize)
            }

            if shouldShowWeather, let symbolName = editState.selectedWeather.symbolName {
                MemoriesTemplateIcon(
                    assetName: editState.selectedWeather.assetName,
                    fallbackSystemName: symbolName
                )
                .frame(width: iconSize, height: iconSize)
            }
        }
        .foregroundStyle(Color(uiColor: TicketTypography.mainInk))
        .frame(width: layout.iconRowRect.width, height: layout.iconRowRect.height)
        .position(x: layout.iconRowRect.midX, y: layout.iconRowRect.midY)
    }

    private func ticketTitleFontSize(size: CGSize) -> CGFloat {
        min(size.width, size.height) * (template.renderStyle == .ticketLandscape ? 0.039 : 0.034)
    }

    private func ticketMainFontSize(size: CGSize) -> CGFloat {
        min(size.width, size.height) * (template.renderStyle == .ticketLandscape ? 0.035 : 0.033)
    }

    private func overlayContent(size: CGSize) -> some View {
        VStack(alignment: editState.selectedPosition.horizontalAlignment, spacing: max(2, CardOverlayLayout.previewStackSpacing(for: size))) {
            if editState.visibilitySettings.showThemeIcon || shouldShowWeather {
                HStack(spacing: CardOverlayLayout.iconRowSpacing(for: size)) {
                    if editState.selectedPosition.isTrailing {
                        Spacer(minLength: 0)
                    }

                    if editState.visibilitySettings.showThemeIcon {
                        MemoriesTemplateIcon(
                            assetName: editState.selectedThemeIcon.assetName,
                            fallbackSystemName: editState.selectedThemeIcon.symbolName
                        )
                        .frame(
                            width: CardOverlayLayout.themeIconSize(for: size),
                            height: CardOverlayLayout.themeIconSize(for: size)
                        )
                    }

                    if shouldShowWeather, let symbolName = editState.selectedWeather.symbolName {
                        MemoriesTemplateIcon(
                            assetName: editState.selectedWeather.assetName,
                            fallbackSystemName: symbolName
                        )
                        .frame(
                            width: CardOverlayLayout.weatherIconSize(for: size),
                            height: CardOverlayLayout.weatherIconSize(for: size)
                        )
                    }
                }
            }

            if shouldShowLocation {
                metaLine(icon: .location, text: editState.locationText, size: size)
            }

            if shouldShowDate {
                metaLine(icon: .calendar, text: editState.displayDateText, size: size)
            }

            if shouldShowMainText {
                overlayText(editState.mainText, size: size, role: .main)
                    .padding(.top, max(2, CardOverlayLayout.base(for: size) * CardOverlayLayout.mainTopSpacingRatio))
            }

            if shouldShowSubText {
                overlayText(editState.subText, size: size, role: .sub)
            }

        }
        .foregroundStyle(editState.selectedTextColor.color)
        .shadow(
            color: .black.opacity(editState.selectedTextColor == .white ? 0.28 : 0.1),
            radius: editState.selectedTextColor == .white ? 5 : 2,
            y: 1
        )
        .frame(maxWidth: CardOverlayLayout.blockWidth(for: size), alignment: editState.selectedPosition.isTrailing ? .trailing : .leading)
    }

    private func overlayText(_ text: String, size: CGSize, role: PreviewTextRole) -> some View {
        Text(text)
            .font(font(for: role, size: size))
            .multilineTextAlignment(editState.selectedPosition.textAlignment)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func metaLine(icon: UtilityIconType, text: String, size: CGSize) -> some View {
        HStack(spacing: CardOverlayLayout.metaIconSize(for: size) * CardOverlayLayout.iconTextSpacingRatio) {
            if editState.selectedPosition.isTrailing {
                Spacer(minLength: 0)
            }

            MemoriesTemplateIcon(assetName: icon.assetName, fallbackSystemName: icon.fallbackSymbolName)
                .frame(
                    width: CardOverlayLayout.metaIconSize(for: size),
                    height: CardOverlayLayout.metaIconSize(for: size)
                )

            overlayText(text, size: size, role: .meta)
        }
    }

    private var shouldShowWeather: Bool {
        editState.visibilitySettings.showWeather && editState.selectedWeather != .none
    }

    private var shouldShowLocation: Bool {
        editState.visibilitySettings.showLocation && !editState.locationText.trimmedForDisplay.isEmpty
    }

    private var shouldShowDate: Bool {
        editState.visibilitySettings.showDate && !editState.displayDateText.trimmedForDisplay.isEmpty
    }

    private var shouldShowMainText: Bool {
        editState.visibilitySettings.showMainText && !editState.mainText.trimmedForDisplay.isEmpty
    }

    private var shouldShowSubText: Bool {
        editState.visibilitySettings.showSubText && !editState.subText.trimmedForDisplay.isEmpty
    }

    private func font(for role: PreviewTextRole, size: CGSize) -> Font {
        switch role {
        case .meta:
            return editState.selectedFontRole.font(size: CardOverlayLayout.fontSize(for: .meta, canvasSize: size), weight: .semibold)
        case .main:
            return editState.selectedFontRole.font(size: CardOverlayLayout.fontSize(for: .main, canvasSize: size), weight: .bold)
        case .sub:
            return editState.selectedFontRole.font(size: CardOverlayLayout.fontSize(for: .sub, canvasSize: size), weight: .medium)
        }
    }
}

private extension String {
    var trimmedForDisplay: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private typealias PreviewTextRole = CardOverlayTextRole

#Preview {
    let template = Template(
        id: "preview",
        name: "Pet Lifelog Clean",
        category: "petLifelog",
        supportedAspectRatios: [.fourByFive, .square, .nineBySixteen],
        defaultLayout: .bottomLeft,
        overlayStyle: OverlayStyle(
            name: "Clean",
            defaultTextColor: .white,
            defaultFontRole: .clean,
            photoPlaceholderStartColor: "#BFD8EA",
            photoPlaceholderEndColor: "#8FB7D9",
            addsSoftShadow: true
        ),
        textFieldDefinitions: []
    )

    return TemplateCanvasPreview(
        template: template,
        editState: template.previewEditState,
        photoImage: nil,
        aspectRatio: CardAspectRatio.fourByFive.value
    )
    .frame(width: 240)
    .padding()
    .background(MemoriesTheme.background)
}
