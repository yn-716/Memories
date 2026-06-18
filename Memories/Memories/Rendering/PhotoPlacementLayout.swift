import CoreGraphics
import UIKit

struct PhotoPlacementLayout {
    static func drawRect(
        imageSize: CGSize,
        frameRect: CGRect,
        placement: PhotoPlacement
    ) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, frameRect.width > 0, frameRect.height > 0 else {
            return frameRect
        }

        let clampedPlacement = placement.clamped
        let baseScale = max(frameRect.width / imageSize.width, frameRect.height / imageSize.height)
        let drawScale = baseScale * CGFloat(clampedPlacement.scale)
        let drawSize = CGSize(width: imageSize.width * drawScale, height: imageSize.height * drawScale)
        let overflowX = max(0, (drawSize.width - frameRect.width) / 2)
        let overflowY = max(0, (drawSize.height - frameRect.height) / 2)
        let center = CGPoint(
            x: frameRect.midX + CGFloat(clampedPlacement.offsetX) * overflowX,
            y: frameRect.midY + CGFloat(clampedPlacement.offsetY) * overflowY
        )

        return CGRect(
            x: center.x - drawSize.width / 2,
            y: center.y - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
    }

    static func placement(
        from placement: PhotoPlacement,
        applyingDrag translation: CGSize,
        imageSize: CGSize,
        frameRect: CGRect
    ) -> PhotoPlacement {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return placement.clamped
        }

        let drawRect = drawRect(imageSize: imageSize, frameRect: frameRect, placement: placement)
        let overflowX = max(0, (drawRect.width - frameRect.width) / 2)
        let overflowY = max(0, (drawRect.height - frameRect.height) / 2)
        let deltaX = overflowX > 0 ? Double(translation.width / overflowX) : 0
        let deltaY = overflowY > 0 ? Double(translation.height / overflowY) : 0

        return PhotoPlacement(
            scale: placement.scale,
            offsetX: placement.offsetX + deltaX,
            offsetY: placement.offsetY + deltaY
        ).clamped
    }

    static func drawImage(_ image: UIImage?, in frameRect: CGRect, placement: PhotoPlacement) {
        guard let image else {
            return
        }

        UIBezierPath(rect: frameRect).addClip()
        image.draw(in: drawRect(imageSize: image.size, frameRect: frameRect, placement: placement))
    }
}

