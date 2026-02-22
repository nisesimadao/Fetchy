import Foundation
import Combine

/// API client for communicating with Railway backend
class APIClient: ObservableObject { // Make it ObservableObject to use @Published and combine
    static let shared = APIClient()
    
    @Published private var baseURL: String // Make it @Published var
    private var cancellables = Set<AnyCancellable>()
    
    private let session: URLSession
    
    public init() {
        // Initialize baseURL with current setting
        self.baseURL = SettingsManager.shared.backendURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        
        // Subscribe to changes in SettingsManager.shared.backendURL
        SettingsManager.shared.$backendURL
            .sink { [weak self] newURL in
                self?.baseURL = newURL
            }
            .store(in: &cancellables)
    }
    
    /// Start a download job
    func startDownload(url: String, quality: String = "1080p", audioOnly: Bool = false, format: String = "mp4", bitrate: String = "192", embedMetadata: Bool = true, embedThumbnail: Bool = true, removeSponsors: Bool = false, embedSubtitles: Bool = false, embedChapters: Bool = false, completion: @escaping (Result<String, Error>) -> Void) {
        guard let endpoint = URL(string: "\(baseURL)/api/download") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "url": url,
            "quality": quality,
            "audioOnly": audioOnly,
            "format": format,
            "bitrate": bitrate,
            "embedMetadata": embedMetadata,
            "embedThumbnail": embedThumbnail,
            "removeSponsors": removeSponsors,
            "embedSubtitles": embedSubtitles,
            "embedChapters": embedChapters
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        if #available(iOS 15, *) {
            Task {
                do {
                    let (data, response) = try await session.data(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        throw APIError.invalidResponse
                    }
                    
                    let result = try JSONDecoder().decode(DownloadResponse.self, from: data)
                    DispatchQueue.main.async {
                        completion(.success(result.jobId))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        } else {
            session.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(.failure(APIError.networkError(error)))
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    DispatchQueue.main.async {
                        completion(.failure(APIError.invalidResponse))
                    }
                    return
                }
                
                guard let data = data else {
                    DispatchQueue.main.async {
                        completion(.failure(APIError.invalidResponse)) // Or a more specific "no data" error
                    }
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(DownloadResponse.self, from: data)
                    DispatchQueue.main.async {
                        completion(.success(result.jobId))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }.resume()
        }
    }
    
    /// Get job status
    func getStatus(jobId: String, completion: @escaping (Result<JobStatus, Error>) -> Void) {
        guard let endpoint = URL(string: "\(baseURL)/api/status/\(jobId)") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        if #available(iOS 15, *) {
            Task {
                do {
                    let (data, _) = try await session.data(from: endpoint)
                    let result = try JSONDecoder().decode(JobStatus.self, from: data)
                    DispatchQueue.main.async {
                        completion(.success(result))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        } else {
            session.dataTask(with: endpoint) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(.failure(APIError.networkError(error)))
                    }
                    return
                }
                
                guard let data = data else {
                    DispatchQueue.main.async {
                        completion(.failure(APIError.invalidResponse)) // Or a more specific "no data" error
                    }
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(JobStatus.self, from: data)
                    DispatchQueue.main.async {
                        completion(.success(result))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }.resume()
        }
    }
    
    /// Download completed file
    /// Download completed file with progress tracking
    func downloadFile(jobId: String, to destination: URL, progressHandler: ((Double) -> Void)? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let endpoint = URL(string: "\(baseURL)/api/download/\(jobId)") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        if #available(iOS 15, *) {
            Task {
                do {
                    try await withCheckedThrowingContinuation { continuation in
                        let delegate = DownloadDelegate(progressHandler: progressHandler, destination: destination, completion: { result in
                            switch result {
                            case .success: continuation.resume()
                            case .failure(let error): continuation.resume(throwing: error)
                            }
                        })
                        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
                        let task = session.downloadTask(with: endpoint)
                        task.resume()
                        // Session is retained by the task/delegate cycle until completion
                    }
                    DispatchQueue.main.async {
                        completion(.success(()))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        } else {
            let delegate = DownloadDelegate(progressHandler: progressHandler, destination: destination, completion: completion)
            // URLSession needs to be strongly referenced during the download.
            // Using a dictionary to hold delegates keyed by taskIdentifier to prevent deallocation.
            // This is a common pattern for pre-iOS15 delegate-based downloads.
            // For simplicity, we'll keep it as a local variable for now, assuming external management
            // or that the APIClient instance lives long enough.
            // In a real app, you'd have a map like [URLSessionTask.taskIdentifier: DownloadDelegate]
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = session.downloadTask(with: endpoint)
            task.resume()
            // The delegate needs to be retained. In a real app, APIClient would keep a map of
            // delegates, possibly associated with jobIds or taskIdentifiers.
            // For this example, we assume APIClient has a long enough lifecycle
            // or DownloadManager manages this.
        }
    }
    
    // Internal Delegate to handle progress and completion
    private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
        let progressHandler: ((Double) -> Void)?
        let destination: URL
        var completion: ((Result<Void, Error>) -> Void)? // Changed to optional completion handler
        
        init(progressHandler: ((Double) -> Void)?, destination: URL, completion: ((Result<Void, Error>) -> Void)?) {
            self.progressHandler = progressHandler
            self.destination = destination
            self.completion = completion
        }
        
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            progressHandler?(progress)
        }
        
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: location, to: destination)
                DispatchQueue.main.async { // Ensure completion is called on main thread
                    self.completion?(.success(()))
                }
            } catch {
                DispatchQueue.main.async { // Ensure completion is called on main thread
                    self.completion?(.failure(error))
                }
            }
        }
        
        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            // This is called AFTER didFinishDownloadingTo if successful, or if an error occurred *during* download.
            // Only call completion here if didFinishDownloadingTo wasn't called (i.e., it was a general task error)
            if let error = error {
                DispatchQueue.main.async { // Ensure completion is called on main thread
                    self.completion?(.failure(error))
                }
            }
            self.completion = nil // Clear to prevent multiple calls
        }
    }
    
    /// Get raw log
    func getLog(jobId: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let endpoint = URL(string: "\(baseURL)/api/log/\(jobId)") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        if #available(iOS 15, *) {
            Task {
                do {
                    let (data, _) = try await session.data(from: endpoint)
                    let result = try JSONDecoder().decode(LogResponse.self, from: data)
                    DispatchQueue.main.async {
                        completion(.success(result.log))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        } else {
            session.dataTask(with: endpoint) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(.failure(APIError.networkError(error)))
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    DispatchQueue.main.async {
                        completion(.failure(APIError.invalidResponse))
                    }
                    return
                }
                
                guard let data = data else {
                    DispatchQueue.main.async {
                        completion(.failure(APIError.invalidResponse)) // Or a more specific "no data" error
                    }
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(LogResponse.self, from: data)
                    DispatchQueue.main.async {
                        completion(.success(result.log))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }.resume()
        }
    }
}

// MARK: - Models

struct DownloadResponse: Codable {
    let jobId: String
}

struct JobStatus: Codable {
    let status: String
    let progress: Double
    let message: String
    let downloadUrl: String?
    let title: String?
    let filename: String?
    let extractor: String?
}

struct LogResponse: Codable {
    let log: String
}

enum APIError: LocalizedError {
    case invalidResponse
    case downloadFailed
    case networkError(Error)
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .downloadFailed:
            return "Download failed"
        case .networkError(let error):
            return error.localizedDescription
        case .invalidURL:
            return "Invalid API URL provided in settings"
        }
    }
}
