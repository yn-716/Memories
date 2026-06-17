import SwiftUI
import UIKit

enum MemoriesTheme {
    static let background = Color(hex: "#F6FAFF")
    static let subBackground = Color(hex: "#EAF4FF")
    static let card = Color(hex: "#FFFFFF")
    static let accent = Color(hex: "#8FB7D9")
    static let accentDeep = Color(hex: "#4F7FA3")
    static let textMain = Color(hex: "#1F3447")
    static let textSub = Color(hex: "#6B7D8C")
    static let border = Color(hex: "#D8E8F5")

    static let cardRadius: CGFloat = 8
    static let controlRadius: CGFloat = 8

    static func color(forRole role: String) -> Color {
        switch role.normalizedRole {
        case "background":
            return background
        case "subbackground":
            return subBackground
        case "card":
            return card
        case "accent":
            return accent
        case "accentdeep":
            return accentDeep
        case "textmain":
            return textMain
        case "textsub":
            return textSub
        case "border":
            return border
        default:
            return textMain
        }
    }

    static func uiColor(forRole role: String) -> UIColor {
        switch role.normalizedRole {
        case "background":
            return UIColor(hex: "#F6FAFF")
        case "subbackground":
            return UIColor(hex: "#EAF4FF")
        case "card":
            return UIColor(hex: "#FFFFFF")
        case "accent":
            return UIColor(hex: "#8FB7D9")
        case "accentdeep":
            return UIColor(hex: "#4F7FA3")
        case "textmain":
            return UIColor(hex: "#1F3447")
        case "textsub":
            return UIColor(hex: "#6B7D8C")
        case "border":
            return UIColor(hex: "#D8E8F5")
        default:
            return UIColor(hex: "#1F3447")
        }
    }
}

extension Color {
    init(hex: String) {
        let components = HexColorParser.components(from: hex)
        self.init(
            .sRGB,
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: components.alpha
        )
    }
}

extension UIColor {
    convenience init(hex: String) {
        let components = HexColorParser.components(from: hex)
        self.init(
            red: components.red,
            green: components.green,
            blue: components.blue,
            alpha: components.alpha
        )
    }
}

private enum HexColorParser {
    static func components(from hex: String) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        switch cleaned.count {
        case 8:
            return (
                red: CGFloat((value & 0xFF00_0000) >> 24) / 255,
                green: CGFloat((value & 0x00FF_0000) >> 16) / 255,
                blue: CGFloat((value & 0x0000_FF00) >> 8) / 255,
                alpha: CGFloat(value & 0x0000_00FF) / 255
            )
        case 6:
            return (
                red: CGFloat((value & 0xFF0000) >> 16) / 255,
                green: CGFloat((value & 0x00FF00) >> 8) / 255,
                blue: CGFloat(value & 0x0000FF) / 255,
                alpha: 1
            )
        default:
            return (red: 0, green: 0, blue: 0, alpha: 1)
        }
    }
}

private extension String {
    var normalizedRole: String {
        lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}
