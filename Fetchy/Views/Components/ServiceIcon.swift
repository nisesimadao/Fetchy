import SwiftUI

struct ServiceIcon: View {
    let serviceName: String
    let size: CGFloat
    
    init(_ serviceName: String, size: CGFloat = 36) {
        self.serviceName = serviceName
        self.size = size
    }
    
    var body: some View {
        let (iconName, color) = mapServiceToStyle(serviceName)
        
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            
            Image(systemName: iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.5, height: size * 0.5)
                .foregroundColor(.white) // White symbols on colored backgrounds
        }
    }
    
    private func mapServiceToStyle(_ name: String) -> (String, Color) {
        let lower = name.lowercased()
        let red = DesignSystem.Colors.nothingRed
        
        if lower.contains("youtube") { return ("play.rectangle.fill", red) }
        if lower.contains("tiktok") { return ("music.note", red) }
        if lower.contains("twitter") || lower.contains("x.com") || lower.contains("x") { return ("at", red) }
        if lower.contains("instagram") { return ("camera.fill", .red) } // Standard red for IG if distinct? Or red.
        if lower.contains("facebook") { return ("f.circle.fill", .blue) }
        
        return ("link", Color.gray.opacity(0.5))
    }
}
