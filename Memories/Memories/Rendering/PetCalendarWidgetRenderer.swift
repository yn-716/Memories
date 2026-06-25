import Foundation
import UIKit

enum PetCalendarWidgetRenderedImageFamily: CaseIterable {
    case small
    case medium
    case large

    var fileName: String {
        switch self {
        case .small:
            return "pet-calendar-widget-small.jpg"
        case .medium:
            return "pet-calendar-widget-medium.jpg"
        case .large:
            return "pet-calendar-widget-large.jpg"
        }
    }

    var size: CGSize {
        switch self {
        case .small:
            return CGSize(width: 540, height: 540)
        case .medium:
            return CGSize(width: 1080, height: 510)
        case .large:
            return CGSize(width: 1080, height: 1080)
        }
    }
}

struct PetCalendarWidgetRenderedImage {
    var family: PetCalendarWidgetRenderedImageFamily
    var fileName: String
    var image: UIImage
}

struct PetCalendarWidgetRenderer {
    private let calendar = PetCalendarDateRules.gregorianCalendar()

    func renderAll(
        snapshot: PetCalendarWidgetSnapshot,
        entries: [PetCalendarDayEntry],
        thumbnailsByID: [String: UIImage],
        now: Date
    ) -> [PetCalendarWidgetRenderedImage] {
        PetCalendarWidgetRenderedImageFamily.allCases.map { family in
            PetCalendarWidgetRenderedImage(
                family: family,
                fileName: family.fileName,
                image: render(
                    family: family,
                    snapshot: snapshot,
                    entries: entries,
                    thumbnailsByID: thumbnailsByID,
                    now: now
                )
            )
        }
    }

    private func render(
        family: PetCalendarWidgetRenderedImageFamily,
        snapshot: PetCalendarWidgetSnapshot,
        entries: [PetCalendarDayEntry],
        thumbnailsByID: [String: UIImage],
        now: Date
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: family.size, format: format)

        return renderer.image { rendererContext in
            let context = rendererContext.cgContext
            let bounds = CGRect(origin: .zero, size: family.size)
            drawBackground(in: context, bounds: bounds)

            switch family {
            case .small:
                drawSmallWidget(snapshot: snapshot, entries: entries, thumbnailsByID: thumbnailsByID, now: now, in: context, bounds: bounds)
            case .medium:
                drawMonthWidget(snapshot: snapshot, entries: entries, thumbnailsByID: thumbnailsByID, now: now, in: context, bounds: bounds, isLarge: false)
            case .large:
                drawMonthWidget(snapshot: snapshot, entries: entries, thumbnailsByID: thumbnailsByID, now: now, in: context, bounds: bounds, isLarge: true)
            }
        }
    }

    private func drawBackground(in context: CGContext, bounds: CGRect) {
        UIColor(hex: "#F7FCFF").setFill()
        context.fill(bounds)
        drawLinearGradient(
            in: bounds,
            context: context,
            colors: [
                UIColor.white.withAlphaComponent(0.88),
                UIColor(hex: "#F1F9FC").withAlphaComponent(0.78),
                UIColor(hex: "#E7F2F6").withAlphaComponent(0.70)
            ]
        )
    }

    private func drawSmallWidget(
        snapshot: PetCalendarWidgetSnapshot,
        entries: [PetCalendarDayEntry],
        thumbnailsByID: [String: UIImage],
        now: Date,
        in context: CGContext,
        bounds: CGRect
    ) {
        let card = bounds.insetBy(dx: 20, dy: 20)
        let entry = todayEntry(entries: entries, now: now) ?? featuredEntry(entries: entries, now: now)
        let image = entry.flatMap { thumbnailsByID[$0.id] }

        drawGlassSurface(in: card, cornerRadius: 52, context: context)
        context.saveGState()
        UIBezierPath(roundedRect: card, cornerRadius: 52).addClip()

        if let entry, let image {
            drawImage(image, in: card, placement: entry.photoPlacement)
            UIColor.black.withAlphaComponent(0.18).setFill()
            context.fill(card)
            drawTopFade(in: card, context: context)
        } else if entry?.overlayStyle.effectiveWeatherIcon == nil {
            UIColor(hex: "#4F7FA3").withAlphaComponent(0.14).setFill()
            PetCalendarRenderer.drawPawPath(in: card.insetBy(dx: card.width * 0.30, dy: card.height * 0.30)).fill()
        }
        context.restoreGState()

        let displayDate = entry?.date ?? now
        let title = PetCalendarDateRules.shortDateTitle(for: displayDate, language: snapshot.displayLanguage, calendar: calendar)
        let titleColor: UIColor = image == nil ? UIColor(hex: "#1F3447") : .white
        drawText(
            title,
            in: CGRect(x: card.minX + 34, y: card.minY + 32, width: card.width - 68, height: 58),
            font: .systemFont(ofSize: 46, weight: .bold),
            color: titleColor.withAlphaComponent(0.96),
            alignment: .left
        )
        drawText(
            weekdayTitle(for: displayDate, language: snapshot.displayLanguage),
            in: CGRect(x: card.minX + 36, y: card.minY + 88, width: card.width - 72, height: 40),
            font: .systemFont(ofSize: 27, weight: .semibold),
            color: titleColor.withAlphaComponent(0.80),
            alignment: .left
        )

        if let entry, let weatherIcon = entry.overlayStyle.effectiveWeatherIcon {
            drawWeatherIcon(weatherIcon, style: entry.overlayStyle, usesPhotoBackground: image != nil, in: card.insetBy(dx: 26, dy: 26), context: context)
        }

        if snapshot.showsBranding {
            drawWatermark(
                in: CGRect(x: card.minX + 28, y: card.maxY - 76, width: min(card.width - 56, 265), height: 44),
                context: context,
                compact: true
            )
        }
    }

    private func drawMonthWidget(
        snapshot: PetCalendarWidgetSnapshot,
        entries: [PetCalendarDayEntry],
        thumbnailsByID: [String: UIImage],
        now: Date,
        in context: CGContext,
        bounds: CGRect,
        isLarge: Bool
    ) {
        let outerInset: CGFloat = isLarge ? 42 : 30
        let card = bounds.insetBy(dx: outerInset, dy: outerInset)
        drawGlassSurface(in: card, cornerRadius: isLarge ? 56 : 42, context: context)

        let entriesByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        let content = card.insetBy(dx: isLarge ? 56 : 42, dy: isLarge ? 48 : 30)
        let titleHeight: CGFloat = isLarge ? 62 : 42
        drawText(
            PetCalendarDateRules.monthTitle(for: snapshot.selectedMonth, language: snapshot.displayLanguage, calendar: calendar),
            in: CGRect(x: content.minX, y: content.minY, width: content.width * 0.62, height: titleHeight),
            font: .systemFont(ofSize: isLarge ? 43 : 31, weight: .bold),
            color: UIColor(hex: "#1F3447"),
            alignment: .left
        )

        if snapshot.showsBranding {
            let watermarkWidth: CGFloat = isLarge ? 250 : 210
            drawWatermark(
                in: CGRect(x: content.maxX - watermarkWidth, y: content.minY + 4, width: watermarkWidth, height: isLarge ? 42 : 34),
                context: context,
                compact: !isLarge
            )
        }

        let weekdayTop = content.minY + titleHeight + (isLarge ? 22 : 12)
        let weekdayHeight: CGFloat = isLarge ? 34 : 24
        let gridTop = weekdayTop + weekdayHeight + (isLarge ? 18 : 10)
        let cells = PetCalendarDateRules.monthGrid(for: snapshot.selectedMonth, now: now, calendar: calendar)
        let rowCount = max(1, cells.count / 7)
        let columnSpacing: CGFloat = isLarge ? 8 : 5
        let rowSpacing: CGFloat = isLarge ? 8 : 5
        let cellWidth = (content.width - columnSpacing * 6) / 7
        let gridHeight = max(1, content.maxY - gridTop)
        let cellHeight = (gridHeight - rowSpacing * CGFloat(rowCount - 1)) / CGFloat(rowCount)
        let weekdaySymbols = PetCalendarDateRules.weekdaySymbols(language: snapshot.displayLanguage)

        for index in 0..<7 {
            drawText(
                weekdaySymbols[index],
                in: CGRect(
                    x: content.minX + CGFloat(index) * (cellWidth + columnSpacing),
                    y: weekdayTop,
                    width: cellWidth,
                    height: weekdayHeight
                ),
                font: .systemFont(ofSize: isLarge ? 24 : 17, weight: .semibold),
                color: UIColor(hex: "#4F7FA3").withAlphaComponent(0.78),
                alignment: .center
            )
        }

        for (index, cell) in cells.enumerated() {
            let row = index / 7
            let column = index % 7
            let rect = CGRect(
                x: content.minX + CGFloat(column) * (cellWidth + columnSpacing),
                y: gridTop + CGFloat(row) * (cellHeight + rowSpacing),
                width: cellWidth,
                height: cellHeight
            )
            let entry = entriesByID[cell.id]
            drawCell(
                cell,
                entry: entry,
                thumbnail: entry.flatMap { thumbnailsByID[$0.id] },
                in: rect,
                context: context,
                isLarge: isLarge
            )
        }
    }

    private func drawCell(
        _ cell: PetCalendarMonthCell,
        entry: PetCalendarDayEntry?,
        thumbnail: UIImage?,
        in rect: CGRect,
        context: CGContext,
        isLarge: Bool
    ) {
        let cornerRadius: CGFloat = isLarge ? 16 : 10
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        drawGlassSurface(in: rect, cornerRadius: cornerRadius, context: context, shadowAlpha: 0.02)

        context.saveGState()
        path.addClip()
        if let entry, let thumbnail {
            drawImage(thumbnail, in: rect, placement: entry.photoPlacement)
            UIColor.black.withAlphaComponent(0.08).setFill()
            context.fill(rect)
        } else if cell.isInDisplayedMonth, entry?.overlayStyle.effectiveWeatherIcon == nil {
            UIColor(hex: "#4F7FA3").withAlphaComponent(cell.isFuture ? 0.06 : 0.13).setFill()
            PetCalendarRenderer.drawPawPath(in: rect.insetBy(dx: rect.width * 0.29, dy: rect.height * 0.26)).fill()
        }
        context.restoreGState()

        let strokeColor = entry == nil
            ? UIColor.white.withAlphaComponent(cell.isInDisplayedMonth ? 0.42 : 0.16)
            : UIColor(hex: "#4F9FEF").withAlphaComponent(0.96)
        strokeColor.setStroke()
        path.lineWidth = entry == nil ? 1.5 : 3
        path.stroke()

        if cell.isToday {
            UIColor(hex: "#138BFF").setStroke()
            let todayPath = UIBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: cornerRadius - 1)
            todayPath.lineWidth = 3
            todayPath.stroke()
        }

        let dateColor: UIColor = thumbnail == nil ? UIColor(hex: "#1F3447") : .white
        let alpha: CGFloat = cell.isFuture ? 0.34 : (cell.isInDisplayedMonth ? 0.95 : 0.22)
        drawText(
            "\(cell.dayNumber)",
            in: CGRect(x: rect.minX + 8, y: rect.minY + 6, width: rect.width - 16, height: isLarge ? 28 : 20),
            font: .systemFont(ofSize: isLarge ? 22 : 15, weight: .bold),
            color: dateColor.withAlphaComponent(alpha),
            alignment: .left
        )

        if let entry, let weatherIcon = entry.overlayStyle.effectiveWeatherIcon {
            drawWeatherIcon(weatherIcon, style: entry.overlayStyle, usesPhotoBackground: thumbnail != nil, in: rect, context: context)
        }

        if cell.isFuture {
            UIColor.white.withAlphaComponent(0.22).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).fill()
        }
    }

    private func todayEntry(entries: [PetCalendarDayEntry], now: Date) -> PetCalendarDayEntry? {
        let todayID = PetCalendarDateRules.id(for: now, calendar: calendar)
        return entries.first { $0.id == todayID }
    }

    private func featuredEntry(entries: [PetCalendarDayEntry], now: Date) -> PetCalendarDayEntry? {
        let today = PetCalendarDateRules.startOfDay(for: now, calendar: calendar)
        return entries
            .filter { PetCalendarDateRules.startOfDay(for: $0.date, calendar: calendar) <= today }
            .max { $0.date < $1.date }
    }

    private func drawGlassSurface(
        in rect: CGRect,
        cornerRadius: CGFloat,
        context: CGContext,
        shadowAlpha: CGFloat = 0.10
    ) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 14), blur: 28, color: UIColor.black.withAlphaComponent(shadowAlpha).cgColor)
        UIColor.white.withAlphaComponent(0.42).setFill()
        path.fill()
        context.restoreGState()

        context.saveGState()
        path.addClip()
        drawLinearGradient(
            in: rect,
            context: context,
            colors: [
                UIColor.white.withAlphaComponent(0.55),
                UIColor(hex: "#F9FDFF").withAlphaComponent(0.32),
                UIColor(hex: "#DCEBF1").withAlphaComponent(0.18)
            ]
        )
        context.restoreGState()

        UIColor.white.withAlphaComponent(0.80).setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    private func drawLinearGradient(in rect: CGRect, context: CGContext, colors: [UIColor]) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors.map(\.cgColor) as CFArray,
            locations: [0, 0.55, 1]
        ) else {
            return
        }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY),
            options: []
        )
    }

    private func drawTopFade(in rect: CGRect, context: CGContext) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                UIColor.black.withAlphaComponent(0.40).cgColor,
                UIColor.black.withAlphaComponent(0.00).cgColor
            ] as CFArray,
            locations: [0, 1]
        ) else {
            return
        }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.minY),
            end: CGPoint(x: rect.midX, y: rect.midY),
            options: []
        )
    }

    private func drawImage(_ image: UIImage, in rect: CGRect, placement: PhotoPlacement) {
        image.draw(in: PhotoPlacementLayout.drawRect(imageSize: image.size, frameRect: rect, placement: placement))
    }

    private func drawWeatherIcon(
        _ icon: PetCalendarWeatherIcon,
        style: PetCalendarOverlayStyle,
        usesPhotoBackground: Bool,
        in rect: CGRect,
        context: CGContext
    ) {
        let minSide = min(rect.width, rect.height)
        let iconSide = max(minSide * 0.28, 20)
        let inset = max(minSide * 0.10, 7)
        let iconRect = CGRect(
            x: weatherIconCenterX(for: style.weatherIconCorner, in: rect, iconSide: iconSide, inset: inset) - iconSide / 2,
            y: weatherIconCenterY(for: style.weatherIconCorner, in: rect, iconSide: iconSide, inset: inset) - iconSide / 2,
            width: iconSide,
            height: iconSide
        )
        let configuration = UIImage.SymbolConfiguration(pointSize: iconSide * 0.74, weight: .bold)
        guard let symbol = UIImage(systemName: icon.symbolName, withConfiguration: configuration) else {
            return
        }

        context.saveGState()
        let shadowColor = usesPhotoBackground
            ? UIColor.black.withAlphaComponent(0.36)
            : UIColor.white.withAlphaComponent(0.82)
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: shadowColor.cgColor)
        symbol.withTintColor(UIColor(hex: style.accentColor.hex), renderingMode: .alwaysOriginal).draw(in: iconRect)
        context.restoreGState()
    }

    private func drawWatermark(in rect: CGRect, context: CGContext, compact: Bool) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 6), blur: 12, color: UIColor.black.withAlphaComponent(0.18).cgColor)
        UIColor.black.withAlphaComponent(0.42).setFill()
        path.fill()
        context.restoreGState()

        UIColor.white.withAlphaComponent(0.22).setStroke()
        path.lineWidth = 1
        path.stroke()

        let padding = rect.height * 0.22
        let iconSide = rect.height * 0.58
        var textMinX = rect.minX + padding
        if let icon = UIImage(named: "watermark_app_icon") {
            let iconRect = CGRect(x: rect.minX + padding, y: rect.midY - iconSide / 2, width: iconSide, height: iconSide)
            context.saveGState()
            UIBezierPath(roundedRect: iconRect, cornerRadius: iconSide * 0.18).addClip()
            icon.draw(in: iconRect, blendMode: .normal, alpha: 0.78)
            context.restoreGState()
            textMinX = iconRect.maxX + rect.height * 0.14
        }

        drawText(
            WatermarkRenderer.brandName,
            in: CGRect(x: textMinX, y: rect.minY + rect.height * 0.22, width: rect.maxX - textMinX - padding, height: rect.height * 0.58),
            font: .systemFont(ofSize: compact ? rect.height * 0.34 : rect.height * 0.36, weight: .semibold),
            color: UIColor.white.withAlphaComponent(0.92),
            alignment: .left
        )
    }

    private func weatherIconCenterX(
        for corner: PetCalendarOverlayCorner,
        in rect: CGRect,
        iconSide: CGFloat,
        inset: CGFloat
    ) -> CGFloat {
        switch corner {
        case .topLeft, .bottomLeft:
            return rect.minX + inset + iconSide / 2
        case .topRight, .bottomRight:
            return rect.maxX - inset - iconSide / 2
        }
    }

    private func weatherIconCenterY(
        for corner: PetCalendarOverlayCorner,
        in rect: CGRect,
        iconSide: CGFloat,
        inset: CGFloat
    ) -> CGFloat {
        switch corner {
        case .topLeft, .topRight:
            return rect.minY + inset + iconSide / 2
        case .bottomLeft, .bottomRight:
            return rect.maxY - inset - iconSide / 2
        }
    }

    private func weekdayTitle(for date: Date, language: PetCalendarDisplayLanguage) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        switch language {
        case .japanese:
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "E"
        case .english:
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "EEE"
        }
        return formatter.string(from: date)
    }

    private func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        NSString(string: text).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes,
            context: nil
        )
    }
}
