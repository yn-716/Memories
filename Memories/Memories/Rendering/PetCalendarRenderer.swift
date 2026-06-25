import Foundation
import UIKit

struct PetCalendarRenderEntry: Hashable {
    var date: Date
    var thumbnail: UIImage?
    var photoPlacement: PhotoPlacement = .default

    static func == (lhs: PetCalendarRenderEntry, rhs: PetCalendarRenderEntry) -> Bool {
        PetCalendarDateRules.id(for: lhs.date) == PetCalendarDateRules.id(for: rhs.date)
            && lhs.thumbnail === rhs.thumbnail
            && lhs.photoPlacement == rhs.photoPlacement
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(PetCalendarDateRules.id(for: date))
        hasher.combine(photoPlacement)
        hasher.combine(thumbnail.map(ObjectIdentifier.init))
    }
}

struct PetCalendarRenderConfiguration: Hashable {
    var month: Date
    var entries: [PetCalendarRenderEntry]
    var displayLanguage: PetCalendarDisplayLanguage
    var watermarkMode: WatermarkMode
    var now: Date
    var size: CGSize

    init(
        month: Date,
        entries: [PetCalendarRenderEntry],
        displayLanguage: PetCalendarDisplayLanguage,
        watermarkMode: WatermarkMode,
        now: Date = Date(),
        size: CGSize = CGSize(width: 1600, height: 2200)
    ) {
        self.month = month
        self.entries = entries
        self.displayLanguage = displayLanguage
        self.watermarkMode = watermarkMode
        self.now = now
        self.size = size
    }
}

protocol CalendarWatermarkDrawing {
    func drawCalendarWatermark(mode: WatermarkMode, in context: CGContext, size: CGSize, bounds: CGRect)
}

struct DefaultCalendarWatermarkDrawer: CalendarWatermarkDrawing {
    func drawCalendarWatermark(mode: WatermarkMode, in context: CGContext, size: CGSize, bounds: CGRect) {
        CalendarWatermarkRenderer().draw(mode: mode, in: context, canvasSize: size, footerRect: bounds)
    }
}

struct CalendarWatermarkRenderer {
    func draw(mode: WatermarkMode, in context: CGContext, canvasSize: CGSize, footerRect: CGRect) {
        guard mode == .visible else {
            return
        }

        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }

        let text = WatermarkRenderer.brandName
        let pillHeight = max(58, min(78, canvasSize.height * 0.036))
        let iconSide = pillHeight * 0.62
        let font = UIFont.systemFont(ofSize: pillHeight * 0.34, weight: .semibold)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.92)
        ]
        let textSize = NSString(string: text).size(withAttributes: textAttributes)
        let horizontalPadding = pillHeight * 0.30
        let spacing = pillHeight * 0.18
        let appIcon = UIImage(named: "watermark_app_icon")
        let iconWidth = appIcon == nil ? CGFloat.zero : iconSide
        let iconSpacing = appIcon == nil ? CGFloat.zero : spacing
        let rawWidth = horizontalPadding * 2 + iconWidth + iconSpacing + textSize.width
        let pillWidth = min(rawWidth, footerRect.width * 0.58)
        let pill = CGRect(
            x: footerRect.maxX - pillWidth,
            y: footerRect.midY - pillHeight / 2,
            width: pillWidth,
            height: pillHeight
        )

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 10), blur: 22, color: UIColor.black.withAlphaComponent(0.18).cgColor)
        let path = UIBezierPath(roundedRect: pill, cornerRadius: pillHeight / 2)
        UIColor.black.withAlphaComponent(0.46).setFill()
        path.fill()
        context.restoreGState()

        UIColor.white.withAlphaComponent(0.22).setStroke()
        path.lineWidth = 1.5
        path.stroke()

        let iconRect = CGRect(
            x: pill.minX + horizontalPadding,
            y: pill.midY - iconSide / 2,
            width: iconSide,
            height: iconSide
        )
        if let appIcon {
            context.saveGState()
            UIBezierPath(roundedRect: iconRect, cornerRadius: iconSide * 0.18).addClip()
            appIcon.draw(in: iconRect, blendMode: .normal, alpha: 0.76)
            context.restoreGState()
        }

        let textMinX = appIcon == nil ? pill.minX + horizontalPadding : iconRect.maxX + iconSpacing
        let textRect = CGRect(
            x: textMinX,
            y: pill.midY - textSize.height / 2,
            width: pill.maxX - textMinX - horizontalPadding,
            height: textSize.height
        )
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byTruncatingTail
        NSString(string: text).draw(
            with: textRect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: [
                .font: font,
                .foregroundColor: UIColor.white.withAlphaComponent(0.92),
                .paragraphStyle: paragraph
            ],
            context: nil
        )
    }
}

struct PetCalendarRenderer {
    var calendar: Calendar = PetCalendarDateRules.gregorianCalendar()
    var watermarkDrawer: CalendarWatermarkDrawing = DefaultCalendarWatermarkDrawer()

    func render(configuration: PetCalendarRenderConfiguration) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: configuration.size, format: format)

        return renderer.image { rendererContext in
            let context = rendererContext.cgContext
            let bounds = CGRect(origin: .zero, size: configuration.size)
            drawBackground(in: context, bounds: bounds)
            drawCalendar(configuration: configuration, in: context, bounds: bounds)

            if configuration.watermarkMode == .visible {
                let footerBounds = CGRect(
                    x: bounds.minX + 70,
                    y: bounds.maxY - 190,
                    width: bounds.width - 140,
                    height: 110
                )
                watermarkDrawer.drawCalendarWatermark(
                    mode: configuration.watermarkMode,
                    in: context,
                    size: configuration.size,
                    bounds: footerBounds
                )
            }
        }
    }

    private func drawBackground(in context: CGContext, bounds: CGRect) {
        context.clear(bounds)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            UIColor(hex: "#FAFDFF").withAlphaComponent(0.72).cgColor,
            UIColor(hex: "#F2F9FC").withAlphaComponent(0.42).cgColor,
            UIColor(hex: "#E4F1F6").withAlphaComponent(0.24).cgColor,
            UIColor(hex: "#FFFFFF").withAlphaComponent(0.34).cgColor
        ] as CFArray
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.42, 0.78, 1])
        context.drawLinearGradient(
            gradient!,
            start: CGPoint(x: bounds.minX, y: bounds.minY),
            end: CGPoint(x: bounds.maxX, y: bounds.maxY),
            options: []
        )

        let frame = bounds.insetBy(dx: 46, dy: 46)
        drawGlassPanel(in: frame, cornerRadius: 42, context: context)
    }

    private func drawGlassPanel(in rect: CGRect, cornerRadius: CGFloat, context: CGContext) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 28), blur: 48, color: UIColor(hex: "#4F7FA3").withAlphaComponent(0.16).cgColor)
        UIColor.white.withAlphaComponent(0.16).setFill()
        path.fill()
        context.restoreGState()

        context.saveGState()
        path.addClip()
        drawAquaGradient(
            in: rect,
            context: context,
            colors: [
                UIColor.white.withAlphaComponent(0.22),
                UIColor(hex: "#F3FAFD").withAlphaComponent(0.16),
                UIColor(hex: "#DDECF2").withAlphaComponent(0.10)
            ]
        )
        context.restoreGState()

        UIColor.white.withAlphaComponent(0.58).setStroke()
        path.lineWidth = 3
        path.stroke()

        UIColor(hex: "#D7E8EF").withAlphaComponent(0.42).setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    private func drawCalendar(configuration: PetCalendarRenderConfiguration, in context: CGContext, bounds: CGRect) {
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }

        let content = bounds.insetBy(dx: 90, dy: 90)
        let title = PetCalendarDateRules.monthTitle(
            for: configuration.month,
            language: configuration.displayLanguage,
            calendar: calendar
        )
        drawText(
            title,
            in: CGRect(x: content.minX, y: content.minY + 12, width: content.width, height: 80),
            font: .systemFont(ofSize: 54, weight: .bold),
            color: UIColor(hex: "#1F3447"),
            alignment: .center
        )

        let weekdayTop = content.minY + 124
        let gridTop = weekdayTop + 70
        let cellWidth = content.width / 7
        let weekdays = PetCalendarDateRules.weekdaySymbols(language: configuration.displayLanguage)

        for index in 0..<7 {
            drawText(
                weekdays[index],
                in: CGRect(x: content.minX + CGFloat(index) * cellWidth, y: weekdayTop, width: cellWidth, height: 48),
                font: .systemFont(ofSize: 30, weight: .semibold),
                color: UIColor(hex: "#4F7FA3"),
                alignment: .center
            )
        }

        let entriesByID = Dictionary(uniqueKeysWithValues: configuration.entries.map {
            (PetCalendarDateRules.id(for: $0.date, calendar: calendar), $0)
        })
        let cells = PetCalendarDateRules.monthGrid(
            for: configuration.month,
            now: configuration.now,
            calendar: calendar
        )
        let rowCount = max(1, cells.count / 7)
        let gridHeight = content.height - 260
        let cellHeight = gridHeight / CGFloat(rowCount)

        for (index, cell) in cells.enumerated() {
            let row = index / 7
            let column = index % 7
            let rect = CGRect(
                x: content.minX + CGFloat(column) * cellWidth,
                y: gridTop + CGFloat(row) * cellHeight,
                width: cellWidth,
                height: cellHeight
            ).insetBy(dx: 4, dy: 4)
            drawCell(cell, entry: entriesByID[cell.id], in: rect, context: context)
        }
    }

    private func drawCell(
        _ cell: PetCalendarMonthCell,
        entry: PetCalendarRenderEntry?,
        in rect: CGRect,
        context: CGContext
    ) {
        let radius: CGFloat = 18
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        context.saveGState()
        path.addClip()
        drawAquaGradient(
            in: rect,
            context: context,
            colors: [
                UIColor.white.withAlphaComponent(cell.isInDisplayedMonth ? 0.16 : 0.05),
                UIColor(hex: "#F2FAFD").withAlphaComponent(cell.isInDisplayedMonth ? 0.14 : 0.04),
                UIColor(hex: "#DCECF2").withAlphaComponent(cell.isInDisplayedMonth ? 0.08 : 0.03)
            ]
        )
        context.restoreGState()
        let baseStroke = entry == nil
            ? UIColor(hex: "#D4E6EE").withAlphaComponent(cell.isInDisplayedMonth ? 0.50 : 0.18)
            : UIColor(hex: "#93C8ED").withAlphaComponent(0.96)
        baseStroke.setStroke()
        path.lineWidth = entry == nil ? 2 : 3
        path.stroke()

        guard cell.isInDisplayedMonth else {
            drawText(
                "\(cell.dayNumber)",
                in: rect.insetBy(dx: 12, dy: 10),
                font: .systemFont(ofSize: 24, weight: .semibold),
                color: UIColor(hex: "#6B7D8C").withAlphaComponent(0.25),
                alignment: .left
            )
            return
        }

        context.saveGState()
        path.addClip()
        if let entry, let thumbnail = entry.thumbnail {
            drawImage(thumbnail, in: rect, placement: entry.photoPlacement)
            UIColor.black.withAlphaComponent(0.06).setFill()
            context.fill(rect)
        } else {
            UIColor.white.withAlphaComponent(cell.isFuture ? 0.04 : 0.08).setFill()
            context.fill(rect)
            drawPaw(in: rect.insetBy(dx: rect.width * 0.23, dy: rect.height * 0.22), alpha: cell.isFuture ? 0.08 : 0.18)
        }
        context.restoreGState()

        if cell.isToday {
            let todayPath = UIBezierPath(roundedRect: rect.insetBy(dx: 3, dy: 3), cornerRadius: radius - 2)
            UIColor(hex: "#4F7FA3").setStroke()
            todayPath.lineWidth = 5
            todayPath.stroke()
        }

        let numberColor: UIColor = entry == nil ? UIColor(hex: "#1F3447") : .white
        drawText(
            "\(cell.dayNumber)",
            in: CGRect(x: rect.minX + 12, y: rect.minY + 8, width: rect.width - 24, height: 30),
            font: .systemFont(ofSize: 26, weight: .bold),
            color: numberColor.withAlphaComponent(cell.isFuture ? 0.38 : 0.94),
            alignment: .left
        )

        if cell.isFuture {
            UIColor.white.withAlphaComponent(0.28).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: radius).fill()
        }
    }

    private func drawAquaGradient(in rect: CGRect, context: CGContext, colors: [UIColor]) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors.map { $0.cgColor } as CFArray,
            locations: [0, 0.56, 1]
        )
        context.drawLinearGradient(
            gradient!,
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY),
            options: []
        )
    }

    private func drawImage(_ image: UIImage, in rect: CGRect, placement: PhotoPlacement) {
        let drawRect = PhotoPlacementLayout.drawRect(imageSize: image.size, frameRect: rect, placement: placement)
        image.draw(in: drawRect)
    }

    private func drawPaw(in rect: CGRect, alpha: CGFloat) {
        UIColor(hex: "#4F7FA3").withAlphaComponent(alpha).setFill()
        Self.drawPawPath(in: rect).fill()
    }

    static func drawPawPath(in rect: CGRect) -> UIBezierPath {
        let side = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        let path = UIBezierPath()
        let toeSize = side * 0.18
        let toeCenters = [
            CGPoint(x: origin.x + side * 0.24, y: origin.y + side * 0.28),
            CGPoint(x: origin.x + side * 0.42, y: origin.y + side * 0.20),
            CGPoint(x: origin.x + side * 0.58, y: origin.y + side * 0.20),
            CGPoint(x: origin.x + side * 0.76, y: origin.y + side * 0.28)
        ]
        for center in toeCenters {
            path.append(UIBezierPath(ovalIn: CGRect(
                x: center.x - toeSize / 2,
                y: center.y - toeSize / 2,
                width: toeSize,
                height: toeSize * 1.12
            )))
        }

        let padRect = CGRect(
            x: origin.x + side * 0.30,
            y: origin.y + side * 0.46,
            width: side * 0.40,
            height: side * 0.36
        )
        path.append(UIBezierPath(roundedRect: padRect, cornerRadius: side * 0.18))
        return path
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
        NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes, context: nil)
    }
}
