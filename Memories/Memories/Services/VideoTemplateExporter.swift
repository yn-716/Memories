import AVFoundation
import CoreImage
import Foundation
import UIKit

enum VideoTemplateExporterError: LocalizedError {
    case missingVideo
    case missingVideoTrack
    case overlayRenderFailed
    case exportSessionUnavailable
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .missingVideo:
            return "動画ファイルを読み込めませんでした。"
        case .missingVideoTrack:
            return "動画トラックを読み込めませんでした。"
        case .overlayRenderFailed:
            return "動画に重ねるデザインを作成できませんでした。"
        case .exportSessionUnavailable:
            return "動画を書き出せませんでした。"
        case .exportFailed:
            return "動画の書き出しに失敗しました。"
        }
    }
}

struct VideoTemplateExporter {
    func export(
        media: EditableMedia,
        template: Template,
        editState: CardEditState,
        watermarkMode: WatermarkMode
    ) async throws -> URL {
        guard media.kind == .video, let videoURL = media.videoURL else {
            throw VideoTemplateExporterError.missingVideo
        }

        let asset = AVURLAsset(url: videoURL)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw VideoTemplateExporterError.missingVideoTrack
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let orientedSize = VideoAssetInspector.orientedSize(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform
        )
        let outputSize = outputSize(for: template, mediaSize: orientedSize)
        let renderer = TemplateRenderer()
        let renderConfiguration = TemplateRenderConfiguration(
            template: template,
            editState: editState,
            outputSize: outputSize,
            photoImage: nil,
            watermarkMode: watermarkMode
        )
        guard
            let overlayImage = renderer.renderVideoOverlay(configuration: renderConfiguration),
            let overlayCGImage = overlayImage.cgImage
        else {
            throw VideoTemplateExporterError.overlayRenderFailed
        }

        let mediaFrame = renderer.mediaFrame(for: template, outputSize: outputSize)
        let ciMediaFrame = ciRect(fromUIKitRect: mediaFrame, outputSize: outputSize)
        let outputRect = CGRect(origin: .zero, size: outputSize)
        let overlayCIImage = CIImage(cgImage: overlayCGImage)
        let placement = editState.photoPlacement.clamped
        let renderStyle = template.renderStyle
        let filterType = editState.retroFilterType

        let videoComposition = AVMutableVideoComposition(asset: asset) { request in
            let sourceImage = normalizedCIImage(request.sourceImage)
            let sourceSize = sourceImage.extent.size
            let mediaSize = sourceSize.width > 0 && sourceSize.height > 0 ? sourceSize : orientedSize
            let filteredImage = renderStyle.isRetroFilm
                ? retroFiltered(sourceImage, filterType: filterType)
                : sourceImage
            let placedVideo = placedCIImage(
                filteredImage,
                mediaSize: mediaSize,
                frameRect: ciMediaFrame,
                placement: placement
            )
            let canvas = placedVideo.composited(over: CIImage(color: .clear).cropped(to: outputRect))
            let finalImage = overlayCIImage
                .composited(over: canvas)
                .cropped(to: outputRect)
            request.finish(with: finalImage, context: nil)
        }
        videoComposition.renderSize = outputSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let outputURL = try MediaFileManager.shared.makeTemporaryExportURL(fileExtension: "mp4")
        MediaFileManager.shared.removeTemporaryFileIfPossible(at: outputURL)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoTemplateExporterError.exportSessionUnavailable
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.metadata = outputMetadata(createdAt: Date())
        exportSession.shouldOptimizeForNetworkUse = true

        try await export(session: exportSession)
        MediaFileManager.shared.excludeFromBackupIfPossible(outputURL)
        return outputURL
    }

    private func export(session: AVAssetExportSession) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let box = ExportSessionBox(session)
            session.exportAsynchronously {
                switch box.session.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(throwing: box.session.error ?? VideoTemplateExporterError.exportFailed)
                default:
                    continuation.resume(throwing: VideoTemplateExporterError.exportFailed)
                }
            }
        }
    }

    private func outputSize(for template: Template, mediaSize: CGSize) -> CGSize {
        let proposed: CGSize
        if let templateOutputSize = template.renderStyle.outputSize {
            proposed = templateOutputSize
        } else if mediaSize.width > 0, mediaSize.height > 0 {
            proposed = mediaSize
        } else {
            proposed = CardAspectRatio.fourByFive.outputSize
        }

        let maxLongSide: CGFloat = 1440
        let longSide = max(proposed.width, proposed.height)
        let scale = longSide > maxLongSide ? maxLongSide / longSide : 1
        return evenSize(CGSize(width: proposed.width * scale, height: proposed.height * scale))
    }

    private func evenSize(_ size: CGSize) -> CGSize {
        CGSize(width: evenDimension(size.width), height: evenDimension(size.height))
    }

    private func evenDimension(_ value: CGFloat) -> CGFloat {
        let rounded = max(2, Int(value.rounded()))
        return CGFloat(rounded - rounded % 2)
    }

    private func outputMetadata(createdAt: Date) -> [AVMetadataItem] {
        let value = ISO8601DateFormatter.videoCreationMetadata.string(from: createdAt) as NSString
        return [
            metadataItem(identifier: .commonIdentifierCreationDate, value: value),
            metadataItem(identifier: .quickTimeMetadataCreationDate, value: value)
        ]
    }

    private func metadataItem(identifier: AVMetadataIdentifier, value: NSString) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value
        return item
    }
}

private extension ISO8601DateFormatter {
    static let videoCreationMetadata: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}

private func ciRect(fromUIKitRect rect: CGRect, outputSize: CGSize) -> CGRect {
    CGRect(
        x: rect.minX,
        y: outputSize.height - rect.maxY,
        width: rect.width,
        height: rect.height
    )
}

private func normalizedCIImage(_ image: CIImage) -> CIImage {
    let extent = image.extent
    guard extent.minX != 0 || extent.minY != 0 else {
        return image
    }
    return image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
}

private func placedCIImage(
    _ image: CIImage,
    mediaSize: CGSize,
    frameRect: CGRect,
    placement: PhotoPlacement
) -> CIImage {
    guard mediaSize.width > 0, mediaSize.height > 0, frameRect.width > 0, frameRect.height > 0 else {
        return image.cropped(to: frameRect)
    }

    let baseScale = max(frameRect.width / mediaSize.width, frameRect.height / mediaSize.height)
    let drawScale = baseScale * CGFloat(placement.scale)
    let drawSize = CGSize(width: mediaSize.width * drawScale, height: mediaSize.height * drawScale)
    let overflowX = max(0, (drawSize.width - frameRect.width) / 2)
    let overflowY = max(0, (drawSize.height - frameRect.height) / 2)
    let center = CGPoint(
        x: frameRect.midX + CGFloat(placement.offsetX) * overflowX,
        y: frameRect.midY - CGFloat(placement.offsetY) * overflowY
    )
    let origin = CGPoint(x: center.x - drawSize.width / 2, y: center.y - drawSize.height / 2)

    return image
        .transformed(by: CGAffineTransform(scaleX: drawScale, y: drawScale))
        .transformed(by: CGAffineTransform(translationX: origin.x, y: origin.y))
        .cropped(to: frameRect)
}

private func retroFiltered(_ image: CIImage, filterType: RetroFilterType) -> CIImage {
    RetroFilmEffect.apply(to: image, filterType: filterType)
}
