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
                  statusHandler: @escaping (Double, String) -> Void,
                  completion: @escaping (Result<(URL, String), Error>) -> Void) {
        
        Task {
            do {
                // Start download job
                let jobId = try await apiClient.startDownload(url: url, quality: quality)
                print("[API] Job started: \(jobId)")
                
                // Poll for status
                try await pollStatus(jobId: jobId, statusHandler: statusHandler, completion: completion)
                
            } catch {
                print("[API] Error starting download: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Poll job status until completion
    private func pollStatus(jobId: String,
                           statusHandler: @escaping (Double, String) -> Void,
                           completion: @escaping (Result<(URL, String), Error>) -> Void) async throws {
        
        var attempts = 0
        let maxAttempts = 600 // 10 minutes with 1s intervals
        
        while attempts < maxAttempts {
            do {
                let status = try await apiClient.getStatus(jobId: jobId)
                
                // Update progress
                statusHandler(status.progress, status.message)
                
                switch status.status {
                case "completed":
                    // Download file
                    let tempDir = FileManager.default.temporaryDirectory
                    let fileName = status.title ?? "video.mp4"
                    let destination = tempDir.appendingPathComponent(fileName)
                    
                    try await apiClient.downloadFile(jobId: jobId, to: destination)
                    
                    // Get log
                    let log = try await apiClient.getLog(jobId: jobId)
                    
                    completion(.success((destination, log)))
                    return
                    
                case "failed":
                    completion(.failure(YTDLPError.apiError(status.message)))
                    return
                    
                default:
                    // Continue polling
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    attempts += 1
                }
                
            } catch {
                print("[API] Polling error: \(error)")
                completion(.failure(error))
                return
            }
        }
        
        // Timeout
        completion(.failure(YTDLPError.timeout))
    }
    
    func cancel() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
