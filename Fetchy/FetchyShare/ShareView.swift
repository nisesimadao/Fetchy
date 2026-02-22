import SwiftUI
import UniformTypeIdentifiers
import Combine

// MARK: - ViewModel
@MainActor
class ShareViewModel: ObservableObject {
    private var extensionContext: NSExtensionContext?
    private var downloadManager = DownloadManager.shared
    private var activeTask: DownloadTask?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: Published State
    @Published var state: ShareState = .initial
    @Published var foundURL: URL?
    @Published var videoTitle: String = "Detecting..."
    @Published var progress: Double = 0.0
    @Published var downloadedFileURL: URL?
    @Published var selectedResolution: String = "1080p"
    @Published var isAudioOnly: Bool = false
    @Published var selectedFormat: String = "mp4"
    @Published var selectedBitrate: String = "192"
    @Published var embedMetadata: Bool = true
    @Published var embedThumbnail: Bool = true
    @Published var removeSponsors: Bool = false
    @Published var embedSubtitles: Bool = false
    @Published var embedChapters: Bool = false
    @Published var isExpandedOptions: Bool = false
    @Published var statusMessage: String = "ANALYZING..."
    @Published var fileDownloadProgress: Double?
    @Published var toastMessage: String?
    @Published var isShowingToast = false
    @Published var showProgressOverride = false
    
    // MARK: Private State
    private var lastHapticProgress: Double = 0.0
    private var startTime: Date?
    
    // MARK: Constants
    let videoResolutions = ["MAX", "2160p", "1080p", "720p", "480p"]
    let videoFormats = ["mp4", "webm", "mkv", "mov"]
    let audioFormats = ["mp3", "m4a", "wav"]
    let audioBitrates = ["320", "256", "192", "128"]
    
    enum ShareState: Equatable {
        case initial
        case downloading
        case readyForPreview
        case error(String)
        case success
    }
    
    init(extensionContext: NSExtensionContext?) {
        self.extensionContext = extensionContext
        
        // Load defaults from settings
        let settings = SettingsManager.shared
        self.selectedResolution = settings.defaultResolution
        self.selectedBitrate = settings.defaultBitrate
        self.embedMetadata = settings.embedMetadata
        self.embedThumbnail = settings.embedThumbnail
        self.removeSponsors = settings.removeSponsors
        self.embedSubtitles = settings.embedSubtitles
        self.embedChapters = settings.embedChapters
        
        // Initial format based on mode (default is video)
        self.selectedFormat = settings.defaultVideoFormat
    }
    
    var stateText: String {
        switch state {
        case .initial: return "READY"
        case .downloading: return "SEQUENCE ACTIVE"
        case .readyForPreview: return "SIGNAL STABLE"
        case .error(let msg): return msg.uppercased()
        case .success: return "COMPLETED"
        }
    }
    
    // MARK: - Logic
    
    func extractURL() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            self.state = .error("INVALID INPUT")
            return
        }
        
        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                        guard let self = self, let url = item as? URL else { return }
                        
                        let isFileURL = url.isFileURL
                        if isFileURL { _ = url.startAccessingSecurityScopedResource() }
                        
                        DispatchQueue.main.async {
                            self.foundURL = url
                            self.videoTitle = url.host ?? "External Link"
                            if isFileURL { url.stopAccessingSecurityScopedResource() }
                        }
                    }
                    return
                }
                else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                        guard let self = self, let text = item as? String else { return }
                        
                        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
                        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
                        
                        if let firstMatch = matches?.first, let url = firstMatch.url {
                            DispatchQueue.main.async {
                                self.foundURL = url
                                self.videoTitle = url.host ?? "Shared Text"
                            }
                        }
                    }
                    return
                }
            }
        }
    }
    
    func startDownload() {
        guard let url = foundURL else { return }
        
        withAnimation {
            state = .downloading
            startTime = Date()
        }
        
        downloadManager.addDownload(
            url: url.absoluteString,
            quality: selectedResolution,
            audioOnly: isAudioOnly,
            format: selectedFormat,
            bitrate: selectedBitrate,
            embedMetadata: embedMetadata,
            embedThumbnail: embedThumbnail,
            removeSponsors: removeSponsors,
            embedSubtitles: embedSubtitles,
            embedChapters: embedChapters
        )
        
        if let task = downloadManager.tasks.last {
            self.activeTask = task
            observe(task: task)
        }
    }
    
    private func observe(task: DownloadTask) {
        task.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] prog in
                self?.progress = prog
                self?.checkHaptics(prog)
            }
            .store(in: &cancellables)
            
        task.$fileDownloadProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] prog in
                self?.fileDownloadProgress = prog
            }
            .store(in: &cancellables)
        
        task.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                self.statusMessage = status
                if status == "COMPLETED" {
                    if let fileURL = task.fileURL {
                        self.downloadedFileURL = fileURL
                        withAnimation { self.state = .readyForPreview }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        self.openQuickLook(url: fileURL)
                    }
                } else if status.contains("ERROR") {
                    withAnimation { self.state = .error(status) }
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkHaptics(_ prog: Double) {
        let settings = SettingsManager.shared
        guard settings.vibrationEnabled else { return }
        
        let step = 0.02
        if prog >= lastHapticProgress + step {
            let style: UIImpactFeedbackGenerator.FeedbackStyle
            switch settings.vibrationStrength {
            case "heavy": style = .heavy
            case "medium": style = .medium
            default: style = .light
            }
            
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
            lastHapticProgress = prog
        }
    }
    
    func showToast(_ message: String, isWarning: Bool = true) {
        guard isWarning else { return }
        
        toastMessage = message
        withAnimation { isShowingToast = true }
        
        let duration = Double(SettingsManager.shared.toastDelaySeconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation { self.isShowingToast = false }
        }
    }
    
    func openQuickLook(url: URL) {
        NotificationCenter.default.post(name: NSNotification.Name("OpenQuickLook"), object: url)
    }
}

// MARK: - View
struct ShareView: View {
    @ObservedObject var viewModel: ShareViewModel
    
    init(viewModel: ShareViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                if viewModel.state == .initial {
                    initialStateView
                } else {
                    activeDownloadView
                }
                
                if case .readyForPreview = viewModel.state, let fileURL = viewModel.downloadedFileURL {
                    Button(action: { viewModel.openQuickLook(url: fileURL) }) {
                        Label("RE-OPEN PREVIEW", systemImage: "eye")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(IndustrialButtonStyle())
                    .padding(.horizontal)
                }
            }
            .padding()
            
            if viewModel.isShowingToast, let msg = viewModel.toastMessage {
                VStack {
                    Spacer()
                    ToastView(message: msg, isWarning: true)
                        .padding(.bottom, 60)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            viewModel.extractURL()
        }
    }
    
    private var initialStateView: some View {
        VStack(spacing: 24) {
            if #available(iOS 15.0, *) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DesignSystem.Colors.nothingRed)
            } else {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(DesignSystem.Colors.nothingRed)
            }
            
            VStack(spacing: 4) {
                Text(viewModel.videoTitle)
                    .font(.nothingHeader)
                    .lineLimit(1)
                
                DotMatrixText(text: viewModel.foundURL?.host ?? "READY TO INITIATE")
            }
            
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    selectionButton(title: "VIDEO", isActive: !viewModel.isAudioOnly) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.isAudioOnly = false
                            viewModel.selectedFormat = SettingsManager.shared.defaultVideoFormat
                        }
                    }
                    selectionButton(title: "AUDIO", isActive: viewModel.isAudioOnly) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.isAudioOnly = true
                            viewModel.selectedFormat = SettingsManager.shared.defaultAudioFormat
                        }
                    }
                }
                
                // Dynamic Pickers with Animation
                ZStack {
                    if viewModel.isAudioOnly {
                        VStack(spacing: 12) {
                            miniPicker(title: "BITRATE", items: viewModel.audioBitrates, selection: $viewModel.selectedBitrate)
                            miniPicker(title: "FORMAT", items: viewModel.audioFormats, selection: $viewModel.selectedFormat)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    } else {
                        VStack(spacing: 12) {
                            miniPicker(title: "QUALITY", items: viewModel.videoResolutions, selection: $viewModel.selectedResolution)
                            miniPicker(title: "FORMAT", items: viewModel.videoFormats, selection: $viewModel.selectedFormat)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }
                .if(availableiOS: 13.0) {
                    $0.animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isAudioOnly)
                } otherwise: {
                    $0.animation(.spring(response: 0.35, dampingFraction: 0.8))
                }
                
                // Advanced Options
                DisclosureGroup(
                    isExpanded: $viewModel.isExpandedOptions,
                    content: {
                        VStack(spacing: 12) {
                            // Metadata Option
                            let metaSupported = !["wav"].contains(viewModel.selectedFormat)
                            toggleRow(
                                title: "Embed Metadata",
                                isOn: $viewModel.embedMetadata,
                                isEnabled: metaSupported,
                                note: metaSupported ? nil : "(mp3, m4a, mp4, mkv only)"
                            )
                            
                            // Thumbnail Option
                            let thumbSupported = ["mp3", "m4a", "mp4", "mkv"].contains(viewModel.selectedFormat)
                            toggleRow(
                                title: "Embed Thumbnail",
                                isOn: $viewModel.embedThumbnail,
                                isEnabled: thumbSupported,
                                note: thumbSupported ? nil : "(mp3, m4a, mp4, mkv only)"
                            )
                            
                            // SponsorBlock Option
                            let sbSupported = ["mp4", "webm", "mkv", "mp3", "m4a"].contains(viewModel.selectedFormat)
                            toggleRow(
                                title: "Remove Sponsors",
                                isOn: $viewModel.removeSponsors,
                                isEnabled: sbSupported,
                                note: sbSupported ? nil : "(mp4, mkv, mp3, m4a only)"
                            )
                            
                            // Subtitles Option
                            let subSupported = ["mp4", "webm", "mkv", "mov"].contains(viewModel.selectedFormat)
                            toggleRow(
                                title: "Embed Subtitles",
                                isOn: $viewModel.embedSubtitles,
                                isEnabled: subSupported,
                                note: subSupported ? nil : "(Video formats only)"
                            )
                            
                            // Chapters Option
                            let chapSupported = ["mp4", "webm", "mkv", "mp3", "m4a"].contains(viewModel.selectedFormat)
                            toggleRow(
                                title: "Embed Chapters",
                                isOn: $viewModel.embedChapters,
                                isEnabled: chapSupported,
                                note: chapSupported ? nil : "(Most formats)"
                            )
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, 4)
                    },
                    label: {
                        DotMatrixText(text: "ADVANCED OPTIONS")
                            .if(availableiOS: 15.0) {
                                if #available(iOS 15.0, *) {
                                    $0.foregroundStyle(.secondary)
                                } else {
                                    $0
                                }
                            } otherwise: {
                                $0.foregroundColor(.secondary)
                            }
                    }
                )
                .if(availableiOS: 15.0, then: { 
                    if #available(iOS 15.0, *) {
                        $0.tint(.primary)
                    } else {
                        $0
                    }
                }, otherwise: { $0.accentColor(.primary) })
                .padding(.top, 8)
            }
            .padding()
            
            
            Button(action: {
                viewModel.startDownload()
            }) {
                Text("INITIATE DOWNLOAD")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IndustrialButtonStyle())
            .disabled(viewModel.foundURL == nil)
        }
    }
    
    private var activeDownloadView: some View {
        VStack(spacing: 20) {
            Image(systemName: viewModel.state == .downloading ? "arrow.down.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 48))
                .if(availableiOS: 15.0) {
                    if #available(iOS 15.0, *) {
                        $0.foregroundStyle(viewModel.state == .downloading ? DesignSystem.Colors.nothingRed : .green)
                    } else {
                        $0
                    }
                } otherwise: {
                    $0.foregroundColor(viewModel.state == .downloading ? DesignSystem.Colors.nothingRed : .green)
                }
                .if(availableiOS: 17.0) {
                    if #available(iOS 17.0, *) {
                        $0.symbolEffect(.bounce, value: viewModel.progress)
                    } else {
                        $0
                    }
                }
            
            VStack(spacing: 6) {
                Text(viewModel.videoTitle)
                    .font(.nothingHeader)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                DotMatrixText(text: viewModel.stateText)
            }
            
            if viewModel.state == .downloading {
                VStack(spacing: 16) {
                    if SettingsManager.shared.progressVisible || viewModel.showProgressOverride {
                        VStack(spacing: 8) {
                            // Main Server Progress
                            ProgressView(value: viewModel.progress)
                                .if(availableiOS: 15.0, then: { 
                                    if #available(iOS 15.0, *) {
                                        $0.tint(DesignSystem.Colors.nothingRed)
                                    } else {
                                        $0
                                    }
                                }, otherwise: { $0.accentColor(DesignSystem.Colors.nothingRed) })
                                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                            
                            // File Transfer Progress (Secondary Bar)
                            if let fileProgress = viewModel.fileDownloadProgress {
                                VStack(spacing: 4) {
                                    ProgressView(value: fileProgress)
                                        .if(availableiOS: 15.0, then: { 
                                            if #available(iOS 15.0, *) {
                                                $0.tint(DesignSystem.Colors.nothingRed)
                                            } else {
                                                $0
                                            }
                                        }, otherwise: { $0.accentColor(DesignSystem.Colors.nothingRed) })
                                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                    
                                    HStack {
                                        Text("\(Int(fileProgress * 100))%")
                                            .font(.nothingMeta)
                                            .if(availableiOS: 15.0, then: { 
                                                if #available(iOS 15.0, *) {
                                                    $0.foregroundStyle(.secondary)
                                                } else {
                                                    $0
                                                }
                                            }, otherwise: { $0.foregroundColor(.secondary) })
                                        Spacer()
                                        // Status is shown below in the main HStack
                                    }
                                }
                                .padding(.top, 4)
                            }
                            
                            HStack {
                                // Only show percentage for server task if file transfer hasn't started or distinct
                                if viewModel.fileDownloadProgress == nil {
                                    Text("\(Int(viewModel.progress * 100))%")
                                        .font(.nothingMeta)
                                        .if(availableiOS: 15.0, then: { 
                                            if #available(iOS 15.0, *) {
                                                $0.foregroundStyle(.secondary)
                                            } else {
                                                $0
                                            }
                                        }, otherwise: { $0.foregroundColor(.secondary) })
                                }
                                Spacer()
                                Text(viewModel.statusMessage)
                                    .font(.nothingMeta)
                                    .if(availableiOS: 15.0, then: { 
                                        if #available(iOS 15.0, *) {
                                            $0.foregroundStyle(.secondary)
                                        } else {
                                            $0
                                        }
                                    }, otherwise: { $0.foregroundColor(.secondary) })
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.fileDownloadProgress)
                    } else {
                        Button(action: { withAnimation { viewModel.showProgressOverride = true } }) {
                            Text("TAP TO REVEAL PROGRESS")
                                .font(.nothingMeta)
                                .if(availableiOS: 15.0, then: { 
                                    if #available(iOS 15.0, *) {
                                        $0.foregroundStyle(.secondary)
                                    } else {
                                        $0
                                    }
                                }, otherwise: { $0.foregroundColor(.secondary) })
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                }
                .transition(.opacity)
                .if(availableiOS: 15.0) {
                    $0.animation(.spring(), value: viewModel.state)
                } otherwise: {
                    $0.animation(.spring())
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
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
    
    private func toggleRow(title: String, isOn: Binding<Bool>, isEnabled: Bool, note: String?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                if let note = note {
                    Text(note)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1.0 : 0.5)
        }
    }
    
    private func miniPicker(title: String, items: [String], selection: Binding<String>) -> some View {
        HStack {
            if #available(iOS 15.0, *) {
                Text(title)
                    .font(.nothingMeta)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
            } else {
                Text(title)
                    .font(.nothingMeta)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        Button(action: { selection.wrappedValue = item }) {
                            Text(item.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selection.wrappedValue == item ? Color.primary : Color.secondary.opacity(0.1))
                                .foregroundColor(selection.wrappedValue == item ? Color(UIColor.systemBackground) : .primary)
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Helper Extensions for iOS 14
// Note: 'if' extensions are now defined in DesignComponents.swift and shared.
