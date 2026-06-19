import CoreGraphics
import UIKit

struct TicketCardLayout {
    let canvasSize: CGSize
    let frameAssetName: String
    let photoFrame: CGRect
    let ticketTitleRect: CGRect
    let mainTextRect: CGRect
    let dateBoxRect: CGRect
    let locationBoxRect: CGRect
    let iconRowRect: CGRect

    static func layout(for renderStyle: TemplateRenderStyle, canvasSize: CGSize) -> TicketCardLayout? {
        switch renderStyle {
        case .simpleCard, .retroFilm:
            return nil
        case .ticketPortrait:
            return TicketCardLayout(
                canvasSize: canvasSize,
                frameAssetName: "ticket_frame_portrait",
                photoFrame: scaledRect(x: 164, y: 164, width: 1272, height: 1077, reference: CGSize(width: 1600, height: 2000), canvas: canvasSize),
                ticketTitleRect: scaledRect(x: 212, y: 1339, width: 936, height: 56, reference: CGSize(width: 1600, height: 2000), canvas: canvasSize),
                mainTextRect: scaledRect(x: 214, y: 1468, width: 860, height: 58, reference: CGSize(width: 1600, height: 2000), canvas: canvasSize),
                dateBoxRect: scaledRect(x: 214, y: 1629, width: 540, height: 76, reference: CGSize(width: 1600, height: 2000), canvas: canvasSize),
                locationBoxRect: scaledRect(x: 846, y: 1629, width: 540, height: 76, reference: CGSize(width: 1600, height: 2000), canvas: canvasSize),
                iconRowRect: scaledRect(x: 1134, y: 1383, width: 210, height: 110, reference: CGSize(width: 1600, height: 2000), canvas: canvasSize)
            )
        case .ticketLandscape:
            return TicketCardLayout(
                canvasSize: canvasSize,
                frameAssetName: "ticket_frame_landscape",
                photoFrame: scaledRect(x: 154, y: 154, width: 1362, height: 1292, reference: CGSize(width: 2400, height: 1600), canvas: canvasSize),
                ticketTitleRect: scaledRect(x: 1638, y: 206, width: 580, height: 70, reference: CGSize(width: 2400, height: 1600), canvas: canvasSize),
                mainTextRect: scaledRect(x: 1640, y: 377, width: 572, height: 70, reference: CGSize(width: 2400, height: 1600), canvas: canvasSize),
                dateBoxRect: scaledRect(x: 1640, y: 570, width: 572, height: 82, reference: CGSize(width: 2400, height: 1600), canvas: canvasSize),
                locationBoxRect: scaledRect(x: 1640, y: 722, width: 572, height: 82, reference: CGSize(width: 2400, height: 1600), canvas: canvasSize),
                iconRowRect: scaledRect(x: 2054, y: 1018, width: 210, height: 112, reference: CGSize(width: 2400, height: 1600), canvas: canvasSize)
            )
        }
    }

    static func aspectRatio(for renderStyle: TemplateRenderStyle) -> CGFloat? {
        switch renderStyle {
        case .simpleCard, .retroFilm:
            return nil
        case .ticketPortrait:
            return 4 / 5
        case .ticketLandscape:
            return 3 / 2
        }
    }

    static func iconSize(for renderStyle: TemplateRenderStyle, canvasSize: CGSize) -> CGFloat {
        let base = min(canvasSize.width, canvasSize.height)
        switch renderStyle {
        case .simpleCard, .retroFilm:
            return base * 0.07
        case .ticketPortrait:
            return base * 0.058
        case .ticketLandscape:
            return base * 0.054
        }
    }

    static func labelValueRects(in boxRect: CGRect, canvasSize: CGSize) -> (label: CGRect, value: CGRect) {
        let base = min(canvasSize.width, canvasSize.height)
        let labelHeight = base * 0.024
        let valueHeight = base * 0.036
        return (
            CGRect(x: boxRect.minX, y: boxRect.minY, width: boxRect.width, height: labelHeight),
            CGRect(x: boxRect.minX, y: boxRect.minY + boxRect.height * 0.45, width: boxRect.width, height: valueHeight)
        )
    }

    private static func scaledRect(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        reference: CGSize,
        canvas: CGSize
    ) -> CGRect {
        CGRect(
            x: x / reference.width * canvas.width,
            y: y / reference.height * canvas.height,
            width: width / reference.width * canvas.width,
            height: height / reference.height * canvas.height
        )
    }
}

enum TicketTypography {
    static let background = UIColor(hex: "#F7F4EC")
    static let mainInk = UIColor(hex: "#496B4A")
    static let mutedInk = UIColor(hex: "#7E664A")
    static let labelInk = UIColor(hex: "#6F8B63")
    static let lightInk = UIColor(hex: "#C2B291")
}
