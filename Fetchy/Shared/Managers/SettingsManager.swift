import Foundation
import SwiftUI
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private var appGroupIdentifier: String { AppGroup.identifier }
    private var store: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    @Published var vibrationEnabled: Bool = true {
        didSet { save("vibrationEnabled", value: vibrationEnabled) }
    }
    
    @Published var vibrationStrength: String = "light" {
        didSet { save("vibrationStrength", value: vibrationStrength) }
    }
    
    @Published var hapticFrequency: Int = 2 { // 2% steps
        didSet { save("hapticFrequency", value: hapticFrequency) }
    }
    
    @Published var progressVisible: Bool = false {
        didSet { save("progressVisible", value: progressVisible) }
    }
    
    @Published var toastEnabled: Bool = true {
        didSet { save("toastEnabled", value: toastEnabled) }
    }
    
    @Published var toastDelaySeconds: Int = 5 { // Default 5s
        didSet { save("toastDelaySeconds", value: toastDelaySeconds) }
    }
    
    @Published var defaultResolution: String = "1080p" {
        didSet { save("defaultResolution", value: defaultResolution) }
    }
    
    @Published var defaultBitrate: String = "192" {
        didSet { save("defaultBitrate", value: defaultBitrate) }
    }
    
    @Published var defaultVideoFormat: String = "mp4" {
        didSet { save("defaultVideoFormat", value: defaultVideoFormat) }
    }
    
    @Published var defaultAudioFormat: String = "mp3" {
        didSet { save("defaultAudioFormat", value: defaultAudioFormat) }
    }
    
    @Published var embedMetadata: Bool = false {
        didSet { save("embedMetadata", value: embedMetadata) }
    }
    
    @Published var embedThumbnail: Bool = false {
        didSet { save("embedThumbnail", value: embedThumbnail) }
    }
    
    @Published var removeSponsors: Bool = false {
        didSet { save("removeSponsors", value: removeSponsors) }
    }
    
    @Published var embedSubtitles: Bool = false {
        didSet { save("embedSubtitles", value: embedSubtitles) }
    }
    
    @Published var embedChapters: Bool = false {
        didSet { save("embedChapters", value: embedChapters) }
    }
    
    @Published var backendURL: String = "https://fetchy-api.onrender.com" {
        didSet { save("backendURL", value: backendURL) }
    }
    
    private init() {
        self.vibrationEnabled = store?.bool(forKey: "vibrationEnabled") ?? true
        self.vibrationStrength = store?.string(forKey: "vibrationStrength") ?? "light"
        self.hapticFrequency = store?.integer(forKey: "hapticFrequency") == 0 ? 2 : store!.integer(forKey: "hapticFrequency")
        self.progressVisible = store?.bool(forKey: "progressVisible") ?? false
        self.toastEnabled = store?.bool(forKey: "toastEnabled") ?? true
        self.toastDelaySeconds = store?.integer(forKey: "toastDelaySeconds") == 0 ? 5 : store!.integer(forKey: "toastDelaySeconds")
        self.defaultResolution = store?.string(forKey: "defaultResolution") ?? "1080p"
        self.defaultBitrate = store?.string(forKey: "defaultBitrate") ?? "192"
        self.defaultVideoFormat = store?.string(forKey: "defaultVideoFormat") ?? "mp4"
        self.defaultAudioFormat = store?.string(forKey: "defaultAudioFormat") ?? "mp3"
        self.embedMetadata = store?.bool(forKey: "embedMetadata") ?? false
        self.embedThumbnail = store?.bool(forKey: "embedThumbnail") ?? false
        self.removeSponsors = store?.bool(forKey: "removeSponsors") ?? false
        self.embedSubtitles = store?.bool(forKey: "embedSubtitles") ?? false
        self.embedChapters = store?.bool(forKey: "embedChapters") ?? false
        
        // Initialize new backendURL
        self.backendURL = store?.string(forKey: "backendURL") ?? "https://fetchy-api--vistaope.replit.app"
    }
    
    private func save(_ key: String, value: Any) {
        store?.set(value, forKey: key)
        store?.synchronize() // Force sync for Extension
    }
    
    func getValue<T>(forKey key: String) -> T? {
        store?.value(forKey: key) as? T
    }
}

