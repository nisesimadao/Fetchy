import SwiftUI
import UniformTypeIdentifiers

struct ShareView: View {
    var extensionContext: NSExtensionContext?
    
    @State private var state: ShareState = .initial
    @State private var foundURL: URL?
    @State private var videoTitle: String = "Detecting..."
    @State private var progress: Double = 0.0
    @State private var downloadedFileURL: URL?
    @State private var showProgressOverride: Bool = false // User tapped to show
    
    enum ShareState: Equatable {
        case initial
        case downloading
        case readyForPreview
        case error(String)
        case success
    }
    
    @State private var statusMessage: String = "ANALYZING..."
    @State private var lastHapticProgress: Double = 0.0
    @State private var startTime: Date?
    @State private var toastMessage: String?
    @State private var isShowingToast = false
    
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        ZStack {
            // Background - Liquid Glass
            Color.clear
                .liquidGlass()
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header / Initial Info
                if case .readyForPreview = state {
                    // Skip header when ready for preview
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(DesignSystem.Colors.nothingRed)
                        
                        Text(videoTitle)
                            .font(.nothingHeader)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        
                        DotMatrixText(text: stateText)
                    }
                    .padding()
                }
                
                // Progress Section (Hidden by default unless downloading & user requests, or logic enforces)
                if state == .downloading || showProgressOverride {
                    VStack {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.2))
                                
                                Capsule()
                                    .fill(DesignSystem.Colors.nothingRed)
                                    .frame(width: geo.size.width * progress)
                                    .animation(.spring, value: progress)
                            }
                        }
                        .frame(height: 6)
                        
                        HStack {
                            Text("\(Int(progress * 100))%")
                            Spacer()
                            if SettingsManager.shared.vibrationEnabled {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                    .font(.caption)
                            }
                        }
                        .font(.nothingMeta)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .transition(.opacity)
                } 
                else if state == .initial {
                    // "Show Progress" Button
                    Button(action: {
                        withAnimation {
                            showProgressOverride = true
                        }
                    }) {
                        HStack {
                            Text("SHOW PROGRESS")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(IndustrialButtonStyle())
                }
                
                // QuickLook / Open Section
                if case .readyForPreview = state, let fileURL = downloadedFileURL {
                    VStack(spacing: 16) {
                        Text("READY FOR PREVIEW")
                            .font(.nothingHeader)
                        
                        Button(action: {
                            openQuickLook(url: fileURL)
                        }) {
                            Label("Open Quick Look", systemImage: "eye")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(IndustrialButtonStyle())
                    }
                }
                
                // Error State
                if case .error(let msg) = state {
                     ToastView(message: msg, isWarning: true)
                }
            }
            .padding()
        }
        .onAppear {
            extractURL()
        }
    }
    
    // MARK: - Logic
    
    private var stateText: String {
        switch state {
        case .initial: return "ANALYZING INPUT..."
        case .downloading: return "DOWNLOADING..."
        case .readyForPreview: return "READY"
        case .error: return "FAILED"
        case .success: return "COMPLETED"
        }
    }
    
    private func extractURL() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return }
        
        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { (item, error) in
                        if let url = item as? URL {
                            DispatchQueue.main.async {
                                self.foundURL = url
                                self.videoTitle = "URL Detected" // Better title fetching usually requires initial scrape
                                self.startDownload(url: url)
                            }
                        }
                    }
                    return
                }
                // Handle plain text that might be a URL
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                     provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (item, error) in
                        if let text = item as? String, let url = URL(string: text) { // Naive check
                             DispatchQueue.main.async {
                                self.foundURL = url
                                self.videoTitle = "Text Link"
                                self.startDownload(url: url)
                            }
                        }
                     }
                }
            }
        }
    }
    
    private func startDownload(url: URL) {
        state = .downloading
        startTime = Date()
        
        YTDLPManager.shared.download(url: url.absoluteString, statusHandler: { prog, status in
            if prog >= 0 {
                self.progress = prog
                checkHaptics(prog)
            }
            self.statusMessage = status
            checkTimeWarnings()
        }) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (fileURL, log)):
                    self.downloadedFileURL = fileURL
                    self.state = .readyForPreview
                    let entry = VideoEntry(
                        title: fileURL.lastPathComponent,
                        url: url.absoluteString,
                        service: url.host ?? "Unknown",
                        status: .completed,
                        localPath: fileURL.path
                    )
                    DatabaseManager.shared.insert(entry: entry, rawLog: log)
                    
                case .failure(let error):
                    self.showToast(error.localizedDescription)
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }
    
    private func checkHaptics(_ prog: Double) {
        if SettingsManager.shared.vibrationEnabled {
            if prog >= lastHapticProgress + 0.02 {
                hapticGenerator.impactOccurred()
                lastHapticProgress = prog
            }
        }
    }
    
    private func checkTimeWarnings() {
        guard SettingsManager.shared.toastEnabled else { return }
        guard let start = startTime else { return }
        let elapsed = Date().timeIntervalSince(start)
        
        if elapsed > 480 { // 8 minutes
            showToast("ダウンロード中です。OSにより中断される可能性があります。")
        } else if elapsed > 300 { // 5 minutes
            showToast("長時間経過するとOSにより中断される可能性があります。")
        }
    }
    
    private func showToast(_ message: String) {
        guard toastMessage != message else { return }
        toastMessage = message
        withAnimation { isShowingToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation { isShowingToast = false }
        }
    }

    
    private func openQuickLook(url: URL) {
        // In a real generic SwiftUI view, we might need a wrapper or bridge to QLPreviewController
        // relying on parent view controller integration. 
        // For this streamlined impl, we'll assume the parent `ShareViewController` handles the presentation
        // or we use a `quickLookPreview` modifier if available in newer iOS, 
        // OR we simply signal the parent.
        // For simplicity here:
        NotificationCenter.default.post(name: NSNotification.Name("OpenQuickLook"), object: url)
    }
}
