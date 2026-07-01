import CoreGraphics
import Foundation
import UIKit

enum EditableMediaKind: String, Codable, Hashable {
    case image
    case video
}

struct EditableMedia: Identifiable {
    let id: UUID
    let kind: EditableMediaKind
    let image: UIImage?
    let videoURL: URL?
    let thumbnailImage: UIImage
    let naturalSize: CGSize
    let duration: TimeInterval?
    let capturedAt: Date?
    let locationText: String?

    init(
        id: UUID = UUID(),
        kind: EditableMediaKind,
        image: UIImage?,
        videoURL: URL?,
        thumbnailImage: UIImage,
        naturalSize: CGSize,
        duration: TimeInterval? = nil,
        capturedAt: Date? = nil,
        locationText: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.image = image
        self.videoURL = videoURL
        self.thumbnailImage = thumbnailImage
        self.naturalSize = naturalSize
        self.duration = duration
        self.capturedAt = capturedAt
        self.locationText = locationText
    }

    static func image(
        _ image: UIImage,
        capturedAt: Date? = nil,
        locationText: String? = nil
    ) -> EditableMedia {
        EditableMedia(
            kind: .image,
            image: image,
            videoURL: nil,
            thumbnailImage: image,
            naturalSize: image.size,
            capturedAt: capturedAt,
            locationText: locationText
        )
    }

    static func video(
        url: URL,
        thumbnailImage: UIImage,
        naturalSize: CGSize,
        duration: TimeInterval?,
        capturedAt: Date? = nil,
        locationText: String? = nil
    ) -> EditableMedia {
        EditableMedia(
            kind: .video,
            image: nil,
            videoURL: url,
            thumbnailImage: thumbnailImage,
            naturalSize: naturalSize,
            duration: duration,
            capturedAt: capturedAt,
            locationText: locationText
        )
    }

    var previewImage: UIImage {
        image ?? thumbnailImage
    }

    var contentSize: CGSize {
        if naturalSize.width > 0, naturalSize.height > 0 {
            return naturalSize
        }

        return previewImage.size
    }
}
