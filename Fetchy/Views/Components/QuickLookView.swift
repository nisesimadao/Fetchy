import SwiftUI
import QuickLook
import AVKit

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct QuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIViewController {
        let isShareExtension = Bundle.main.bundleIdentifier?.contains("FetchyShare") ?? false

        // Per user request: For the main app, always use QLPreviewController.
        // This avoids the blank screen on iOS 15, though it may not play video directly.
        if !isShareExtension {
            return createQLController(context: context)
        }
        
        // For the Share Extension, use the version-aware logic where the AVPlayer fallback is known to work.
        if #available(iOS 16.0, *) {
            return createQLController(context: context)
        } else {
            return createAVPlayerController(context: context)
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Controller Creation Helpers

    private func createQLController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        let nav = UINavigationController(rootViewController: controller)
        return nav
    }

    private func createAVPlayerController(context: Context) -> UIViewController {
        // This path is now only for the Share Extension on iOS 15
        if let temporaryURL = context.coordinator.createTemporaryFileURL() {
            let playerVC = AVPlayerViewController()
            playerVC.player = AVPlayer(url: temporaryURL)
            
            let shareButton = UIBarButtonItem(barButtonSystemItem: .action, target: context.coordinator, action: #selector(context.coordinator.shareTapped))
            playerVC.navigationItem.rightBarButtonItem = shareButton
            
            let navController = UINavigationController(rootViewController: playerVC)
            context.coordinator.presentingViewController = navController

            // Play is deferred to the completion handler for smoother presentation
            navController.modalPresentationStyle = .fullScreen
            DispatchQueue.main.async {
                playerVC.player?.play()
            }
            
            return navController
        } else {
            // Return a blank controller if file copy fails
            return UIViewController()
        }
    }
    
    // MARK: - Coordinator

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookView
        weak var presentingViewController: UIViewController?
        var temporaryFileURL: URL?

        init(parent: QuickLookView) {
            self.parent = parent
        }
        
        // --- For AVPlayerViewController on iOS <= 15 (Share Extension ONLY) ---
        func createTemporaryFileURL() -> URL? {
            let originalURL = parent.url
            do {
                let videoData = try Data(contentsOf: originalURL)
                let temporaryDirectory = FileManager.default.temporaryDirectory
                let fileName = UUID().uuidString + "." + originalURL.pathExtension
                let temporaryURL = temporaryDirectory.appendingPathComponent(fileName)
                try videoData.write(to: temporaryURL)
                self.temporaryFileURL = temporaryURL
                return temporaryURL
            } catch {
                print("Fetchy: Error creating temporary file for playback. Error: \(error)")
                return nil
            }
        }
        
        @objc func shareTapped() {
            guard let presentingVC = presentingViewController else { return }
            
            let activityViewController = UIActivityViewController(activityItems: [parent.url], applicationActivities: nil)
            
            if let popoverController = activityViewController.popoverPresentationController {
                if let topVC = (presentingVC as? UINavigationController)?.topViewController {
                    popoverController.barButtonItem = topVC.navigationItem.rightBarButtonItem
                }
            }
            
            presentingVC.present(activityViewController, animated: true, completion: nil)
        }
        
        deinit {
            if let tempURL = temporaryFileURL {
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
        
        // --- For QLPreviewController (All other cases) ---
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return PreviewItem(url: parent.url)
        }
    }
}

// QLPreviewItem remains unchanged
class PreviewItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?
    let previewItemTitle: String?
    
    init(url: URL) {
        self.previewItemURL = url
        self.previewItemTitle = url.lastPathComponent
        super.init()
        
        if url.isFileURL {
            _ = url.startAccessingSecurityScopedResource()
        }
    }
    
    deinit {
        if let url = previewItemURL, url.isFileURL {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
