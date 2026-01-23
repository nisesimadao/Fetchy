import Foundation
import Combine

// MARK: - Process Polyfill for iOS
// 'Process' (NSTask) is not public on iOS, but exists in the runtime.
// This allows compilation on iOS to support 'Designed for iPad' on Mac.
#if os(iOS)
class Process: NSObject {
    private let task: AnyObject
    
    var executableURL: URL? {
        didSet {
            task.setValue(executableURL?.path, forKey: "launchPath")
        }
    }
    
    var arguments: [String]? {
        didSet {
            task.setValue(arguments, forKey: "arguments")
        }
    }
    
    var standardOutput: Any? {
        didSet {
            task.setValue(standardOutput, forKey: "standardOutput")
        }
    }
    
    var standardError: Any? {
        didSet {
            task.setValue(standardError, forKey: "standardError")
        }
    }
    
    var terminationHandler: ((Process) -> Void)?
    var terminationStatus: Int32 {
        return (task.value(forKey: "terminationStatus") as? Int32) ?? 0
    }
    
    override init() {
        let taskClass = NSClassFromString("NSTask") as! NSObject.Type
        self.task = taskClass.init()
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(taskDidTerminate(_:)), name: NSNotification.Name("NSTaskDidTerminateNotification"), object: task)
    }
    
    func run() throws {
        let selector = Selector(("launch"))
        if task.responds(to: selector) {
            _ = task.perform(selector)
        } else {
            throw YTDLPError.osNotSupported
        }
    }
    
    func terminate() {
        _ = task.perform(Selector(("terminate")))
    }
    
    @objc private func taskDidTerminate(_ notification: Notification) {
        terminationHandler?(self)
    }
}
#endif

enum YTDLPError: Error {
    case binaryNotFound
    case processFailed(Int32)
    case cancelled
    case unknown
    case osNotSupported
}

class YTDLPManager: ObservableObject {
    static let shared = YTDLPManager()
    
    private var currentProcess: Process?
    private var outputPipe: Pipe?
    
    func download(url: String, 
                  quality: String = "1080p", 
                  progressHandler: @escaping (Double) -> Void, 
                  completion: @escaping (Result<URL, Error>) -> Void) {
        
        guard let binaryPath = Bundle.main.path(forResource: "yt-dlp", ofType: nil) else {
            completion(.failure(YTDLPError.binaryNotFound))
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let outputPathTemplate = tempDir.appendingPathComponent("%(title)s.%(ext)s").path
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "--newline",
            "--progress",
            "-o", outputPathTemplate,
            url
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        self.outputPipe = pipe
        self.currentProcess = process
        
        let outHandle = pipe.fileHandleForReading
        outHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            if let str = String(data: data, encoding: .utf8) {
                self.parseProgress(from: str, handler: progressHandler)
            }
        }
        
        process.terminationHandler = { (proc: Process) in
            outHandle.readabilityHandler = nil
            
            if proc.terminationStatus == 0 {
                do {
                    let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                    if let videoFile = files.first {
                        completion(.success(videoFile))
                    } else {
                        completion(.failure(YTDLPError.unknown))
                    }
                } catch {
                    completion(.failure(error))
                }
            } else {
                completion(.failure(YTDLPError.processFailed(proc.terminationStatus)))
            }
            self.currentProcess = nil
        }
        
        do {
            try process.run()
        } catch {
            completion(.failure(error))
        }
    }
    
    func cancel() {
        currentProcess?.terminate()
        currentProcess = nil
    }
    
    private func parseProgress(from output: String, handler: @escaping (Double) -> Void) {
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.contains("[download]") && line.contains("%") {
                let components = line.components(separatedBy: CharacterSet.whitespaces)
                for comp in components {
                    if comp.contains("%") {
                        let numStr = comp.replacingOccurrences(of: "%", with: "")
                        if let val = Double(numStr) {
                            DispatchQueue.main.async {
                                handler(val / 100.0)
                            }
                        }
                    }
                }
            }
        }
    }
}

