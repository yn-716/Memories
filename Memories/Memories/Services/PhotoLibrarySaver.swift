import Photos
import UIKit

enum PhotoLibrarySaveError: LocalizedError {
    case permissionDenied
    case saveFailed
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "写真への保存が許可されていません。設定から写真への追加を許可してください。"
        case .saveFailed:
            return "写真に保存できませんでした。"
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

struct PhotoLibrarySaver {
    func save(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

        guard status == .authorized || status == .limited else {
            throw PhotoLibrarySaveError.permissionDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: PhotoLibrarySaveError.underlying(error))
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotoLibrarySaveError.saveFailed)
                }
            }
        }
    }
}
