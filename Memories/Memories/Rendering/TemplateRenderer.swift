import CoreImage
import UIKit

struct TemplateRenderConfiguration {
    let template: Template
    let editState: CardEditState
    let outputSize: CGSize
    let photoImage: UIImage?
    let watermarkMode: WatermarkMode

    init(
        template: Template,
        editState: CardEditState,
        outputSize: CGSize? = nil,
        photoImage: UIImage? = nil,
        watermarkMode: WatermarkMode = .visible
    ) {
        self.template = template
        self.editState = editState
        self.photoImage = photoImage
        self.outputSize = outputSize
            ?? template.renderStyle.outputSize
            ?? photoImage?.preferredRenderSize
            ?? CardAspectRatio.fourByFive.outputSize
        self.watermarkMode = watermarkMode
    }
}

final class TemplateRenderer {
    func render(configuration: TemplateRenderConfiguration) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: configuration.outputSize, format: format)
        return renderer.image { context in
            let cgContext = context.cgContext
            if configuration.template.renderStyle.isRetroFilm {
                drawRetroFilm(configuration: configuration, in: cgContext)
                return
            }

            if configuration.template.renderStyle.isTicket {
                drawTicketCard(configuration: configuration, in: cgContext)
                return
            }

            drawPhotoLayer(
                image: configuration.photoImage,
                template: configuration.template,
                editState: configuration.editState,
                in: cgContext,
                size: configuration.outputSize
            )
            drawOverlay(
                template: configuration.template,
                editState: configuration.editState,
                in: cgContext,
                size: configuration.outputSize
            )
            WatermarkRenderer().draw(
                mode: configuration.watermarkMode,
                overlayPosition: configuration.editState.selectedPosition,
                in: cgContext,
                size: configuration.outputSize
            )
        }
    }

    private func drawRetroFilm(configuration: TemplateRenderConfiguration, in context: CGContext) {
        let size = configuration.outputSize
        let canvasRect = CGRect(origin: .zero, size: size)

        UIGraphicsPushContext(context)
        if let image = configuration.photoImage,
           let filteredImage = RetroFilmEffect.render(
                image: image,
                size: size,
                filterType: configuration.editState.retroFilterType
           ) {
            filteredImage.draw(in: canvasRect)
        } else {
            drawRetroPlaceholder(in: canvasRect)
        }
        drawRetroDateStamp(
            configuration.editState.retroDateStampText,
            filterType: configuration.editState.retroFilterType,
            canvasSize: size
        )
        UIGraphicsPopContext()

        WatermarkRenderer().draw(
            mode: configuration.watermarkMode,
            overlayPosition: .bottomRight,
            in: context,
            size: size
        )
    }

    private func drawRetroPlaceholder(in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        let colors = [
            UIColor(red: 0.84, green: 0.72, blue: 0.54, alpha: 1).cgColor,
            UIColor(red: 0.50, green: 0.42, blue: 0.32, alpha: 1).cgColor
        ]
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: [0, 1]
        )
        if let gradient {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.minX, y: rect.minY),
                end: CGPoint(x: rect.maxX, y: rect.maxY),
                options: []
            )
        }
    }

    private func drawRetroDateStamp(_ text: String, filterType: RetroFilterType, canvasSize: CGSize) {
        let inset = RetroFilmLayout.stampInset(for: canvasSize)
        let stampImage = RetroDateStampRenderer.image(
            text: text,
            filterType: filterType,
            canvasSize: canvasSize
        )
        let measured = stampImage.size
        let rect = CGRect(
            x: canvasSize.width - inset - measured.width,
            y: canvasSize.height - inset - measured.height,
            width: measured.width,
            height: measured.height
        )
        stampImage.draw(in: rect)
    }

    private func drawPhotoLayer(
        image: UIImage?,
        template: Template,
        editState: CardEditState,
        in context: CGContext,
        size: CGSize
    ) {
        let rect = CGRect(origin: .zero, size: size)

        if let image {
            drawAspectFillImage(image, in: rect, placement: editState.photoPlacement)
            return
        }

        let colors = [
            UIColor(hex: template.overlayStyle.photoPlaceholderStartColor).cgColor,
            UIColor(hex: template.overlayStyle.photoPlaceholderEndColor).cgColor
        ]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1])

        if let gradient {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.minX, y: rect.minY),
                end: CGPoint(x: rect.maxX, y: rect.maxY),
                options: []
            )
        } else {
            context.setFillColor(MemoriesTheme.uiColor(forRole: "subBackground").cgColor)
            context.fill(rect)
        }

        let pawSymbol = UIImage(systemName: "pawprint.fill")?
            .withTintColor(UIColor.white.withAlphaComponent(0.35), renderingMode: .alwaysOriginal)
        let symbolSize = min(size.width, size.height) * 0.18
        let symbolRect = CGRect(
            x: (size.width - symbolSize) / 2,
            y: (size.height - symbolSize) / 2,
            width: symbolSize,
            height: symbolSize
        )
        pawSymbol?.draw(in: symbolRect)
    }

    private func drawAspectFillImage(_ image: UIImage, in rect: CGRect, placement: PhotoPlacement) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            return
        }

        UIBezierPath(rect: rect).addClip()
        let drawRect = PhotoPlacementLayout.drawRect(imageSize: imageSize, frameRect: rect, placement: placement)
        image.draw(in: drawRect)
    }

    private func drawTicketCard(configuration: TemplateRenderConfiguration, in context: CGContext) {
        let size = configuration.outputSize
        let canvasRect = CGRect(origin: .zero, size: size)

        context.setFillColor(TicketTypography.background.cgColor)
        context.fill(canvasRect)

        guard let layout = TicketCardLayout.layout(for: configuration.template.renderStyle, canvasSize: size) else {
            return
        }

        context.saveGState()
        UIGraphicsPushContext(context)
        if let image = configuration.photoImage {
            PhotoPlacementLayout.drawImage(image, in: layout.photoFrame, placement: configuration.editState.photoPlacement)
        } else {
            drawTicketPhotoPlaceholder(in: layout.photoFrame, template: configuration.template)
        }
        UIGraphicsPopContext()
        context.restoreGState()

        UIGraphicsPushContext(context)
        UIImage(named: layout.frameAssetName)?.draw(in: canvasRect)
        drawTicketText(layout: layout, editState: configuration.editState, renderStyle: configuration.template.renderStyle, canvasSize: size)
        UIGraphicsPopContext()

        WatermarkRenderer().draw(
            mode: configuration.watermarkMode,
            overlayPosition: .bottomLeft,
            in: context,
            size: size,
            bounds: layout.photoFrame
        )
    }

    private func drawTicketPhotoPlaceholder(in rect: CGRect, template: Template) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        context.saveGState()
        UIBezierPath(rect: rect).addClip()
        let colors = [
            UIColor(hex: template.overlayStyle.photoPlaceholderStartColor).cgColor,
            UIColor(hex: template.overlayStyle.photoPlaceholderEndColor).cgColor
        ]
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: [0, 1]
        )
        if let gradient {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.minX, y: rect.minY),
                end: CGPoint(x: rect.maxX, y: rect.maxY),
                options: []
            )
        } else {
            TicketTypography.background.setFill()
            UIBezierPath(rect: rect).fill()
        }
        context.restoreGState()
    }

    private func drawTicketText(
        layout: TicketCardLayout,
        editState: CardEditState,
        renderStyle: TemplateRenderStyle,
        canvasSize: CGSize
    ) {
        drawTicketTitle(editState.ticketTitle, in: layout.ticketTitleRect, renderStyle: renderStyle, canvasSize: canvasSize)
        drawTicketMain(editState: editState, in: layout.mainTextRect, renderStyle: renderStyle, canvasSize: canvasSize)
        drawTicketMetaBox(label: "DATE", value: editState.displayDateText, isVisible: editState.visibilitySettings.showDate, in: layout.dateBoxRect, canvasSize: canvasSize)
        drawTicketMetaBox(label: "PLACE", value: editState.locationText, isVisible: editState.visibilitySettings.showLocation, in: layout.locationBoxRect, canvasSize: canvasSize)
    }

    private func drawTicketTitle(_ title: String, in rect: CGRect, renderStyle: TemplateRenderStyle, canvasSize: CGSize) {
        let base = min(canvasSize.width, canvasSize.height)
        let fontSize = base * (renderStyle == .ticketLandscape ? 0.039 : 0.034)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: ticketFont(size: fontSize, weight: .heavy),
            .foregroundColor: TicketTypography.mainInk,
            .kern: 1.4
        ]
        drawTicketString(title.trimmedForRenderer, verticallyCenteredIn: rect, attributes: attributes)
    }

    private func drawTicketMain(editState: CardEditState, in rect: CGRect, renderStyle: TemplateRenderStyle, canvasSize: CGSize) {
        guard editState.visibilitySettings.showMainText, !editState.mainText.trimmedForRenderer.isEmpty else {
            return
        }

        let base = min(canvasSize.width, canvasSize.height)
        let fontSize = base * (renderStyle == .ticketLandscape ? 0.035 : 0.033)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: ticketFont(size: fontSize, weight: .bold),
            .foregroundColor: TicketTypography.mainInk
        ]
        drawTicketString(editState.mainText.trimmedForRenderer, verticallyCenteredIn: rect, attributes: attributes)
    }

    private func drawTicketMetaBox(label: String, value: String, isVisible: Bool, in rect: CGRect, canvasSize: CGSize) {
        guard isVisible, !value.trimmedForRenderer.isEmpty else {
            return
        }

        let base = min(canvasSize.width, canvasSize.height)
        let labelFontSize = base * 0.015
        let valueFontSize = base * 0.024
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: labelFontSize, weight: .semibold),
            .foregroundColor: TicketTypography.labelInk,
            .kern: 1.2
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: ticketFont(size: valueFontSize, weight: .semibold),
            .foregroundColor: TicketTypography.mainInk
        ]
        let textRects = TicketCardLayout.labelValueRects(in: rect, canvasSize: canvasSize)
        drawTicketString(label, in: textRects.label, attributes: labelAttributes)
        drawTicketString(value.trimmedForRenderer, in: textRects.value, attributes: valueAttributes)
    }

    private func drawTicketIconRow(
        layout: TicketCardLayout,
        editState: CardEditState,
        renderStyle: TemplateRenderStyle,
        canvasSize: CGSize
    ) {
        var icons: [(assetName: String?, fallbackSymbolName: String)] = []
        if editState.visibilitySettings.showThemeIcon {
            icons.append((editState.selectedThemeIcon.assetName, editState.selectedThemeIcon.symbolName))
        }
        if shouldDrawWeather(editState), let weatherSymbol = editState.selectedWeather.symbolName {
            icons.append((editState.selectedWeather.assetName, weatherSymbol))
        }
        guard !icons.isEmpty else {
            return
        }

        let iconSize = TicketCardLayout.iconSize(for: renderStyle, canvasSize: canvasSize)
        let spacing = iconSize * 0.14
        let totalWidth = CGFloat(icons.count) * iconSize + CGFloat(max(0, icons.count - 1)) * spacing
        var cursorX = layout.iconRowRect.midX - totalWidth / 2
        let y = layout.iconRowRect.midY - iconSize / 2

        for icon in icons {
            drawTemplateIcon(
                assetName: icon.assetName,
                fallbackSymbolName: icon.fallbackSymbolName,
                tintColor: TicketTypography.mainInk,
                in: CGRect(x: cursorX, y: y, width: iconSize, height: iconSize)
            )
            cursorX += iconSize + spacing
        }
    }

    private func drawTicketString(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any]) {
        guard !text.isEmpty else {
            return
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = .left
        var nextAttributes = attributes
        nextAttributes[.paragraphStyle] = paragraph

        NSString(string: text).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine],
            attributes: nextAttributes,
            context: nil
        )
    }

    private func drawTicketString(_ text: String, verticallyCenteredIn rect: CGRect, attributes: [NSAttributedString.Key: Any]) {
        guard !text.isEmpty else {
            return
        }

        let measuredSize = NSString(string: text).boundingRect(
            with: CGSize(width: rect.width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).size
        let centeredRect = CGRect(
            x: rect.minX,
            y: rect.midY - ceil(measuredSize.height) / 2,
            width: rect.width,
            height: max(rect.height, ceil(measuredSize.height))
        )
        drawTicketString(text, in: centeredRect, attributes: attributes)
    }

    private func ticketFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    private func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let baseFont = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = baseFont.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return baseFont
    }

    private func drawOverlay(
        template: Template,
        editState: CardEditState,
        in context: CGContext,
        size: CGSize
    ) {
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }

        let inset = CardOverlayLayout.inset(for: size)
        let blockWidth = CardOverlayLayout.blockWidth(for: size)
        let blockHeight = estimatedOverlayHeight(for: editState, size: size)
        let x = editState.selectedPosition.isTrailing ? size.width - inset - blockWidth : inset
        let y = editState.selectedPosition.isBottom ? size.height - inset - blockHeight : inset
        let rect = CGRect(x: x, y: y, width: blockWidth, height: blockHeight)

        if template.overlayStyle.addsSoftShadow {
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 2), blur: 8, color: UIColor.black.withAlphaComponent(0.22).cgColor)
            context.restoreGState()
        }

        var cursorY = rect.minY

        if editState.visibilitySettings.showThemeIcon || shouldDrawWeather(editState) {
            drawIconRow(editState: editState, in: rect, cursorY: cursorY, size: size)
            cursorY += CardOverlayLayout.base(for: size) * CardOverlayLayout.iconRowAdvanceRatio
        }

        if shouldDrawText(editState.locationText, isVisible: editState.visibilitySettings.showLocation) {
            cursorY += drawMetaLine(
                assetName: UtilityIconType.location.assetName,
                fallbackSymbolName: UtilityIconType.location.fallbackSymbolName,
                text: editState.locationText,
                in: lineRect(parent: rect, y: cursorY, height: CardOverlayLayout.lineHeight(for: .meta, canvasSize: size)),
                editState: editState,
                size: size
            )
        }

        if shouldDrawText(editState.displayDateText, isVisible: editState.visibilitySettings.showDate) {
            cursorY += drawMetaLine(
                assetName: UtilityIconType.calendar.assetName,
                fallbackSymbolName: UtilityIconType.calendar.fallbackSymbolName,
                text: editState.displayDateText,
                in: lineRect(parent: rect, y: cursorY, height: CardOverlayLayout.lineHeight(for: .meta, canvasSize: size)),
                editState: editState,
                size: size
            )
        }

        if shouldDrawText(editState.mainText, isVisible: editState.visibilitySettings.showMainText) {
            cursorY += CardOverlayLayout.base(for: size) * CardOverlayLayout.mainTopSpacingRatio
            cursorY += drawText(
                editState.mainText,
                in: lineRect(parent: rect, y: cursorY, height: CardOverlayLayout.lineHeight(for: .main, canvasSize: size)),
                editState: editState,
                size: size,
                role: .main
            )
        }

        if shouldDrawText(editState.subText, isVisible: editState.visibilitySettings.showSubText) {
            cursorY += drawText(
                editState.subText,
                in: lineRect(parent: rect, y: cursorY, height: CardOverlayLayout.lineHeight(for: .sub, canvasSize: size)),
                editState: editState,
                size: size,
                role: .sub
            )
        }

    }

    private func drawMetaLine(
        assetName: String,
        fallbackSymbolName: String,
        text: String,
        in rect: CGRect,
        editState: CardEditState,
        size: CGSize
    ) -> CGFloat {
        let iconSize = CardOverlayLayout.metaIconSize(for: size)
        let spacing = iconSize * CardOverlayLayout.iconTextSpacingRatio
        let textWidth = rect.width - iconSize - spacing
        let iconX = editState.selectedPosition.isTrailing ? rect.maxX - iconSize : rect.minX
        let textX = editState.selectedPosition.isTrailing ? rect.minX : rect.minX + iconSize + spacing

        drawTemplateIcon(
            assetName: assetName,
            fallbackSymbolName: fallbackSymbolName,
            tintColor: editState.selectedTextColor.uiColor,
            in: CGRect(
                x: iconX,
                y: rect.minY + max(0, (rect.height - iconSize) / 2),
                width: iconSize,
                height: iconSize
            )
        )

        let textRect = verticallyCenteredTextRect(
            text,
            in: CGRect(x: textX, y: rect.minY, width: textWidth, height: rect.height),
            editState: editState,
            size: size,
            role: .meta
        )

        _ = drawText(
            text,
            in: textRect,
            editState: editState,
            size: size,
            role: .meta
        )

        return rect.height
    }

    private func drawIconRow(editState: CardEditState, in rect: CGRect, cursorY: CGFloat, size: CGSize) {
        let spacing = CardOverlayLayout.iconRowSpacing(for: size)
        var icons: [(assetName: String?, fallbackSymbolName: String, size: CGFloat)] = []

        if editState.visibilitySettings.showThemeIcon {
            icons.append((
                editState.selectedThemeIcon.assetName,
                editState.selectedThemeIcon.symbolName,
                CardOverlayLayout.themeIconSize(for: size)
            ))
        }

        if shouldDrawWeather(editState), let weatherSymbol = editState.selectedWeather.symbolName {
            icons.append((
                editState.selectedWeather.assetName,
                weatherSymbol,
                CardOverlayLayout.weatherIconSize(for: size)
            ))
        }

        let totalWidth = icons.reduce(CGFloat(0)) { $0 + $1.size } + CGFloat(max(0, icons.count - 1)) * spacing
        let maxIconSize = icons.map(\.size).max() ?? 0
        var cursorX = editState.selectedPosition.isTrailing ? rect.maxX - totalWidth : rect.minX

        for icon in icons {
            drawTemplateIcon(
                assetName: icon.assetName,
                fallbackSymbolName: icon.fallbackSymbolName,
                tintColor: editState.selectedTextColor.uiColor,
                in: CGRect(
                    x: cursorX,
                    y: cursorY + max(0, (maxIconSize - icon.size) / 2),
                    width: icon.size,
                    height: icon.size
                )
            )
            cursorX += icon.size + spacing
        }
    }

    private func drawTemplateIcon(
        assetName: String?,
        fallbackSymbolName: String,
        tintColor: UIColor,
        in rect: CGRect
    ) {
        let image = assetName.flatMap { UIImage(named: $0) } ?? UIImage(systemName: fallbackSymbolName)
        image?
            .withRenderingMode(.alwaysTemplate)
            .withTintColor(tintColor, renderingMode: .alwaysOriginal)
            .draw(in: rect)
    }

    private func drawText(
        _ text: String,
        in rect: CGRect,
        editState: CardEditState,
        size: CGSize,
        role: RenderTextRole
    ) -> CGFloat {
        guard !text.trimmedForRenderer.isEmpty else {
            return 0
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = editState.selectedPosition.isTrailing ? .right : .left

        let font = editState.selectedFontRole.uiFont(
            size: CardOverlayLayout.fontSize(for: role, canvasSize: size),
            weight: CardOverlayLayout.fontWeight(for: role)
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: editState.selectedTextColor.uiColor,
            .paragraphStyle: paragraphStyle,
            .shadow: textShadow(for: editState)
        ]

        NSString(string: text.trimmedForRenderer).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        return rect.height
    }

    private func verticallyCenteredTextRect(
        _ text: String,
        in rect: CGRect,
        editState: CardEditState,
        size: CGSize,
        role: RenderTextRole
    ) -> CGRect {
        let font = editState.selectedFontRole.uiFont(
            size: CardOverlayLayout.fontSize(for: role, canvasSize: size),
            weight: CardOverlayLayout.fontWeight(for: role)
        )
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let measuredSize = NSString(string: text.trimmedForRenderer).boundingRect(
            with: CGSize(width: rect.width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).size
        let textHeight = min(rect.height, ceil(measuredSize.height))
        let centeredY = rect.midY - textHeight / 2

        return CGRect(
            x: rect.minX,
            y: centeredY,
            width: rect.width,
            height: max(textHeight, font.lineHeight)
        )
    }

    private func textShadow(for editState: CardEditState) -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowBlurRadius = editState.selectedTextColor == .white ? 6 : 2
        shadow.shadowOffset = CGSize(width: 0, height: 1)
        shadow.shadowColor = UIColor.black.withAlphaComponent(editState.selectedTextColor == .white ? 0.35 : 0.12)
        return shadow
    }

    private func estimatedOverlayHeight(for editState: CardEditState, size: CGSize) -> CGFloat {
        let base = CardOverlayLayout.base(for: size)
        var height: CGFloat = 0

        if editState.visibilitySettings.showThemeIcon || shouldDrawWeather(editState) {
            height += base * (CardOverlayLayout.iconRowAdvanceRatio + 0.006)
        }
        if shouldDrawText(editState.locationText, isVisible: editState.visibilitySettings.showLocation) {
            height += CardOverlayLayout.lineHeight(for: .meta, canvasSize: size)
        }
        if shouldDrawText(editState.displayDateText, isVisible: editState.visibilitySettings.showDate) {
            height += CardOverlayLayout.lineHeight(for: .meta, canvasSize: size)
        }
        if shouldDrawText(editState.mainText, isVisible: editState.visibilitySettings.showMainText) {
            height += base * CardOverlayLayout.mainTopSpacingRatio
            height += CardOverlayLayout.lineHeight(for: .main, canvasSize: size)
        }
        if shouldDrawText(editState.subText, isVisible: editState.visibilitySettings.showSubText) {
            height += CardOverlayLayout.lineHeight(for: .sub, canvasSize: size)
        }
        return max(height, base * 0.08)
    }

    private func shouldDrawWeather(_ editState: CardEditState) -> Bool {
        editState.visibilitySettings.showWeather && editState.selectedWeather != .none
    }

    private func shouldDrawText(_ text: String, isVisible: Bool) -> Bool {
        isVisible && !text.trimmedForRenderer.isEmpty
    }

    private func lineRect(parent: CGRect, y: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: parent.minX, y: y, width: parent.width, height: height)
    }

}

private typealias RenderTextRole = CardOverlayTextRole

struct RetroFilmLayout {
    static func stampColor(for filterType: RetroFilterType) -> UIColor {
        switch filterType {
        case .sepia, .nostalgic:
            return UIColor(red: 1.0, green: 0.416, blue: 0.102, alpha: 0.96)
        case .monochrome:
            return UIColor(red: 0.957, green: 0.945, blue: 0.910, alpha: 0.96)
        }
    }

    static func stampBleedColor(for filterType: RetroFilterType) -> UIColor {
        switch filterType {
        case .sepia, .nostalgic:
            return UIColor(red: 1.0, green: 0.416, blue: 0.102, alpha: 0.25)
        case .monochrome:
            return UIColor(red: 0.957, green: 0.945, blue: 0.910, alpha: 0.24)
        }
    }

    static func stampShadowColor(for filterType: RetroFilterType) -> UIColor {
        switch filterType {
        case .sepia, .nostalgic:
            return UIColor(white: 0.0, alpha: 0.35)
        case .monochrome:
            return UIColor(white: 0.0, alpha: 0.55)
        }
    }

    static func stampFontSize(for size: CGSize) -> CGFloat {
        max(14, min(size.width, size.height) * 0.039)
    }

    static func stampInset(for size: CGSize) -> CGFloat {
        max(18, min(size.width, size.height) * 0.052)
    }

    static func stampShadowRadius(for size: CGSize) -> CGFloat {
        max(1.0, min(2.0, min(size.width, size.height) * 0.0022))
    }

    static func stampShadowOffset(for size: CGSize) -> CGFloat {
        max(0.6, min(1.2, min(size.width, size.height) * 0.0014))
    }

    static func stampTracking(for size: CGSize) -> CGFloat {
        max(1.8, min(3.0, stampFontSize(for: size) * 0.065))
    }
}

enum RetroDateStampRenderer {
    static func image(text: String, filterType: RetroFilterType, canvasSize: CGSize) -> UIImage {
        let size = stampSize(text: text, canvasSize: canvasSize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            let padding = padding(for: canvasSize)
            let origin = CGPoint(x: padding, y: padding)
            let shadowOffset = RetroFilmLayout.stampShadowOffset(for: canvasSize)

            context.saveGState()
            context.setShadow(
                offset: CGSize(width: shadowOffset * 0.7, height: shadowOffset * 0.7),
                blur: RetroFilmLayout.stampShadowRadius(for: canvasSize),
                color: RetroFilmLayout.stampShadowColor(for: filterType).cgColor
            )
            draw(
                text: text,
                at: CGPoint(x: origin.x + shadowOffset * 0.45, y: origin.y + shadowOffset * 0.45),
                color: RetroFilmLayout.stampBleedColor(for: filterType),
                canvasSize: canvasSize,
                in: context
            )
            context.restoreGState()

            context.saveGState()
            context.setShadow(
                offset: CGSize(width: shadowOffset, height: shadowOffset),
                blur: RetroFilmLayout.stampShadowRadius(for: canvasSize),
                color: RetroFilmLayout.stampShadowColor(for: filterType).cgColor
            )
            draw(
                text: text,
                at: origin,
                color: RetroFilmLayout.stampColor(for: filterType),
                canvasSize: canvasSize,
                in: context
            )
            context.restoreGState()
        }
    }

    static func stampSize(text: String, canvasSize: CGSize) -> CGSize {
        let height = glyphHeight(for: canvasSize)
        let tracking = RetroFilmLayout.stampTracking(for: canvasSize)
        let width = text.reduce(CGFloat.zero) { partial, character in
            partial + glyphWidth(for: character, height: height) + tracking
        } - tracking
        let padding = padding(for: canvasSize)
        return CGSize(
            width: max(1, width + padding * 2),
            height: height + padding * 2
        )
    }

    private static func draw(
        text: String,
        at origin: CGPoint,
        color: UIColor,
        canvasSize: CGSize,
        in context: CGContext
    ) {
        let height = glyphHeight(for: canvasSize)
        let tracking = RetroFilmLayout.stampTracking(for: canvasSize)
        var cursorX = origin.x

        context.setFillColor(color.cgColor)

        for character in text {
            let width = glyphWidth(for: character, height: height)
            let rect = CGRect(x: cursorX, y: origin.y, width: width, height: height)
            draw(character: character, in: rect, context: context)
            cursorX += width + tracking
        }
    }

    private static func draw(character: Character, in rect: CGRect, context: CGContext) {
        if let segments = segments(for: character) {
            for segment in segments {
                context.addPath(segment.path(in: rect))
                context.fillPath()
            }
            return
        }

        if character == "'" {
            let tick = CGRect(
                x: rect.midX - rect.width * 0.03,
                y: rect.minY + rect.height * 0.06,
                width: max(1, rect.width * 0.22),
                height: rect.height * 0.24
            )
            context.addPath(apostrophePath(in: tick))
            context.fillPath()
        }
    }

    private static func segments(for character: Character) -> [Segment]? {
        switch character {
        case "0":
            return [.top, .upperLeft, .upperRight, .lowerLeft, .lowerRight, .bottom]
        case "1":
            return [.upperRight, .lowerRight]
        case "2":
            return [.top, .upperRight, .middle, .lowerLeft, .bottom]
        case "3":
            return [.top, .upperRight, .middle, .lowerRight, .bottom]
        case "4":
            return [.upperLeft, .upperRight, .middle, .lowerRight]
        case "5":
            return [.top, .upperLeft, .middle, .lowerRight, .bottom]
        case "6":
            return [.top, .upperLeft, .middle, .lowerLeft, .lowerRight, .bottom]
        case "7":
            return [.top, .upperRight, .lowerRight]
        case "8":
            return [.top, .upperLeft, .upperRight, .middle, .lowerLeft, .lowerRight, .bottom]
        case "9":
            return [.top, .upperLeft, .upperRight, .middle, .lowerRight, .bottom]
        default:
            return nil
        }
    }

    private static func glyphHeight(for canvasSize: CGSize) -> CGFloat {
        RetroFilmLayout.stampFontSize(for: canvasSize) * 1.02
    }

    private static func glyphWidth(for character: Character, height: CGFloat) -> CGFloat {
        switch character {
        case " ":
            return height * 0.33
        case "'":
            return height * 0.20
        default:
            return height * 0.46
        }
    }

    private static func padding(for canvasSize: CGSize) -> CGFloat {
        max(2.0, RetroFilmLayout.stampShadowRadius(for: canvasSize) * 2.4)
    }

    private static func apostrophePath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.36, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.32, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    private enum Segment {
        case top
        case upperLeft
        case upperRight
        case middle
        case lowerLeft
        case lowerRight
        case bottom

        func path(in rect: CGRect) -> CGPath {
            let thickness = max(1.4, rect.height * 0.13)
            let shortThickness = max(1.2, rect.height * 0.105)
            let chamfer = thickness * 0.42
            switch self {
            case .top:
                return horizontalSegmentPath(
                    fromX: rect.minX + rect.width * 0.26,
                    toX: rect.minX + rect.width * 0.76,
                    centerY: rect.minY + rect.height * 0.11,
                    thickness: thickness,
                    chamfer: chamfer
                )
            case .upperLeft:
                return verticalSegmentPath(
                    centerX: rect.minX + rect.width * 0.18,
                    fromY: rect.minY + rect.height * 0.17,
                    toY: rect.minY + rect.height * 0.44,
                    thickness: shortThickness,
                    chamfer: chamfer
                )
            case .upperRight:
                return verticalSegmentPath(
                    centerX: rect.minX + rect.width * 0.84,
                    fromY: rect.minY + rect.height * 0.17,
                    toY: rect.minY + rect.height * 0.44,
                    thickness: shortThickness,
                    chamfer: chamfer
                )
            case .middle:
                return horizontalSegmentPath(
                    fromX: rect.minX + rect.width * 0.24,
                    toX: rect.minX + rect.width * 0.74,
                    centerY: rect.minY + rect.height * 0.50,
                    thickness: thickness,
                    chamfer: chamfer
                )
            case .lowerLeft:
                return verticalSegmentPath(
                    centerX: rect.minX + rect.width * 0.18,
                    fromY: rect.minY + rect.height * 0.56,
                    toY: rect.minY + rect.height * 0.83,
                    thickness: shortThickness,
                    chamfer: chamfer
                )
            case .lowerRight:
                return verticalSegmentPath(
                    centerX: rect.minX + rect.width * 0.84,
                    fromY: rect.minY + rect.height * 0.56,
                    toY: rect.minY + rect.height * 0.83,
                    thickness: shortThickness,
                    chamfer: chamfer
                )
            case .bottom:
                return horizontalSegmentPath(
                    fromX: rect.minX + rect.width * 0.24,
                    toX: rect.minX + rect.width * 0.74,
                    centerY: rect.minY + rect.height * 0.89,
                    thickness: thickness,
                    chamfer: chamfer
                )
            }
        }

        private func horizontalSegmentPath(
            fromX: CGFloat,
            toX: CGFloat,
            centerY: CGFloat,
            thickness: CGFloat,
            chamfer: CGFloat
        ) -> CGPath {
            let half = thickness / 2
            let path = CGMutablePath()
            path.move(to: CGPoint(x: fromX + chamfer, y: centerY - half))
            path.addLine(to: CGPoint(x: toX - chamfer, y: centerY - half))
            path.addLine(to: CGPoint(x: toX, y: centerY))
            path.addLine(to: CGPoint(x: toX - chamfer, y: centerY + half))
            path.addLine(to: CGPoint(x: fromX + chamfer, y: centerY + half))
            path.addLine(to: CGPoint(x: fromX, y: centerY))
            path.closeSubpath()
            return path
        }

        private func verticalSegmentPath(
            centerX: CGFloat,
            fromY: CGFloat,
            toY: CGFloat,
            thickness: CGFloat,
            chamfer: CGFloat
        ) -> CGPath {
            let half = thickness / 2
            let path = CGMutablePath()
            path.move(to: CGPoint(x: centerX, y: fromY))
            path.addLine(to: CGPoint(x: centerX + half, y: fromY + chamfer))
            path.addLine(to: CGPoint(x: centerX + half, y: toY - chamfer))
            path.addLine(to: CGPoint(x: centerX, y: toY))
            path.addLine(to: CGPoint(x: centerX - half, y: toY - chamfer))
            path.addLine(to: CGPoint(x: centerX - half, y: fromY + chamfer))
            path.closeSubpath()
            return path
        }
    }
}

enum RetroFilmEffect {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    static func render(image: UIImage, size: CGSize, filterType: RetroFilterType) -> UIImage? {
        guard size.width > 0, size.height > 0 else {
            return nil
        }

        let normalized = normalizedImage(image, size: size)
        guard let input = CIImage(image: normalized) else {
            return normalized
        }

        let extent = input.extent
        let output: CIImage
        switch filterType {
        case .sepia:
            output = sepiaImage(input).cropped(to: extent)
        case .nostalgic:
            output = nostalgicImage(input).cropped(to: extent)
        case .monochrome:
            output = monochromeImage(input).cropped(to: extent)
        }

        guard let cgImage = ciContext.createCGImage(output, from: extent) else {
            return normalized
        }
        return UIImage(cgImage: cgImage)
    }

    private static func normalizedImage(_ image: UIImage, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: aspectFitRect(imageSize: image.size, targetSize: size))
        }
    }

    private static func sepiaImage(_ image: CIImage) -> CIImage {
        let sepia = CIFilter(name: "CISepiaTone")
        sepia?.setValue(image, forKey: kCIInputImageKey)
        sepia?.setValue(0.70, forKey: kCIInputIntensityKey)
        return colorControlled(
            sepia?.outputImage ?? image,
            saturation: 0.90,
            contrast: 0.95,
            brightness: 0.0
        )
    }

    private static func nostalgicImage(_ image: CIImage) -> CIImage {
        let controlled = colorControlled(
            image,
            saturation: 0.82,
            contrast: 0.90,
            brightness: 0.012
        )
        let curved = toneCurvedNostalgic(controlled)
        let warmed = subtlyWarmed(curved)
        return beigeSoftLightOverlay(warmed, opacity: 0.06)
    }

    private static func monochromeImage(_ image: CIImage) -> CIImage {
        let mono = CIFilter(name: "CIPhotoEffectMono")
        mono?.setValue(image, forKey: kCIInputImageKey)
        return colorControlled(
            mono?.outputImage ?? image,
            saturation: 1.0,
            contrast: 0.99,
            brightness: 0.006
        )
    }

    private static func colorControlled(
        _ image: CIImage,
        saturation: CGFloat,
        contrast: CGFloat,
        brightness: CGFloat
    ) -> CIImage {
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(saturation, forKey: kCIInputSaturationKey)
        filter?.setValue(contrast, forKey: kCIInputContrastKey)
        filter?.setValue(brightness, forKey: kCIInputBrightnessKey)
        return filter?.outputImage ?? image
    }

    private static func toneCurvedNostalgic(_ image: CIImage) -> CIImage {
        let filter = CIFilter(name: "CIToneCurve")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(x: 0.00, y: 0.07), forKey: "inputPoint0")
        filter?.setValue(CIVector(x: 0.25, y: 0.23), forKey: "inputPoint1")
        filter?.setValue(CIVector(x: 0.50, y: 0.50), forKey: "inputPoint2")
        filter?.setValue(CIVector(x: 0.78, y: 0.74), forKey: "inputPoint3")
        filter?.setValue(CIVector(x: 1.00, y: 0.93), forKey: "inputPoint4")
        return filter?.outputImage ?? image
    }

    private static func subtlyWarmed(_ image: CIImage) -> CIImage {
        let filter = CIFilter(name: "CIColorMatrix")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(x: 1.020, y: 0.010, z: 0.000, w: 0), forKey: "inputRVector")
        filter?.setValue(CIVector(x: 0.010, y: 1.012, z: 0.000, w: 0), forKey: "inputGVector")
        filter?.setValue(CIVector(x: -0.010, y: -0.006, z: 0.945, w: 0), forKey: "inputBVector")
        filter?.setValue(CIVector(x: 0.006, y: 0.004, z: -0.002, w: 0), forKey: "inputBiasVector")
        return filter?.outputImage ?? image
    }

    private static func beigeSoftLightOverlay(_ image: CIImage, opacity: CGFloat) -> CIImage {
        guard opacity > 0,
              let overlay = constantImage(
                color: CIColor(red: 0.96, green: 0.86, blue: 0.68, alpha: opacity),
                extent: image.extent
              )
        else {
            return image
        }

        let blend = CIFilter(name: "CISoftLightBlendMode")
        blend?.setValue(overlay, forKey: kCIInputImageKey)
        blend?.setValue(image, forKey: kCIInputBackgroundImageKey)
        return blend?.outputImage?.cropped(to: image.extent) ?? image
    }

    private static func constantImage(color: CIColor, extent: CGRect) -> CIImage? {
        let filter = CIFilter(name: "CIConstantColorGenerator")
        filter?.setValue(color, forKey: kCIInputColorKey)
        return filter?.outputImage?.cropped(to: extent)
    }

    private static func aspectFitRect(imageSize: CGSize, targetSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: targetSize)
        }

        let scale = min(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (targetSize.width - drawSize.width) / 2,
            y: (targetSize.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )
    }
}

private extension String {
    var trimmedForRenderer: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension UIImage {
    var preferredRenderSize: CGSize {
        guard size.width > 0, size.height > 0 else {
            return CardAspectRatio.fourByFive.outputSize
        }

        let maxLongSide: CGFloat = 3000
        let aspectRatio = size.width / size.height

        if aspectRatio >= 1 {
            return CGSize(width: maxLongSide, height: maxLongSide / aspectRatio)
        } else {
            return CGSize(width: maxLongSide * aspectRatio, height: maxLongSide)
        }
    }
}
