import Foundation
import Combine

enum YTDLPError: Error {
    case apiError(String)
    case networkError(Error)
    case timeout
    case unknown
}

class YTDLPManager: ObservableObject {
    static let shared = YTDLPManager()
    
    private var pollingTask: Task<Void, Never>?
    private let apiClient = APIClient.shared
    
    private init() {}
    
    /// Download video via Railway API
    func download(url: String,
                  quality: String = "1080p",
                  audioOnly: Bool = false,
                  format: String = "mp4",
                  bitrate: String = "192",
                  statusHandler: @escaping (Double, String) -> Void,
                  completion: @escaping (Result<URL, Error>, String?) -> Void) {
        
        Task {
            do {
                // Start download job
                let jobId = try await apiClient.startDownload(url: url, quality: quality, audioOnly: audioOnly, format: format, bitrate: bitrate)
                print("[API] Job started: \(jobId)")
                
                // Poll for status
                try await pollStatus(jobId: jobId, statusHandler: statusHandler, completion: completion)
                
            } catch {
                print("[API] Error starting download: \(error)")
                completion(.failure(error), nil)
            }
        }
    }
    
    /// Poll job status until completion
    private func pollStatus(jobId: String,
                           statusHandler: @escaping (Double, String) -> Void,
                           completion: @escaping (Result<URL, Error>, String?) -> Void) async throws {
        
        print("[YTDLP] Starting poll for \(jobId)")
        var attempts = 0
        let maxAttempts = 600 // 5 minutes with 0.5s intervals
        
        while attempts < maxAttempts {
            do {
                let status = try await apiClient.getStatus(jobId: jobId)
                
                // Update progress
                statusHandler(status.progress, status.message)
                
                switch status.status {
                case "completed":
                    // Download file
                    let tempDir = FileManager.default.temporaryDirectory
                    let fileName = status.filename ?? status.title?.appending(".mp4") ?? "video.mp4"
                    let destination = tempDir.appendingPathComponent(fileName)
                    
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try? FileManager.default.removeItem(at: destination)
                    }
                    
                    try await apiClient.downloadFile(jobId: jobId, to: destination)
                    let log = try? await apiClient.getLog(jobId: jobId)
                    completion(.success(destination), log)
                    return
                    
                case "failed":
                    let log = try? await apiClient.getLog(jobId: jobId)
                    completion(.failure(YTDLPError.apiError(status.message)), log)
                    return
                    
                default:
                    // Continue polling
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                    attempts += 1
                }
                
            } catch {
                print("[API] Polling error: \(error)")
                let log = try? await apiClient.getLog(jobId: jobId)
                completion(.failure(error), log)
                return
            }
        }
        
        let log = try? await apiClient.getLog(jobId: jobId)
        completion(.failure(YTDLPError.timeout), log)
    }
    
    func cancel() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
