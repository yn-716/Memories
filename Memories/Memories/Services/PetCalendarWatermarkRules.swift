import Foundation

struct CalendarWatermarkExportState: Hashable {
    var selectedOption: WatermarkExportOption
    var accessSnapshot: WatermarkAccessSnapshot
}

enum CalendarWatermarkExportRules {
    static func initialOption(for snapshot: WatermarkAccessSnapshot) -> WatermarkExportOption {
        snapshot.hasUnlimitedAccess ? .withoutWatermark : .withWatermark
    }

    static func canSelect(_ option: WatermarkExportOption, snapshot: WatermarkAccessSnapshot) -> Bool {
        switch option {
        case .withWatermark:
            return true
        case .withoutWatermark:
            return snapshot.canExportWithoutWatermark
        }
    }

    static func shouldConsumeAllowance(
        afterSuccessfulOutput option: WatermarkExportOption,
        snapshot: WatermarkAccessSnapshot
    ) -> Bool {
        option == .withoutWatermark && !snapshot.hasUnlimitedAccess
    }
}

enum MemoriesDeepLinkRoute: Hashable {
    case petCalendar
    case petCalendarToday
}

enum MemoriesDeepLinkRouter {
    static func route(for url: URL) -> MemoriesDeepLinkRoute? {
        guard url.scheme?.lowercased() == "memories" else {
            return nil
        }

        let host = url.host?.lowercased()
        let path = url.path.lowercased()

        // Explicit allow-list only. Deep links are navigation-only and must not
        // trigger registration, deletion, purchase, export, or file operations.
        if host == "calendar" && (path.isEmpty || path == "/") {
            return .petCalendar
        }

        if host == "calendar" && path == "/today" {
            return .petCalendarToday
        }

        return nil
    }
}
