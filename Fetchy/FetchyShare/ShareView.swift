import SwiftUI
import UniformTypeIdentifiers
import Combine

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
    @State private var showProgressOverride = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var activeTask: DownloadTask?
    
    @ObservedObject var downloadManager = DownloadManager.shared
    
    let videoResolutions = ["2160p", "1080p", "720p", "480p"]
    let videoFormats = ["mp4", "webm", "mkv"]
    let audioFormats = ["mp3", "m4a", "wav"]
    let audioBitrates = ["320", "256", "192", "128"]
    
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                if state == .initial {
                    initialStateView
                } else {
                    activeDownloadView
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
            
            if isShowingToast, let msg = toastMessage {
                VStack {
                    Spacer()
                    ToastView(message: msg, isWarning: true)
                        .padding(.bottom, 60)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            extractURL()
        }
    }
    
    private var initialStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.nothingRed)
            
            VStack(spacing: 4) {
                Text(videoTitle)
                    .font(.nothingHeader)
                    .lineLimit(1)
                
                DotMatrixText(text: foundURL?.host ?? "READY TO INITIATE")
            }
            
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    selectionButton(title: "VIDEO", isActive: !isAudioOnly) {
                        withAnimation { isAudioOnly = false; selectedFormat = "mp4" }
                    }
                    selectionButton(title: "AUDIO", isActive: isAudioOnly) {
                        withAnimation { isAudioOnly = true; selectedFormat = "mp3" }
                    }
                }
                
                VStack(spacing: 12) {
                    if isAudioOnly {
                        miniPicker(title: "FORMAT", items: audioFormats, selection: $selectedFormat)
                        miniPicker(title: "BITRATE", items: audioBitrates, selection: $selectedBitrate)
                    } else {
                        miniPicker(title: "QUALITY", items: videoResolutions, selection: $selectedResolution)
                        miniPicker(title: "CONTAINER", items: videoFormats, selection: $selectedFormat)
                    }
                }
            }
            .padding()
            .liquidGlass(cornerRadius: 20)
            
            Button(action: {
                if let url = foundURL {
                    startDownload(url: url)
                }
            }) {
                Text("INITIATE DOWNLOAD")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IndustrialButtonStyle())
            .disabled(foundURL == nil)
        }
    }
    
    private var activeDownloadView: some View {
        VStack(spacing: 20) {
            Image(systemName: state == .downloading ? "arrow.down.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(state == .downloading ? DesignSystem.Colors.nothingRed : .green)
                .symbolEffect(.bounce, value: progress)
            
            VStack(spacing: 6) {
                Text(videoTitle)
                    .font(.nothingHeader)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                DotMatrixText(text: stateText)
            }
            
            if state == .downloading {
                VStack(spacing: 16) {
                    if SettingsManager.shared.progressVisible || showProgressOverride {
                        VStack(spacing: 8) {
                            ProgressView(value: progress)
                                .tint(DesignSystem.Colors.nothingRed)
                                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                            
                            Text("\(Int(progress * 100))%")
                                .font(.nothingMeta)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button(action: { withAnimation { showProgressOverride = true } }) {
                            Text("TAP TO REVEAL PROGRESS")
                                .font(.nothingMeta)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding()
        .liquidGlass(cornerRadius: 24)
    }
    
    private func selectionButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.nothingMeta)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(isActive ? DesignSystem.Colors.nothingRed : Color.secondary.opacity(0.1))
                .foregroundColor(isActive ? .white : .primary)
                .cornerRadius(12)
        }
    }
    
    private func miniPicker(title: String, items: [String], selection: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(.nothingMeta)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        Button(action: { selection.wrappedValue = item }) {
                            Text(item.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selection.wrappedValue == item ? Color.primary : Color.secondary.opacity(0.1))
                                .foregroundColor(selection.wrappedValue == item ? Color(uiColor: .systemBackground) : .primary)
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
    }
    
    private var stateText: String {
        switch state {
        case .initial: return "READY"
        case .downloading: return "SEQUENCE ACTIVE"
        case .readyForPreview: return "SIGNAL STABLE"
        case .error(let msg): return msg
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
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (item, error) in
                        if let text = item as? String, let url = URL(string: text) {
                            DispatchQueue.main.async {
                                self.foundURL = url
                                self.videoTitle = url.host ?? "Shared Text"
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func startDownload(url: URL) {
        withAnimation {
            state = .downloading
            startTime = Date()
        }
        
        downloadManager.addDownload(
            url: url.absoluteString,
            quality: selectedResolution,
            audioOnly: isAudioOnly,
            format: selectedFormat,
            bitrate: selectedBitrate
        )
        
        if let task = downloadManager.tasks.last {
            self.activeTask = task
            task.$progress
                .receive(on: DispatchQueue.main)
                .sink { prog in
                    self.progress = prog
                    self.checkHaptics(prog)
                }
                .store(in: &cancellables)
            
            task.$status
                .receive(on: DispatchQueue.main)
                .sink { status in
                    if status == "COMPLETED" {
                        if let fileURL = task.fileURL {
                            self.downloadedFileURL = fileURL
                            self.state = .readyForPreview
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            self.openQuickLook(url: fileURL)
                        }
                    } else if status.contains("ERROR") {
                        self.state = .error(status)
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    private func checkHaptics(_ prog: Double) {
        let settings = SettingsManager.shared
        guard settings.vibrationEnabled else { return }
        let frequency = Double(settings.hapticFrequency) / 100.0
        if prog >= lastHapticProgress + frequency {
            hapticGenerator.impactOccurred()
            lastHapticProgress = prog
        }
    }
    
    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation { isShowingToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation { isShowingToast = false }
        }
    }
    
    private func openQuickLook(url: URL) {
        NotificationCenter.default.post(name: NSNotification.Name("OpenQuickLook"), object: url)
    }
}

