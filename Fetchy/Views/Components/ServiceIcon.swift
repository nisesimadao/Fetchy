import SwiftUI

struct ServiceIcon: View {
    let serviceName: String
    let size: CGFloat
    
    init(_ serviceName: String, size: CGFloat = 40) {
        self.serviceName = serviceName
        self.size = size
    }
    
    var body: some View {
        let (iconName, _) = mapServiceToSymbol(serviceName)
        
        Circle()
            .fill(Color.accentColor.opacity(0.1))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.5, height: size * 0.5)
                    .foregroundStyle(Color.accentColor)
            )
    }
    
    private func mapServiceToSymbol(_ name: String) -> (String, Bool) {
        let lower = name.lowercased()
        // Returns (SF Symbol Name, IsCustom?)
        if lower.contains("youtube") { return ("play.rectangle.fill", true) }
        if lower.contains("tiktok") { return ("music.note", true) }
        if lower.contains("twitter") || lower.contains("x.com") { return ("at", true) } // SF doesn't have X logo, 'at' or 'number' is close enough for generic
        if lower.contains("instagram") { return ("camera.fill", true) }
        if lower.contains("facebook") { return ("f.circle.fill", true) } // 'f.cursive' or similar might exist, defaulting to generic text-like
        
        return ("link", false)
    }
}
