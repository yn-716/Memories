import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var completion: (Bool, Error?) -> Void = { _, _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, error in
            DispatchQueue.main.async {
                completion(completed, error)
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareMediaItem: Identifiable {
    let id = UUID()
    let item: Any
    let consumesFreeWatermarkAllowance: Bool
    let cleanupURL: URL?
}
