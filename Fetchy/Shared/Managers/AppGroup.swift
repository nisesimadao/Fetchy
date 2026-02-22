// AppGroup.swift
// 共通のApp Group IDユーティリティ
import Foundation

// A helper class to get the bundle
private class BundleFinder {}

/// Info.plistのAppGroupIdentifierからIDを取得し、なければ従来値にフォールバック
struct AppGroup {
    static var identifier: String {
        // Use Bundle(for:) to ensure the correct bundle is searched in both the app and the extension
        let bundle = Bundle(for: BundleFinder.self)
        
        if let id = bundle.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String {
            return id
        }
        
        // Fallback for safety, but the plist should always have the identifier.
        return "group.com.nisesimadao.Fetchy"
    }
}
