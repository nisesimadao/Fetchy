import SwiftUI

struct DownloadView: View {
    @State private var urlInput: String = ""
    @State private var selectedResolution: String = "1080p"
    @State private var isAudioOnly: Bool = false
    @State private var selectedFormat: String = "mp4"
    @State private var selectedBitrate: String = "192"
    @State private var embedMetadata: Bool = true
    @State private var embedThumbnail: Bool = true
    @State private var removeSponsors: Bool = false
    @State private var embedSubtitles: Bool = false
    @State private var embedChapters: Bool = false
    @State private var isExpandedOptions: Bool = false
    
    // QuickLook State
    @State private var quickLookURL: URL?
    @State private var showQuickLook: Bool = false
    
    let videoResolutions = ["MAX", "2160p", "1080p", "720p", "480p"]
    let videoFormats = ["mp4", "webm", "mkv", "mov"]
    let audioFormats = ["mp3", "m4a", "wav", "ogg"]
    let audioBitrates = ["320", "256", "192", "128"]
    
    @ObservedObject var downloadManager = DownloadManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                
                VStack(spacing: 16) {
                    // Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            DotMatrixText(text: "TARGET URL")
                            Spacer()
                            if !urlInput.isEmpty {
                                Button(action: { urlInput = "" }) {
                                    Text("RESET")
                                        .font(.nothingMeta)
                                        .foregroundColor(DesignSystem.Colors.nothingRed)
                                }
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Button(action: pasteFromClipboard) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                                    .frame(width: 44, height: 44)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            
                            TextField("Paste Link Here...", text: $urlInput)
                                .padding()
                                .liquidGlass()
                                .if(availableiOS: 15.0) {
                                    if #available(iOS 15.0, *) {
                                        $0.submitLabel(.go)
                                          .onSubmit { startDownload() }
                                    } else {
                                        $0
                                    }
                                }
                        }
                        
                        // Mode Toggle (Video/Audio)
                        HStack(spacing: 12) {
                            modeButton(title: "VIDEO", isActive: !isAudioOnly) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isAudioOnly = false
                                    selectedFormat = SettingsManager.shared.defaultVideoFormat
                                }
                            }
                            modeButton(title: "AUDIO", isActive: isAudioOnly) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isAudioOnly = true
                                    selectedFormat = SettingsManager.shared.defaultAudioFormat
                                }
                            }
                        }
                        .padding(.top, 4)
                        
                        // Dynamic Pickers with Animation
                        ZStack {
                            if isAudioOnly {
                                VStack(alignment: .leading, spacing: 12) {
                                    pickerSection(title: "BITRATE (kbps)", items: audioBitrates, selection: $selectedBitrate)
                                    pickerSection(title: "FORMAT", items: audioFormats, selection: $selectedFormat)
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    pickerSection(title: "RESOLUTION", items: videoResolutions, selection: $selectedResolution)
                                    pickerSection(title: "FORMAT", items: videoFormats, selection: $selectedFormat)
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                            }
                        }
                        .if(availableiOS: 15.0) {
                            $0.animation(.spring(response: 0.35, dampingFraction: 0.8), value: isAudioOnly)
                        } otherwise: {
                            $0.animation(.spring(response: 0.35, dampingFraction: 0.8))
                        }
                        
                        // Advanced Options
                        DisclosureGroup(
                            isExpanded: $isExpandedOptions,
                            content: {
                                VStack(spacing: 12) {
                                    // Metadata Option
                                    let metaSupported = !["wav"].contains(selectedFormat)
                                    toggleRow(
                                        title: "Embed Metadata",
                                        isOn: $embedMetadata,
                                        isEnabled: metaSupported,
                                        note: metaSupported ? nil : "(mp3, m4a, mp4, mkv only)"
                                    )
                                    
                                    // Thumbnail Option
                                    let thumbSupported = ["mp3", "m4a", "mp4", "mkv"].contains(selectedFormat)
                                    toggleRow(
                                        title: "Embed Thumbnail",
                                        isOn: $embedThumbnail,
                                        isEnabled: thumbSupported,
                                        note: thumbSupported ? nil : "(mp3, m4a, mp4, mkv only)"
                                    )
                                    
                                    // SponsorBlock Option
                                    let sbSupported = ["mp4", "webm", "mkv", "mp3", "m4a"].contains(selectedFormat)
                                    toggleRow(
                                        title: "Remove Sponsors",
                                        isOn: $removeSponsors,
                                        isEnabled: sbSupported,
                                        note: sbSupported ? nil : "(mp4, mkv, mp3, m4a only)"
                                    )
                                    
                                    // Subtitles Option
                                    let subSupported = ["mp4", "webm", "mkv", "mov"].contains(selectedFormat)
                                    toggleRow(
                                        title: "Embed Subtitles",
                                        isOn: $embedSubtitles,
                                        isEnabled: subSupported,
                                        note: subSupported ? nil : "(Video formats only)"
                                    )
                                    
                                    // Chapters Option
                                    let chapSupported = ["mp4", "webm", "mkv", "mp3", "m4a"].contains(selectedFormat)
                                    toggleRow(
                                        title: "Embed Chapters",
                                        isOn: $embedChapters,
                                        isEnabled: chapSupported,
                                        note: chapSupported ? nil : "(Most formats)"
                                    )
                                }
                                .padding(.top, 8)
                                .padding(.leading, 4)
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
                        .if(availableiOS: 15.0) {
                            if #available(iOS 15.0, *) {
                                $0.tint(.primary)
                            } else {
                                $0
                            }
                        } otherwise: {
                            $0.accentColor(.primary)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Active Download Monitoring (Latest Task)
                    if let task = downloadManager.tasks.last, task.status != "CANCELLED", !task.status.contains("ERROR") {
                        DownloadProgressSection(task: task)
                            .onReceive(task.$status) { status in
                                if status == "COMPLETED", let url = task.fileURL {
                                    self.quickLookURL = url
                                    self.showQuickLook = true
                                }
                            }
                            .if(availableiOS: 15.0) {
                                if #available(iOS 15.0, *) {
                                    $0.animation(.spring(), value: task.status)
                                } else {
                                    $0
                                }
                            } otherwise: {
                                $0.animation(.spring())
                            }
                    }
                    
                    // Action Button
                    Button(action: startDownload) {
                        Text(isDownloading ? "SEQUENCE ACTIVE..." : "INITIATE DOWNLOAD")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(IndustrialButtonStyle())
                    .disabled(urlInput.isEmpty || isDownloading)
                    .opacity(isDownloading ? 0.6 : 1.0)
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
                .padding(.top, 10)
                .if(availableiOS: 15.0) {
                    if #available(iOS 15.0, *) {
                        $0.animation(.easeInOut(duration: 0.8), value: isDownloading)
                    } else {
                        $0
                    }
                } otherwise: {
                    $0.animation(.easeInOut(duration: 0.8))
                }
            }
            .navigationTitle("Download")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Load defaults from settings
                if selectedResolution == "1080p" { // Only override if untouched (simple check)
                    selectedResolution = SettingsManager.shared.defaultResolution
                }
                if selectedBitrate == "192" {
                    selectedBitrate = SettingsManager.shared.defaultBitrate
                }
                
                // Advanced options defaults
                embedMetadata = SettingsManager.shared.embedMetadata
                embedThumbnail = SettingsManager.shared.embedThumbnail
                removeSponsors = SettingsManager.shared.removeSponsors
                embedSubtitles = SettingsManager.shared.embedSubtitles
                embedChapters = SettingsManager.shared.embedChapters
                
                // Load format based on initial mode
                if isAudioOnly {
                   if selectedFormat == "mp3" { selectedFormat = SettingsManager.shared.defaultAudioFormat }
                } else {
                   if selectedFormat == "mp4" { selectedFormat = SettingsManager.shared.defaultVideoFormat }
                }
            }
            .sheet(isPresented: $showQuickLook, onDismiss: cleanupSession) {
                if let url = quickLookURL {
                    QuickLookView(url: url)
                }
            }
        }
    }
    
    // UI Helpers
    private var isDownloading: Bool {
        guard let task = downloadManager.tasks.last else { return false }
        return task.status != "COMPLETED" && task.status != "CANCELLED" && !task.status.contains("ERROR")
    }
    
    private func pasteFromClipboard() {
        if let string = UIPasteboard.general.string {
            urlInput = string
        }
    }
    
    private func modeButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
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
    
    private func pickerSection(title: String, items: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DotMatrixText(text: title)
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Button(action: { selection.wrappedValue = item }) {
                        Text(item.uppercased())
                            .font(.nothingMeta)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(selection.wrappedValue == item ? Color.primary : Color.secondary.opacity(0.1))
                            .foregroundColor(selection.wrappedValue == item ? Color(UIColor.systemBackground) : .primary)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    private func startDownload() {
        guard !urlInput.isEmpty else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        DownloadManager.shared.addDownload(
            url: urlInput,
            quality: selectedResolution,
            audioOnly: isAudioOnly,
            format: selectedFormat,
            bitrate: selectedBitrate,
            embedMetadata: embedMetadata,
            embedThumbnail: embedThumbnail,
            removeSponsors: removeSponsors
        )
    }
    
    private func cleanupSession() {
        // Strict cleanup: Delete the parent session directory
        if let url = quickLookURL {
            let sessionDir = url.deletingLastPathComponent()
            do {
                try FileManager.default.removeItem(at: sessionDir)
                print("[DownloadView] Cleanup: Removed session directory at \(sessionDir.path)")
            } catch {
                print("[DownloadView] Cleanup Error: \(error)")
            }
            self.quickLookURL = nil
        }
    }
}

struct DownloadProgressSection: View {
    @ObservedObject var task: DownloadTask
    @State private var lastHapticProgress: Double = 0.0
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        VStack(spacing: 8) {
            DotMatrixText(text: task.status)
            
            if SettingsManager.shared.progressVisible {
                // Main Server Progress
                ProgressView(value: task.progress)
                    .if(availableiOS: 15.0) {
                        if #available(iOS 15.0, *) {
                            $0.tint(DesignSystem.Colors.nothingRed)
                        } else {
                            $0
                        }
                    } otherwise: {
                        $0.accentColor(DesignSystem.Colors.nothingRed)
                    }
                    .scaleEffect(x: 1, y: 1.2, anchor: .center)
                
                // File Transfer Progress (Secondary Bar)
                if let fileProgress = task.fileDownloadProgress {
                    VStack(spacing: 4) {
                        ProgressView(value: fileProgress)
                            .if(availableiOS: 15.0) {
                                if #available(iOS 15.0, *) {
                                    $0.tint(DesignSystem.Colors.nothingRed)
                                } else {
                                    $0
                                }
                            } otherwise: {
                                $0.accentColor(DesignSystem.Colors.nothingRed)
                            }
                            .scaleEffect(x: 1, y: 1.2, anchor: .center)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        
                        Text("\(Int(fileProgress * 100))%")
                            .font(.nothingMeta)
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
                    .padding(.top, 4)
                } else {
                    // Only show percentage for server task if file transfer hasn't started
                    Text("\(Int(task.progress * 100))%")
                        .font(.nothingMeta)
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
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
        .if(availableiOS: 15.0) {
            if #available(iOS 15.0, *) {
                $0.animation(.spring(response: 0.4, dampingFraction: 0.7), value: task.fileDownloadProgress)
            } else {
                $0
            }
        } otherwise: {
            $0.animation(.spring(response: 0.4, dampingFraction: 0.7))
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onReceive(task.$progress) { prog in
            checkHaptics(prog)
        }
    }
    
    private func checkHaptics(_ prog: Double) {
        let settings = SettingsManager.shared
        guard settings.vibrationEnabled else { return }
        
        // Strict rule: 2% steps
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
}

#Preview {
    DownloadView()
}
