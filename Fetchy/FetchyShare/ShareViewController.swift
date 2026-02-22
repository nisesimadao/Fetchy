import UIKit
import SwiftUI
import Social
import QuickLook
import AVKit

// Custom AVPlayerViewController to detect dismissal for cleanup
class SharePlayerViewController: AVPlayerViewController {
    var onDismiss: (() -> Void)?
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || isMovingFromParent {
            onDismiss?()
        }
    }
}

class ShareViewController: UIViewController, QLPreviewControllerDataSource, QLPreviewControllerDelegate {

    private var originalDownloadedURL: URL?
    private var temporaryPlaybackURL: URL? // For the AVPlayer fallback
    private var viewModel: ShareViewModel!

    override func loadView() {
        super.loadView()
        self.view = UIView(frame: UIScreen.main.bounds)
        self.view.backgroundColor = .clear
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.viewModel = ShareViewModel(extensionContext: self.extensionContext)
        
        let shareView = ShareView(viewModel: self.viewModel)
        let hostingController = UIHostingController(rootView: shareView)
        
        view.backgroundColor = .clear
        
        addChild(hostingController)
        hostingController.view.backgroundColor = .clear
        view.addSubview(hostingController.view)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        hostingController.didMove(toParent: self)
        
        view.layoutIfNeeded()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleQuickLookRequest(_:)), name: NSNotification.Name("OpenQuickLook"), object: nil)
    }
    
    @objc func handleQuickLookRequest(_ notification: Notification) {
        guard let url = notification.object as? URL else { return }
        self.originalDownloadedURL = url
        
        if #available(iOS 16.0, *) {
            // Use QLPreviewController on iOS 16+
            let qlVC = QLPreviewController()
            qlVC.dataSource = self
            qlVC.delegate = self
            self.present(qlVC, animated: true, completion: nil)
        } else {
            // Use AVPlayerViewController on iOS 15 and below
            prepareAndShowAVPlayer(for: url)
        }
    }
    
    private func prepareAndShowAVPlayer(for originalURL: URL) {
        // 1. Create a temporary copy for stable playback
        guard let tempURL = createTemporaryCopy(of: originalURL) else {
            cleanUpSession() // Cleanup if copy fails
            return
        }
        self.temporaryPlaybackURL = tempURL
        
        // 2. Set up the player with the temporary URL
        let playerVC = SharePlayerViewController()
        playerVC.player = AVPlayer(url: tempURL)
        playerVC.onDismiss = { [weak self] in
            self?.cleanUpSession()
        }
        
        // 3. Add a share button
        let shareButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareTapped))
        playerVC.navigationItem.rightBarButtonItem = shareButton
        
        // 4. Wrap in a Navigation Controller and present
        let navController = UINavigationController(rootViewController: playerVC)
        navController.modalPresentationStyle = .fullScreen
        self.present(navController, animated: true) {
            playerVC.player?.play()
        }
    }
    
    private func createTemporaryCopy(of originalURL: URL) -> URL? {
        // App Group file access is not needed if the file is already in the share extension's sandbox
        do {
            let videoData = try Data(contentsOf: originalURL)
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = UUID().uuidString + "." + originalURL.pathExtension
            let tempURL = tempDir.appendingPathComponent(fileName)
            try videoData.write(to: tempURL)
            return tempURL
        } catch {
            print("[Share] Error creating temp copy: \(error)")
            return nil
        }
    }
    
    @objc private func shareTapped() {
        guard let urlToShare = self.originalDownloadedURL else { return }
        let activityVC = UIActivityViewController(activityItems: [urlToShare], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = self.view
            popover.barButtonItem = (self.presentedViewController as? UINavigationController)?.topViewController?.navigationItem.rightBarButtonItem
        }
        self.presentedViewController?.present(activityVC, animated: true)
    }
    
    // MARK: - QLPreviewControllerDataSource (for iOS 16+)
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return originalDownloadedURL != nil ? 1 : 0
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return originalDownloadedURL! as QLPreviewItem
    }
    
    // MARK: - QLPreviewControllerDelegate (Cleanup)
    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        cleanUpSession()
    }
    
    private func cleanUpSession() {
        // Delete the temporary playback file if it exists
        if let tempURL = temporaryPlaybackURL {
            try? FileManager.default.removeItem(at: tempURL)
            self.temporaryPlaybackURL = nil
        }
        
        // Delete the original downloaded file and its session directory
        if let url = originalDownloadedURL {
            let sessionDir = url.deletingLastPathComponent()
            do {
                try FileManager.default.removeItem(at: sessionDir)
                print("[Share] Cleanup: Removed session directory at \(sessionDir.path)")
            } catch {
                print("[Share] Cleanup Error: \(error)")
            }
            self.originalDownloadedURL = nil
        }
        
        // Close the extension
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

