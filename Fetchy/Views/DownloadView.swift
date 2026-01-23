import SwiftUI
import QuickLook

struct DownloadView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var urlInput: String = ""
    @State private var isDownloading = false
    @State private var progress: Double = 0.0
    @State private var statusMessage: String = "READY"
    @State private var showProgress = false
    @State private var selectedResolution: String = "1080p"
    @State private var isAudioOnly: Bool = false
    @State private var selectedFormat: String = "mp4"
    @State private var selectedBitrate: String = "192"
    
    // QuickLook support
    @State private var previewURL: URL?
    @State private var showPreview = false
    
    let videoResolutions = ["2160p", "1080p", "720p", "480p"]
    let videoFormats = ["mp4", "webm", "mkv"]
    let audioFormats = ["mp3", "m4a", "wav"]
    let audioBitrates = ["320", "256", "192", "128"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    
                    // Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            DotMatrixText(text: "TARGET URL")
                            Spacer()
                            if !urlInput.isEmpty {
                                Button(action: { urlInput = ""; isDownloading = false; progress = 0 }) {
                                    Text("RESET")
                                        .font(.nothingMeta)
                                        .foregroundColor(DesignSystem.Colors.nothingRed)
                                }
                            }
                        }
                        
                        TextField("Paste Link Here...", text: $urlInput)
                            .padding()
                            .liquidGlass()
                            .submitLabel(.go)
                            .disabled(isDownloading)
                            .onSubmit {
                                startDownload()
                            }
                        
                        // Mode Toggle (Video/Audio)
                        HStack(spacing: 12) {
                            modeButton(title: "VIDEO", isActive: !isAudioOnly) {
                                withAnimation { isAudioOnly = false; selectedFormat = "mp4" }
                            }
                            modeButton(title: "AUDIO", isActive: isAudioOnly) {
                                withAnimation { isAudioOnly = true; selectedFormat = "mp3" }
                            }
                        }
                        .padding(.top, 4)
                        
                        // Dynamic Pickers
                        if isAudioOnly {
                            pickerSection(title: "AUDIO FORMAT", items: audioFormats, selection: $selectedFormat)
                            pickerSection(title: "BITRATE (kbps)", items: audioBitrates, selection: $selectedBitrate)
                        } else {
                            pickerSection(title: "RESOLUTION", items: videoResolutions, selection: $selectedResolution)
                            pickerSection(title: "CONTAINER", items: videoFormats, selection: $selectedFormat)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Progress & Status
                    if isDownloading && (showProgress || settings.progressVisible) {
                        VStack(spacing: 12) {
                            DotMatrixText(text: statusMessage)
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.2))
                                    
                                    Capsule()
                                        .fill(DesignSystem.Colors.nothingRed)
                                        .frame(width: geo.size.width * progress)
                                }
                            }
                            .frame(height: 6)
                            
                            HStack {
                                Text("\(Int(progress * 100))%")
                                Spacer()
                                Text(isAudioOnly ? "EXTRACTING..." : "DOWNLOADING...")
                            }
                            .font(.nothingMeta)
                        }
                        .padding()
                        .liquidGlass()
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    Spacer()
                    
                    // Action Button
                    Button(action: startDownload) {
                        HStack {
                            if isDownloading {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 8)
                            }
                            Text(isDownloading ? "SEQUENCE ACTIVE" : "INITIATE DOWNLOAD")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(IndustrialButtonStyle())
                    .disabled(urlInput.isEmpty || isDownloading)
                    .padding()
                }
                .padding(.top, 10)
            }
            .navigationTitle("Download")
            .sheet(isPresented: $showPreview) {
                if let url = previewURL {
                    QuickLookView(url: url)
                }
            }
        }
    }
    
    // UI Helpers
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
        .disabled(isDownloading)
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
                            .foregroundColor(selection.wrappedValue == item ? Color(uiColor: .systemBackground) : .primary)
                            .cornerRadius(8)
                    }
                    .disabled(isDownloading)
                }
            }
        }
        .padding(.top, 8)
    }
    
    private func startDownload() {
        guard !urlInput.isEmpty else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        withAnimation {
            isDownloading = true
            statusMessage = "INITIALIZING..."
            progress = 0.0
        }
        
        YTDLPManager.shared.download(
            url: urlInput,
            quality: selectedResolution,
            audioOnly: isAudioOnly,
            format: selectedFormat,
            bitrate: selectedBitrate,
            statusHandler: { prog, status in
                DispatchQueue.main.async {
                    if prog >= 0 {
                        self.progress = prog
                    }
                    self.statusMessage = status.uppercased()
                }
            }
        ) { result in
            DispatchQueue.main.async {
                withAnimation { self.isDownloading = false }
                
                switch result {
                case .success(let (fileURL, log)):
                    self.statusMessage = "COMPLETED"
                    self.progress = 1.0
                    
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    
                    let entry = VideoEntry(
                        title: fileURL.lastPathComponent,
                        url: self.urlInput,
                        service: "Direct",
                        status: .completed,
                        localPath: fileURL.path
                    )
                    DatabaseManager.shared.insert(entry: entry, rawLog: log)
                    
                    self.previewURL = fileURL
                    // Small delay to ensure UI state is stable before presenting sheet
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.showPreview = true
                    }
                    
                case .failure(let error):
                    self.statusMessage = "ERROR: \(error.localizedDescription)"
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}

// QuickLook SwiftUI Wrapper
struct QuickLookView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        let nav = UINavigationController(rootViewController: controller)
        return nav
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookView
        
        init(parent: QuickLookView) {
            self.parent = parent
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem
        }
    }
}

