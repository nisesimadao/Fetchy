import Foundation
import Combine

enum YTDLPError: LocalizedError {
    case apiError(String)
    case networkError(Error)
    case timeout
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .apiError(let msg): return msg
        case .networkError(let error): return error.localizedDescription
        case .timeout: return "Request timed out"
        case .unknown: return "An unknown error occurred"
        }
    }
}

class YTDLPManager {
    // private var pollingTask: Task<Void, Error>? // Removed as no longer used
    private let apiClient = APIClient()
    
    // Info.plistからApp Group IDを取得。なければ従来値にフォールバック
    private var appGroupIdentifier: String {
        if let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String {
            return id
        }
        return "group.com.nisesimadao.Fetchy"
    }
    
    public init() {}
    
    /// Download video via Railway API
    func download(url: String,
                  quality: String = "1080p",
                  audioOnly: Bool = false,
                  format: String = "mp4",
                  bitrate: String = "192",
                  embedMetadata: Bool = true,
                  embedThumbnail: Bool = true,
                  removeSponsors: Bool = false,
                  embedSubtitles: Bool = false,
                  embedChapters: Bool = false,
                  outputTemplate: String? = nil, // Custom output path support
                  statusHandler: @escaping (Double, String, String?, String?) -> Void,
                  completion: @escaping (Result<URL, Error>, String?) -> Void) {
        
        apiClient.startDownload(url: url, quality: quality, audioOnly: audioOnly, format: format, bitrate: bitrate, embedMetadata: embedMetadata, embedThumbnail: embedThumbnail, removeSponsors: removeSponsors, embedSubtitles: embedSubtitles, embedChapters: embedChapters) { result in
            switch result {
            case .success(let jobId):
                print("[API] Job started: \(jobId)")
                self.pollStatus(jobId: jobId, outputTemplate: outputTemplate, statusHandler: statusHandler, completion: completion)
            case .failure(let error):
                print("[API] Error starting download: \(error)")
                completion(.failure(error), nil)
            }
        }
    }
    
    /// Poll job status until completion
    private func pollStatus(jobId: String,
                           outputTemplate: String?,
                           statusHandler: @escaping (Double, String, String?, String?) -> Void,
                           completion: @escaping (Result<URL, Error>, String?) -> Void,
                           attempts: Int = 0) { // Add attempts parameter for recursive calls
        
        let maxAttempts = 600 // 5 minutes with 0.5s intervals
        
        guard attempts < maxAttempts else {
            apiClient.getLog(jobId: jobId) { logResult in
                let log = try? logResult.get()
                completion(.failure(YTDLPError.timeout), log)
            }
            return
        }
        
        apiClient.getStatus(jobId: jobId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let status):
                // Update progress
                statusHandler(status.progress, status.message, status.extractor, status.title)
                
                switch status.status {
                case "completed":
                    // Notify UI that we are now transferring the file
                    statusHandler(1.0, "DOWNLOADING FILE...", status.extractor, status.title)
                    
                    // Determine destination
                    let destinationURL: URL
                    if let template = outputTemplate {
                        destinationURL = URL(fileURLWithPath: template)
                    } else {
                        // Fallback logic (legacy)
                        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.appGroupIdentifier) else {
                            completion(.failure(YTDLPError.apiError("Could not access App Group")), nil)
                            return
                        }
                        let downloadsDir = containerURL.appendingPathComponent("downloads", isDirectory: true)
                        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
                        let fileName = status.filename ?? status.title?.appending(".mp4") ?? "video.mp4"
                        destinationURL = downloadsDir.appendingPathComponent(fileName)
                    }
                    
                    // Remove existing file at destination if present to ensure clean write
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try? FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    self.apiClient.downloadFile(jobId: jobId, to: destinationURL) { progress in
                        statusHandler(progress, "DOWNLOADING FILE...", status.extractor, status.title)
                    } completion: { downloadResult in
                        switch downloadResult {
                        case .success:
                            self.apiClient.getLog(jobId: jobId) { logResult in
                                let log = try? logResult.get()
                                completion(.success(destinationURL), log)
                            }
                        case .failure(let error):
                            self.apiClient.getLog(jobId: jobId) { logResult in
                                let log = try? logResult.get()
                                completion(.failure(error), log)
                            }
                        }
                    }
                    
                case "failed":
                    self.apiClient.getLog(jobId: jobId) { logResult in
                        let log = try? logResult.get()
                        completion(.failure(YTDLPError.apiError(status.message)), log)
                    }
                    
                default:
                    // Continue polling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.pollStatus(jobId: jobId, outputTemplate: outputTemplate, statusHandler: statusHandler, completion: completion, attempts: attempts + 1)
                    }
                }
                
            case .failure(let error):
                if let apiError = error as? APIError, case .networkError(_) = apiError {
                    // Network error, potentially transient, retry polling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.pollStatus(jobId: jobId, outputTemplate: outputTemplate, statusHandler: statusHandler, completion: completion, attempts: attempts + 1)
                    }
                } else {
                    // Other API errors are considered fatal for this poll cycle
                    self.apiClient.getLog(jobId: jobId) { logResult in
                        let log = try? logResult.get()
                        completion(.failure(error), log)
                    }
                }
            }
        }
    }
}
