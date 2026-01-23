import Foundation
import Combine

/// API client for communicating with Railway backend
class APIClient: ObservableObject {
    static let shared = APIClient()
    
    // TODO: Replace with your Railway deployment URL
    private let baseURL = "https://your-railway-app.railway.app"
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    /// Start a download job
    func startDownload(url: String, quality: String = "1080p") async throws -> String {
        let endpoint = URL(string: "\(baseURL)/api/download")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["url": url, "quality": quality]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(DownloadResponse.self, from: data)
        return result.jobId
    }
    
    /// Get job status
    func getStatus(jobId: String) async throws -> JobStatus {
        let endpoint = URL(string: "\(baseURL)/api/status/\(jobId)")!
        let (data, _) = try await session.data(from: endpoint)
        return try JSONDecoder().decode(JobStatus.self, from: data)
    }
    
    /// Download completed file
    func downloadFile(jobId: String, to destination: URL) async throws {
        let endpoint = URL(string: "\(baseURL)/api/download/\(jobId)")!
        let (tempURL, response) = try await session.download(from: endpoint)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.downloadFailed
        }
        
        try FileManager.default.moveItem(at: tempURL, to: destination)
    }
    
    /// Get raw log
    func getLog(jobId: String) async throws -> String {
        let endpoint = URL(string: "\(baseURL)/api/log/\(jobId)")!
        let (data, _) = try await session.data(from: endpoint)
        let result = try JSONDecoder().decode(LogResponse.self, from: data)
        return result.log
    }
}

// MARK: - Models

struct DownloadResponse: Codable {
    let jobId: String
    let status: String
}

struct JobStatus: Codable {
    let status: String
    let progress: Double
    let message: String
    let downloadUrl: String?
    let title: String?
}

struct LogResponse: Codable {
    let log: String
}

enum APIError: LocalizedError {
    case invalidResponse
    case downloadFailed
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .downloadFailed:
            return "Download failed"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}
