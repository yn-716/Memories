import Foundation
import UIKit

struct PetCalendarImportCandidate: Identifiable, Hashable {
    let id: UUID
    var image: UIImage
    var imageData: Data
    var capturedAt: Date?
    var manualDate: Date?
    var sourceIndex: Int

    init(
        id: UUID = UUID(),
        image: UIImage,
        imageData: Data,
        capturedAt: Date?,
        manualDate: Date? = nil,
        sourceIndex: Int
    ) {
        self.id = id
        self.image = image
        self.imageData = imageData
        self.capturedAt = capturedAt
        self.manualDate = manualDate
        self.sourceIndex = sourceIndex
    }

    static func == (lhs: PetCalendarImportCandidate, rhs: PetCalendarImportCandidate) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var proposedDate: Date? {
        manualDate ?? capturedAt
    }
}

enum PetCalendarImportGroupAction: String, Codable, Hashable {
    case keepExisting
    case replaceExisting
    case addNew
}

struct PetCalendarImportGroup: Identifiable, Hashable {
    var id: String
    var date: Date?
    var candidates: [PetCalendarImportCandidate]
    var existingEntry: PetCalendarDayEntry?
    var selectedCandidateID: UUID?
    var action: PetCalendarImportGroupAction
    var isFutureDate: Bool

    var selectedCandidate: PetCalendarImportCandidate? {
        guard let selectedCandidateID else {
            return nil
        }
        return candidates.first { $0.id == selectedCandidateID }
    }

    var requiresUserDecision: Bool {
        date == nil || isFutureDate || candidates.count > 1 || existingEntry != nil
    }
}

struct PetCalendarImportPlannedEntry: Identifiable, Hashable {
    var id: String
    var date: Date
    var candidate: PetCalendarImportCandidate
    var replacesExisting: Bool
}

struct PetCalendarImportPlanner {
    var calendar: Calendar = PetCalendarDateRules.gregorianCalendar()

    static func makeMetadataReader(
        read: @escaping (Data, Bool) async -> PhotoMetadata = { data, allowsLocationSuggestion in
            await PhotoMetadataReader().metadata(from: data, allowsLocationSuggestion: allowsLocationSuggestion)
        }
    ) -> (Data) async -> PhotoMetadata {
        { data in
            await read(data, false)
        }
    }

    func makeCandidates(
        from imagePayloads: [(data: Data, image: UIImage)],
        metadataReader: ((Data) async -> PhotoMetadata)? = nil
    ) async -> [PetCalendarImportCandidate] {
        let reader = metadataReader ?? Self.makeMetadataReader()
        var candidates: [PetCalendarImportCandidate] = []
        for (index, payload) in imagePayloads.enumerated() {
            let metadata = await reader(payload.data)
            candidates.append(
                PetCalendarImportCandidate(
                    image: payload.image,
                    imageData: payload.data,
                    capturedAt: metadata.capturedAt,
                    sourceIndex: index
                )
            )
        }
        return candidates
    }

    func groups(
        for candidates: [PetCalendarImportCandidate],
        existingEntries: [PetCalendarDayEntry] = [],
        now: Date = Date()
    ) -> [PetCalendarImportGroup] {
        let existingByID = Dictionary(uniqueKeysWithValues: existingEntries.map { ($0.id, $0) })
        var grouped: [String: [PetCalendarImportCandidate]] = [:]
        var undated: [PetCalendarImportCandidate] = []

        for candidate in candidates {
            guard let date = candidate.proposedDate else {
                undated.append(candidate)
                continue
            }
            let dateID = PetCalendarDateRules.id(for: date, calendar: calendar)
            grouped[dateID, default: []].append(candidate)
        }

        var result = grouped.map { dateID, candidates in
            let sortedCandidates = candidates.sorted {
                ($0.capturedAt ?? .distantPast) > ($1.capturedAt ?? .distantPast)
            }
            let date = sortedCandidates.first?.proposedDate.map {
                PetCalendarDateRules.startOfDay(for: $0, calendar: calendar)
            }
            let existing = existingByID[dateID]
            return PetCalendarImportGroup(
                id: dateID,
                date: date,
                candidates: sortedCandidates,
                existingEntry: existing,
                selectedCandidateID: sortedCandidates.first?.id,
                action: existing == nil ? .addNew : .keepExisting,
                isFutureDate: date.map { !PetCalendarDateRules.canRegisterPhoto(for: $0, now: now, calendar: calendar) } ?? false
            )
        }

        result.append(contentsOf: undated.map { candidate in
            PetCalendarImportGroup(
                id: "undated-\(candidate.id.uuidString)",
                date: nil,
                candidates: [candidate],
                existingEntry: nil,
                selectedCandidateID: candidate.id,
                action: .addNew,
                isFutureDate: false
            )
        })

        return result.sorted { lhs, rhs in
            switch (lhs.date, rhs.date) {
            case let (left?, right?):
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.id < rhs.id
            }
        }
    }

    func plannedEntries(from groups: [PetCalendarImportGroup], now: Date = Date()) -> [PetCalendarImportPlannedEntry] {
        groups.compactMap { group in
            guard
                group.action != .keepExisting,
                !group.isFutureDate,
                let date = group.date,
                PetCalendarDateRules.canRegisterPhoto(for: date, now: now, calendar: calendar),
                let candidate = group.selectedCandidate
            else {
                return nil
            }

            let dateID = PetCalendarDateRules.id(for: date, calendar: calendar)
            return PetCalendarImportPlannedEntry(
                id: dateID,
                date: date,
                candidate: candidate,
                replacesExisting: group.existingEntry != nil && group.action == .replaceExisting
            )
        }
    }
}
