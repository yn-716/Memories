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
