import SwiftUI
import UniformTypeIdentifiers

struct ShareView: View {
    var extensionContext: NSExtensionContext?
    
    @State private var state: ShareState = .initial
    @State private var foundURL: URL?
    @State private var videoTitle: String = "Detecting..."
    @State private var progress: Double = 0.0
    @State private var downloadedFileURL: URL?
    @State private var selectedResolution: String = "1080p"
    @State private var isAudioOnly: Bool = false
    @State private var selectedFormat: String = "mp4"
    @State private var selectedBitrate: String = "192"
    
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
    
    let videoResolutions = ["2160p", "1080p", "720p", "480p"]
    let videoFormats = ["mp4", "webm", "mkv"]
    let audioFormats = ["mp3", "m4a", "wav"]
    let audioBitrates = ["320", "256", "192", "128"]
    
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        ZStack {
            Color.clear
                .liquidGlass()
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                if state == .initial {
                    VStack(spacing: 16) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(DesignSystem.Colors.nothingRed)
                        
                        Text(videoTitle)
                            .font(.nothingHeader)
                            .lineLimit(1)
                        
                        // Mode Toggle
                        HStack(spacing: 12) {
                            selectionButton(title: "VIDEO", isActive: !isAudioOnly) {
                                withAnimation { isAudioOnly = false; selectedFormat = "mp4" }
                            }
                            selectionButton(title: "AUDIO", isActive: isAudioOnly) {
                                withAnimation { isAudioOnly = true; selectedFormat = "mp3" }
                            }
                        }
                        
                        // Pickers
                        VStack(spacing: 10) {
                            if isAudioOnly {
                                miniPicker(title: "FORMAT", items: audioFormats, selection: $selectedFormat)
                                miniPicker(title: "BITRATE", items: audioBitrates, selection: $selectedBitrate)
                            } else {
                                miniPicker(title: "QUALITY", items: videoResolutions, selection: $selectedResolution)
                                miniPicker(title: "CONTAINER", items: videoFormats, selection: $selectedFormat)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Button(action: {
                            if let url = foundURL {
                                startDownload(url: url)
                            }
                        }) {
                            Text("START DOWNLOAD")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(IndustrialButtonStyle())
                        .disabled(foundURL == nil)
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: state == .downloading ? "arrow.down.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(state == .downloading ? DesignSystem.Colors.nothingRed : .green)
                            .symbolEffect(.pulse, isActive: state == .downloading)
                        
                        Text(videoTitle)
                            .font(.nothingHeader)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        
                        DotMatrixText(text: stateText)
                        
                        if state == .downloading {
                            VStack(spacing: 8) {
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
                                
                                Text("\(Int(progress * 100))%")
                                    .font(.nothingMeta)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 10)
                        }
                    }
                    .padding()
                }
                
                if case .readyForPreview = state, let fileURL = downloadedFileURL {
                    Button(action: { openQuickLook(url: fileURL) }) {
                        Label("RE-OPEN PREVIEW", systemImage: "eye")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(IndustrialButtonStyle())
                    .padding(.horizontal)
                }
            }
            .padding()
            
            // Toast layer
            if isShowingToast, let msg = toastMessage {
                VStack {
                    Spacer()
                    ToastView(message: msg, isWarning: false)
                        .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            extractURL()
        }
    }
    
    // UI Helpers
    private func selectionButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.nothingMeta)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isActive ? DesignSystem.Colors.nothingRed : Color.secondary.opacity(0.1))
                .foregroundColor(isActive ? .white : .primary)
                .cornerRadius(10)
        }
    }
    
    private func miniPicker(title: String, items: [String], selection: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(.nothingMeta)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        Button(action: { selection.wrappedValue = item }) {
                            Text(item.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selection.wrappedValue == item ? Color.primary : Color.secondary.opacity(0.1))
                                .foregroundColor(selection.wrappedValue == item ? Color(uiColor: .systemBackground) : .primary)
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
    }
    
    private var stateText: String {
        switch state {
        case .initial: return "READY"
        case .downloading: return "DOWNLOADING..."
        case .readyForPreview: return "COMPLETED"
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
                                self.videoTitle = url.host ?? "External Link"
                            }
                        }
                    }
                    return
                }
            }
        }
    }
    
    private func startDownload(url: URL) {
        state = .downloading
        startTime = Date()
        
        YTDLPManager.shared.download(
            url: url.absoluteString, 
            quality: selectedResolution,
            audioOnly: isAudioOnly,
            format: selectedFormat,
            bitrate: selectedBitrate,
            statusHandler: { prog, status in
            DispatchQueue.main.async {
                if prog >= 0 {
                    self.progress = prog
                    checkHaptics(prog)
                }
                self.statusMessage = status
                checkTimeWarnings()
            }
        }) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (fileURL, log)):
                    self.downloadedFileURL = fileURL
                    self.state = .readyForPreview
                    self.progress = 1.0
                    
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    
                    let entry = VideoEntry(
                        title: fileURL.lastPathComponent,
                        url: url.absoluteString,
                        service: url.host ?? "Unknown",
                        status: .completed,
                        localPath: fileURL.path
                    )
                    DatabaseManager.shared.insert(entry: entry, rawLog: log)
                    
                    // Auto-open QuickLook
                    openQuickLook(url: fileURL)
                    
                case .failure(let error):
                    self.showToast(error.localizedDescription)
                    self.state = .error(error.localizedDescription)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
    
    private func checkHaptics(_ prog: Double) {
        if SettingsManager.shared.vibrationEnabled {
            if prog >= lastHapticProgress + 0.05 {
                hapticGenerator.impactOccurred()
                lastHapticProgress = prog
            }
        }
    }
    
    private func checkTimeWarnings() {
        guard SettingsManager.shared.toastEnabled else { return }
        guard let start = startTime else { return }
        let elapsed = Date().timeIntervalSince(start)
        
        if elapsed > 480 {
            showToast("OSにより中断される可能性があります。")
        }
    }
    
    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation { isShowingToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { isShowingToast = false }
        }
    }
    
    private func openQuickLook(url: URL) {
        NotificationCenter.default.post(name: NSNotification.Name("OpenQuickLook"), object: url)
    }
}

