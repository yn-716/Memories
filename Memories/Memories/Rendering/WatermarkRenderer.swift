import UIKit

enum WatermarkMode: Hashable {
    case visible
    case hidden
}

struct WatermarkPolicy: Hashable {
    var mode: WatermarkMode

    static let freeDefault = WatermarkPolicy(mode: .visible)

    var shouldShowWatermark: Bool {
        mode == .visible
    }
}

struct WatermarkRenderer {
    private static let brandName = "Memories Pet Life"

    func draw(
        mode: WatermarkMode,
        overlayPosition: OverlayPosition,
        in context: CGContext,
        size: CGSize,
        bounds: CGRect? = nil
    ) {
        draw(policy: WatermarkPolicy(mode: mode), overlayPosition: overlayPosition, in: context, size: size, bounds: bounds)
    }

    func draw(
        policy: WatermarkPolicy,
        overlayPosition: OverlayPosition,
        in context: CGContext,
        size: CGSize,
        bounds: CGRect? = nil
    ) {
        guard policy.shouldShowWatermark else {
            return
        }

        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }

        let drawingBounds = bounds ?? CGRect(origin: .zero, size: size)
        let base = min(drawingBounds.width, drawingBounds.height)
        let watermarkPosition = Self.oppositeWatermarkPosition(for: overlayPosition)
        let pillHeight = max(34, base * 0.068)
        let iconSide = pillHeight * 0.62
        let fontSize = pillHeight * 0.36
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let text = Self.brandName
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.78)
        ]
        let textSize = NSString(string: text).size(withAttributes: textAttributes)
        let horizontalPadding = pillHeight * 0.28
        let spacing = pillHeight * 0.18
        let rawWidth = horizontalPadding * 2 + iconSide + spacing + textSize.width
        let pillWidth = min(max(rawWidth, base * 0.28), base * 0.46)
        let inset = max(18, base * 0.056)
        let origin = origin(
            for: watermarkPosition,
            watermarkSize: CGSize(width: pillWidth, height: pillHeight),
            inset: inset,
            bounds: drawingBounds
        )
        let rect = CGRect(origin: origin, size: CGSize(width: pillWidth, height: pillHeight))

        let path = UIBezierPath(roundedRect: rect, cornerRadius: pillHeight * 0.34)
        UIColor.black.withAlphaComponent(0.28).setFill()
        path.fill()
        UIColor.white.withAlphaComponent(0.2).setStroke()
        path.lineWidth = max(1, base * 0.001)
        path.stroke()

        let iconRect = CGRect(
            x: rect.minX + horizontalPadding,
            y: rect.midY - iconSide / 2,
            width: iconSide,
            height: iconSide
        )
        let textOrigin = CGPoint(
            x: iconRect.maxX + spacing,
            y: rect.midY - textSize.height / 2
        )

        guard let image = UIImage(named: "watermark_app_icon") else {
            drawFallbackText(in: rect, canvasSize: size)
            return
        }

        context.saveGState()
        UIBezierPath(roundedRect: iconRect, cornerRadius: iconSide * 0.18).addClip()
        image.draw(in: iconRect, blendMode: .normal, alpha: 0.62)
        context.restoreGState()

        NSString(string: text).draw(at: textOrigin, withAttributes: textAttributes)
    }

    static func oppositeWatermarkPosition(for overlayPosition: OverlayPosition) -> OverlayPosition {
        switch overlayPosition {
        case .topLeft:
            return .bottomRight
        case .topRight:
            return .bottomLeft
        case .bottomLeft:
            return .topRight
        case .bottomRight:
            return .topLeft
        }
    }

    private func origin(for position: OverlayPosition, watermarkSize: CGSize, inset: CGFloat, bounds: CGRect) -> CGPoint {
        let x = position.isTrailing ? bounds.maxX - inset - watermarkSize.width : bounds.minX + inset
        let y = position.isBottom ? bounds.maxY - inset - watermarkSize.height : bounds.minY + inset
        return CGPoint(x: x, y: y)
    }

    private func drawFallbackText(in rect: CGRect, canvasSize: CGSize) {
        let fontSize = max(10, min(canvasSize.width, canvasSize.height) * 0.022)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.42)
        ]
        NSString(string: Self.brandName).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
    }
}
