import AVFoundation
import CoreLocation
import CoreTransferable
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum EditableMediaLoadError: LocalizedError {
    case unsupported
    case imageLoadFailed
    case videoLoadFailed

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "このメディアは読み込めませんでした。"
        case .imageLoadFailed:
            return "写真を読み込めませんでした。"
        case .videoLoadFailed:
            return "動画を読み込めませんでした。"
        }
    }
}

struct PickedVideoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let copiedURL = try MediaFileManager().copyVideoToTemporaryImport(from: received.file)
            return PickedVideoFile(url: copiedURL)
        }
    }
}

struct EditableMediaLoader {
    func load(
        from item: PhotosPickerItem,
        allowsLocationSuggestion: Bool = true
    ) async throws -> EditableMedia {
        try MediaFileManager.shared.prepareTemporaryDirectories()
        _ = try? MediaFileManager.shared.cleanupTemporaryFiles()

        if item.supportedContentTypes.contains(where: { $0.conforms(to: UTType.movie) }) {
            return try await loadVideo(from: item, allowsLocationSuggestion: allowsLocationSuggestion)
        }

        if item.supportedContentTypes.contains(where: { $0.conforms(to: UTType.image) }) {
            return try await loadImage(from: item, allowsLocationSuggestion: allowsLocationSuggestion)
        }

        throw EditableMediaLoadError.unsupported
    }

    private func loadImage(
        from item: PhotosPickerItem,
        allowsLocationSuggestion: Bool
    ) async throws -> EditableMedia {
        guard
            let data = try await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else {
            throw EditableMediaLoadError.imageLoadFailed
        }

        let metadata = await PhotoMetadataReader().metadata(
            from: data,
            allowsLocationSuggestion: allowsLocationSuggestion
        )

        return .image(
            image,
            capturedAt: metadata.capturedAt,
            locationText: metadata.locationText
        )
    }

    private func loadVideo(
        from item: PhotosPickerItem,
        allowsLocationSuggestion: Bool
    ) async throws -> EditableMedia {
        guard let pickedVideo = try await item.loadTransferable(type: PickedVideoFile.self) else {
            throw EditableMediaLoadError.videoLoadFailed
        }

        let asset = AVURLAsset(url: pickedVideo.url)
        let properties = try await VideoAssetInspector().properties(for: asset)
        let thumbnail = try VideoAssetInspector().thumbnail(for: asset, duration: properties.duration)
        let metadata = await VideoMetadataReader().metadata(
            from: asset,
            allowsLocationSuggestion: allowsLocationSuggestion
        )

        return .video(
            url: pickedVideo.url,
            thumbnailImage: thumbnail,
            naturalSize: properties.naturalSize,
            duration: properties.duration,
            capturedAt: metadata.capturedAt,
            locationText: metadata.locationText
        )
    }
}

struct VideoAssetProperties {
    let naturalSize: CGSize
    let duration: TimeInterval
    let preferredTransform: CGAffineTransform
}

struct VideoAssetInspector {
    func properties(for asset: AVAsset) async throws -> VideoAssetProperties {
        let duration = try await asset.load(.duration)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw EditableMediaLoadError.videoLoadFailed
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let orientedSize = Self.orientedSize(naturalSize: naturalSize, preferredTransform: preferredTransform)

        return VideoAssetProperties(
            naturalSize: orientedSize,
            duration: duration.seconds.isFinite ? duration.seconds : 0,
            preferredTransform: preferredTransform
        )
    }

    func thumbnail(for asset: AVAsset, duration: TimeInterval) throws -> UIImage {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1440, height: 1440)
        let seconds = duration > 1 ? min(duration * 0.05, 1) : 0
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
        return UIImage(cgImage: cgImage)
    }

    static func orientedSize(naturalSize: CGSize, preferredTransform: CGAffineTransform) -> CGSize {
        let transformed = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        return CGSize(width: abs(transformed.width), height: abs(transformed.height))
    }
}

struct VideoMetadataReader {
    func metadata(from asset: AVAsset, allowsLocationSuggestion: Bool = true) async -> PhotoMetadata {
        let metadataItems = await metadataItems(from: asset)
        let capturedAt = await capturedAt(from: metadataItems)
        let coordinate = allowsLocationSuggestion ? await coordinate(from: metadataItems) : nil
        let locationText = allowsLocationSuggestion ? await locationText(for: coordinate) : nil
        return PhotoMetadata(capturedAt: capturedAt, locationText: locationText)
    }

    private func metadataItems(from asset: AVAsset) async -> [AVMetadataItem] {
        do {
            let commonMetadata = try await asset.load(.commonMetadata)
            let metadata = try await asset.load(.metadata)
            return commonMetadata + metadata
        } catch {
            return []
        }
    }

    private func capturedAt(from metadataItems: [AVMetadataItem]) async -> Date? {
        var candidates: [String] = []
        for item in metadataItems {
            if item.commonKey == .commonKeyCreationDate {
                if let value = try? await item.load(.stringValue) {
                    candidates.append(value)
                }
            }
            if item.identifier == .quickTimeMetadataCreationDate {
                if let value = try? await item.load(.stringValue) {
                    candidates.append(value)
                }
            }
        }

        return candidates.compactMap(parseDate).first
    }

    private func coordinate(from metadataItems: [AVMetadataItem]) async -> CLLocationCoordinate2D? {
        var candidates: [String] = []
        for item in metadataItems {
            if item.identifier == .quickTimeMetadataLocationISO6709 {
                if let value = try? await item.load(.stringValue) {
                    candidates.append(value)
                }
            }
        }

        return candidates.compactMap(parseISO6709Coordinate).first
    }

    private func parseDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let date = ISO8601DateFormatter().date(from: trimmed) {
            return date
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy:MM:dd HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    private func parseISO6709Coordinate(_ value: String) -> CLLocationCoordinate2D? {
        let pattern = #"^([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
            match.numberOfRanges >= 3,
            let latitudeRange = Range(match.range(at: 1), in: value),
            let longitudeRange = Range(match.range(at: 2), in: value),
            let latitude = CLLocationDegrees(value[latitudeRange]),
            let longitude = CLLocationDegrees(value[longitudeRange])
        else {
            return nil
        }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }

    private func locationText(for coordinate: CLLocationCoordinate2D?) async -> String? {
        guard let coordinate else {
            return nil
        }

        do {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if let placemark = try await CLGeocoder().reverseGeocodeLocation(location).first {
                return formattedLocationText(from: placemark)
            }
        } catch {
            return nil
        }

        return nil
    }

    private func formattedLocationText(from placemark: CLPlacemark) -> String? {
        let candidates = [
            placemark.locality,
            placemark.subLocality,
            placemark.administrativeArea,
            placemark.country
        ]

        var uniqueParts: [String] = []
        for candidate in candidates.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }) where !candidate.isEmpty {
            if !uniqueParts.contains(candidate) {
                uniqueParts.append(candidate)
            }
        }

        let text = uniqueParts.prefix(2).joined(separator: " ")
        return text.isEmpty ? nil : text
    }
}
