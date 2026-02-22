import Foundation
import Combine

class DownloadTask: ObservableObject, Identifiable {
    let id = UUID()
    @Published var url: String
    @Published var progress: Double = 0.0
    @Published var status: String = "QUEUED"
    @Published var fileURL: URL?
    @Published var fileDownloadProgress: Double?
    
    // Store detected service from API
    private var detectedService: String?
    private var detectedTitle: String?
    
    // YTDLP options
    let quality: String
    let audioOnly: Bool
    let format: String
    let bitrate: String
    let embedMetadata: Bool
    let embedThumbnail: Bool
    let removeSponsors: Bool
    let embedSubtitles: Bool
    let embedChapters: Bool

    private var ytdlpManager = YTDLPManager()
    private var cancellables = Set<AnyCancellable>()
    private let progressSubject = PassthroughSubject<Double, Never>()

    init(url: String, quality: String, audioOnly: Bool, format: String, bitrate: String, embedMetadata: Bool = true, embedThumbnail: Bool = true, removeSponsors: Bool = false, embedSubtitles: Bool = false, embedChapters: Bool = false) {
        self.url = url
        self.quality = quality
        self.audioOnly = audioOnly
        self.format = format
        self.bitrate = bitrate
        self.embedMetadata = embedMetadata
        self.embedThumbnail = embedThumbnail
        self.removeSponsors = removeSponsors
        self.embedSubtitles = embedSubtitles
        self.embedChapters = embedChapters
        
        progressSubject
            .throttle(for: .seconds(0.1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] val in
                guard let self = self else { return }
                if self.status == "DOWNLOADING FILE..." {
                    self.fileDownloadProgress = val
                    self.progress = 1.0 // Main progress stays at 100%
                } else {
                    self.progress = val
                }
            }
            .store(in: &cancellables)
    }

    func start() {
        self.status = "INITIALIZING..."
        
        // Setup session directory
        // Path: AppGroup/temp/session_<UUID>/output.mp4
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
            self.status = "ERROR: APP GROUP UNREACHABLE"
            return
        }
        
        let sessionDir = containerURL.appendingPathComponent("temp").appendingPathComponent("session_\(id.uuidString)")
        try? FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        let outputPath = sessionDir.appendingPathComponent("output.mp4").path
        
        // Pass this explicit path to YTDLP
        ytdlpManager.download(
            url: self.url,
            quality: self.quality,
            audioOnly: self.audioOnly,
            format: self.format,
            bitrate: self.bitrate,
            embedMetadata: self.embedMetadata,
            embedThumbnail: self.embedThumbnail,
            removeSponsors: self.removeSponsors,
            embedSubtitles: self.embedSubtitles,
            embedChapters: self.embedChapters,
            outputTemplate: outputPath, // New parameter support needed in YTDLPManager
            statusHandler: { [weak self] progress, status, service, title in
                self?.progressSubject.send(progress)
                if let service = service {
                    self?.detectedService = service // Capture service name from API
                }
                if let title = title {
                    self?.detectedTitle = title // Capture title from API
                }
                DispatchQueue.main.async {
                    self?.status = status.uppercased()
                }
            },
            completion: { [weak self] result, logs in
                DispatchQueue.main.async {
                    // Helper to determine final service name
                    let finalService = self?.detectedService ?? self?.detectService(from: self?.url ?? "") ?? "Direct"
                    // Determine final title
                    let finalTitle = self?.detectedTitle ?? self?.url ?? "Completed"
                    
                    switch result {
                    case .success(let fileURL):
                        self?.fileURL = fileURL // Set URL first so observers of COMPLETED status can access it
                        self?.status = "COMPLETED"
                        self?.progress = 1.0
                        let entry = VideoEntry(
                            title: finalTitle,
                            url: self?.url ?? "",
                            service: finalService,
                            status: .completed,
                            rawLog: logs
                        )
                        DatabaseManager.shared.insert(entry: entry) // No rawLog arg needed anymore as it's in entry

                    case .failure(let error):
                        self?.status = "ERROR: \(error.localizedDescription)"
                        let entry = VideoEntry(
                            title: "Failed",
                            url: self?.url ?? "",
                            service: finalService,
                            status: .failed,
                            rawLog: logs ?? error.localizedDescription
                        )
                        DatabaseManager.shared.insert(entry: entry)
                    }
                }
            }
        )
    }

    func cancel() {
        self.status = "CANCELLED"
        // Cleanup happens in ShareViewController dismissal
    }
    
    private func detectService(from urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host?.lowercased() else {
            return "Direct"
        }
        
        if host.contains("youtube") || host.contains("youtu.be") { return "YouTube" }
        if host.contains("tiktok") { return "TikTok" }
        if host.contains("twitter") || host.contains("x.com") { return "X" }
        if host.contains("instagram") { return "Instagram" }
        if host.contains("vimeo") { return "Vimeo" }
        if host.contains("facebook") { return "Facebook" }
        if host.contains("twitch") { return "Twitch" }
        
        return "Direct"
    }
}

class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    private let fileManager = FileManager.default
    private let databaseManager = DatabaseManager.shared
    @Published var tasks: [DownloadTask] = []
    
    init() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.cleanupOldSessions()
        }
    }
    
    /// Startup GC: Delete all session directories in temp
    private func cleanupOldSessions() {
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else { return }
        let tempDir = containerURL.appendingPathComponent("temp")
        
        do {
            if FileManager.default.fileExists(atPath: tempDir.path) {
                // Simply wipe the entire temp directory content
                let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                for url in contents {
                    try FileManager.default.removeItem(at: url)
                }
                print("[GC] Cleaned up \(contents.count) stale session(s) in temp.")
            }
        } catch {
            print("[GC] Error cleaning temp: \(error)")
        }
    }

    func addDownload(url: String, quality: String, audioOnly: Bool, format: String, bitrate: String, embedMetadata: Bool = true, embedThumbnail: Bool = true, removeSponsors: Bool = false, embedSubtitles: Bool = false, embedChapters: Bool = false) {
        let task = DownloadTask(url: url, quality: quality, audioOnly: audioOnly, format: format, bitrate: bitrate, embedMetadata: embedMetadata, embedThumbnail: embedThumbnail, removeSponsors: removeSponsors, embedSubtitles: embedSubtitles, embedChapters: embedChapters)
        tasks.append(task)
        task.start()
    }

    func cancelAll() {
        tasks.forEach { $0.cancel() }
    }
}
