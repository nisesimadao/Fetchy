import SwiftUI

struct DownloadView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var urlInput: String = ""
    @State private var isDownloading = false
    @State private var progress: Double = 0.0
    @State private var statusMessage: String = "READY"
    @State private var showProgress = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    
                    // Input Section
                    VStack(alignment: .leading, spacing: 8) {
                        DotMatrixText(text: "TARGET URL")
                        
                        TextField("Paste Link Here...", text: $urlInput)
                            .padding()
                            .liquidGlass()
                            .submitLabel(.go)
                            .onSubmit {
                                startDownload()
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
                                        .animation(.spring, value: progress)
                                }
                            }
                            .frame(height: 6)
                            
                            Text("\(Int(progress * 100))%")
                                .font(.nothingMeta)
                        }
                        .padding()
                        .liquidGlass()
                        .padding(.horizontal)
                    } else if isDownloading {
                        // Show toggle button if progress is hidden
                        Button(action: { showProgress = true }) {
                            HStack {
                                Text("SHOW PROGRESS")
                                Image(systemName: "percent")
                            }
                            .font(.nothingMeta)
                        }
                        .buttonStyle(IndustrialButtonStyle())
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Action Button
                    Button(action: startDownload) {
                        Text("INITIATE SEQUENCE")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(IndustrialButtonStyle())
                    .disabled(urlInput.isEmpty || isDownloading)
                    .padding()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Download")
        }
    }
    
    private func startDownload() {
        guard !urlInput.isEmpty else { return }
        isDownloading = true
        statusMessage = "INITIALIZING..."
        progress = 0.0
        
        // Use YTDLPManager (API version)
        YTDLPManager.shared.download(url: urlInput, statusHandler: { prog, status in
            if prog >= 0 {
                self.progress = prog
            }
            self.statusMessage = status.uppercased()
        }) { result in
            DispatchQueue.main.async {
                self.isDownloading = false
                switch result {
                case .success(let (fileURL, log)):
                    self.statusMessage = "COMPLETED"
                    
                    // Save to database
                    let entry = VideoEntry(
                        title: fileURL.lastPathComponent,
                        url: self.urlInput,
                        service: "Direct",
                        status: .completed,
                        localPath: fileURL.path
                    )
                    DatabaseManager.shared.insert(entry: entry, rawLog: log)
                    
                    self.urlInput = ""
                case .failure(let error):
                    self.statusMessage = "ERROR: \(error.localizedDescription)"
                }
            }
        }
    }

}
