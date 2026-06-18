import CoreGraphics
import UIKit

enum CardOverlayTextRole {
    case meta
    case main
    case sub
}

struct CardOverlayLayout {
    static let insetRatio: CGFloat = 0.055
    static let blockWidthRatio: CGFloat = 0.84
    static let themeIconSizeRatio: CGFloat = 0.116
    static let weatherIconSizeRatio: CGFloat = 0.102
    static let metaIconSizeRatio: CGFloat = 0.059
    static let iconSpacingRatio: CGFloat = 0.08
    static let iconTextSpacingRatio: CGFloat = 0.20
    static let iconRowAdvanceRatio: CGFloat = 0.128
    static let metaLineHeightRatio: CGFloat = 0.064
    static let mainTopSpacingRatio: CGFloat = 0.010
    static let mainLineHeightRatio: CGFloat = 0.073
    static let subLineHeightRatio: CGFloat = 0.046
    static let previewStackSpacingRatio: CGFloat = 0.006

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
        themeIconSize(for: size)
    }

    static func themeIconSize(for size: CGSize) -> CGFloat {
        base(for: size) * themeIconSizeRatio
    }

    static func weatherIconSize(for size: CGSize) -> CGFloat {
        base(for: size) * weatherIconSizeRatio
    }

    static func metaIconSize(for size: CGSize) -> CGFloat {
        base(for: size) * metaIconSizeRatio
    }

    static func iconRowSpacing(for size: CGSize) -> CGFloat {
        themeIconSize(for: size) * iconSpacingRatio
    }

    static func previewStackSpacing(for size: CGSize) -> CGFloat {
        base(for: size) * previewStackSpacingRatio
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
            return base * 0.030
        case .main:
            return base * 0.065
        case .sub:
            return base * 0.033
        }
    }

    static func fontWeight(for role: CardOverlayTextRole) -> UIFont.Weight {
        switch role {
        case .meta:
            return .semibold
        case .main:
            return .bold
        case .sub:
            return .medium
        }
    }
}
