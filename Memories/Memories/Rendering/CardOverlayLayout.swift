import CoreGraphics
import UIKit

enum CardOverlayTextRole {
    case meta
    case main
    case sub
}

struct CardOverlayLayout {
    static let insetRatio: CGFloat = 0.055
    static let blockWidthRatio: CGFloat = 0.78
    static let iconSizeRatio: CGFloat = 0.057
    static let metaIconSizeRatio: CGFloat = 0.032
    static let iconSpacingRatio: CGFloat = 0.43
    static let iconRowAdvanceRatio: CGFloat = 0.076
    static let metaLineHeightRatio: CGFloat = 0.042
    static let mainTopSpacingRatio: CGFloat = 0.020
    static let mainLineHeightRatio: CGFloat = 0.091
    static let subLineHeightRatio: CGFloat = 0.058

    static func base(for size: CGSize) -> CGFloat {
        min(size.width, size.height)
    }

    static func inset(for size: CGSize) -> CGFloat {
        base(for: size) * insetRatio
    }

    static func blockWidth(for size: CGSize) -> CGFloat {
        min(size.width * blockWidthRatio, size.width - inset(for: size) * 2)
    }

    static func iconSize(for size: CGSize) -> CGFloat {
        base(for: size) * iconSizeRatio
    }

    static func metaIconSize(for size: CGSize) -> CGFloat {
        base(for: size) * metaIconSizeRatio
    }

    static func lineHeight(for role: CardOverlayTextRole, canvasSize: CGSize) -> CGFloat {
        let base = base(for: canvasSize)

        switch role {
        case .meta:
            return base * metaLineHeightRatio
        case .main:
            return base * mainLineHeightRatio
        case .sub:
            return base * subLineHeightRatio
        }
    }

    static func fontSize(for role: CardOverlayTextRole, canvasSize: CGSize) -> CGFloat {
        let base = base(for: canvasSize)

        switch role {
        case .meta:
            return base * 0.031
        case .main:
            return base * 0.081
        case .sub:
            return base * 0.041
        }
    }

    static func fontWeight(for role: CardOverlayTextRole) -> UIFont.Weight {
        switch role {
        case .meta:
            return .medium
        case .main:
            return .semibold
        case .sub:
            return .regular
        }
    }
}
