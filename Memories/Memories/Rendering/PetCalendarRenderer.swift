import Foundation
import UIKit

struct PetCalendarRenderEntry: Hashable {
    var date: Date
    var caption: String
    var thumbnail: UIImage?

    static func == (lhs: PetCalendarRenderEntry, rhs: PetCalendarRenderEntry) -> Bool {
        PetCalendarDateRules.id(for: lhs.date) == PetCalendarDateRules.id(for: rhs.date)
            && lhs.caption == rhs.caption
            && lhs.thumbnail === rhs.thumbnail
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(PetCalendarDateRules.id(for: date))
        hasher.combine(caption)
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
        WatermarkRenderer().draw(
            mode: mode,
            overlayPosition: .topLeft,
            in: context,
            size: size,
            bounds: bounds
        )
    }
}

struct PetCalendarRenderer {
    var calendar: Calendar = PetCalendarDateRules.gregorianCalendar()
    var watermarkDrawer: CalendarWatermarkDrawing = DefaultCalendarWatermarkDrawer()

    func render(configuration: PetCalendarRenderConfiguration) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: configuration.size, format: format)

        return renderer.image { rendererContext in
            let context = rendererContext.cgContext
            let bounds = CGRect(origin: .zero, size: configuration.size)
            drawBackground(in: context, bounds: bounds)
            drawCalendar(configuration: configuration, in: context, bounds: bounds)

            if configuration.watermarkMode == .visible {
                let footerBounds = CGRect(
                    x: bounds.minX + 70,
                    y: bounds.maxY - 210,
                    width: bounds.width - 140,
                    height: 130
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
        UIColor(hex: "#F6FAFF").setFill()
        context.fill(bounds)

        let frame = bounds.insetBy(dx: 46, dy: 46)
        let path = UIBezierPath(roundedRect: frame, cornerRadius: 42)
        UIColor.white.setFill()
        path.fill()
        UIColor(hex: "#D8E8F5").withAlphaComponent(0.9).setStroke()
        path.lineWidth = 3
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
        let gridHeight = content.height - 260
        let cellWidth = content.width / 7
        let cellHeight = gridHeight / 6
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

        for (index, cell) in cells.enumerated() {
            let row = index / 7
            let column = index % 7
            let rect = CGRect(
                x: content.minX + CGFloat(column) * cellWidth,
                y: gridTop + CGFloat(row) * cellHeight,
                width: cellWidth,
                height: cellHeight
            ).insetBy(dx: 6, dy: 6)
            drawCell(cell, entry: entriesByID[cell.id], in: rect, context: context)
        }

        drawText(
            WatermarkRenderer.brandName,
            in: CGRect(x: content.minX, y: content.maxY - 64, width: content.width, height: 40),
            font: .systemFont(ofSize: 24, weight: .semibold),
            color: UIColor(hex: "#6B7D8C").withAlphaComponent(0.42),
            alignment: .center
        )
    }

    private func drawCell(
        _ cell: PetCalendarMonthCell,
        entry: PetCalendarRenderEntry?,
        in rect: CGRect,
        context: CGContext
    ) {
        let radius: CGFloat = 18
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        UIColor(hex: "#FFFFFF").setFill()
        path.fill()
        UIColor(hex: "#D8E8F5").withAlphaComponent(cell.isInDisplayedMonth ? 0.88 : 0.32).setStroke()
        path.lineWidth = 2
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
            drawImage(thumbnail, in: rect)
            UIColor.black.withAlphaComponent(0.16).setFill()
            context.fill(rect)
        } else {
            UIColor(hex: "#E6ECF2").setFill()
            context.fill(rect)
            drawPaw(in: rect.insetBy(dx: rect.width * 0.22, dy: rect.height * 0.22), alpha: cell.isFuture ? 0.12 : 0.24)
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

        if let caption = entry?.caption, !caption.isEmpty {
            let captionRect = CGRect(x: rect.minX + 10, y: rect.maxY - 38, width: rect.width - 20, height: 28)
            UIColor.black.withAlphaComponent(0.28).setFill()
            UIBezierPath(roundedRect: captionRect.insetBy(dx: -5, dy: -2), cornerRadius: 9).fill()
            drawText(
                caption,
                in: captionRect,
                font: .systemFont(ofSize: 20, weight: .semibold),
                color: .white,
                alignment: .center
            )
        }

        if cell.isFuture {
            UIColor.white.withAlphaComponent(0.48).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: radius).fill()
        }
    }

    private func drawImage(_ image: UIImage, in rect: CGRect) {
        let imageRatio = image.size.width / max(image.size.height, 1)
        let rectRatio = rect.width / max(rect.height, 1)
        let drawSize: CGSize
        if imageRatio > rectRatio {
            drawSize = CGSize(width: rect.height * imageRatio, height: rect.height)
        } else {
            drawSize = CGSize(width: rect.width, height: rect.width / max(imageRatio, 0.001))
        }

        let drawRect = CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        image.draw(in: drawRect)
    }

    private func drawPaw(in rect: CGRect, alpha: CGFloat) {
        UIColor(hex: "#4F7FA3").withAlphaComponent(alpha).setFill()
        let pad = min(rect.width, rect.height)
        let toeSize = pad * 0.22
        let toeY = rect.minY + pad * 0.05
        let toeCenters = [
            CGPoint(x: rect.midX - pad * 0.25, y: toeY + toeSize),
            CGPoint(x: rect.midX, y: toeY + toeSize * 0.55),
            CGPoint(x: rect.midX + pad * 0.25, y: toeY + toeSize),
            CGPoint(x: rect.midX - pad * 0.02, y: toeY + toeSize * 1.25)
        ]
        for center in toeCenters {
            UIBezierPath(ovalIn: CGRect(
                x: center.x - toeSize / 2,
                y: center.y - toeSize / 2,
                width: toeSize,
                height: toeSize
            )).fill()
        }

        let padRect = CGRect(
            x: rect.midX - pad * 0.24,
            y: rect.midY - pad * 0.04,
            width: pad * 0.48,
            height: pad * 0.42
        )
        UIBezierPath(ovalIn: padRect).fill()
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
