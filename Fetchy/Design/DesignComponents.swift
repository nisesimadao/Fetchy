import SwiftUI

// MARK: - Design System Constants

enum DesignSystem {
    enum Colors {
        static let glassLight = Color.white.opacity(0.4)
        static let glassDark = Color.black.opacity(0.6)
        static let borderLight = Color.white.opacity(0.6)
        static let borderDark = Color.white.opacity(0.1)
        static let nothingRed = Color(red: 0.85, green: 0.1, blue: 0.1) // Typical Nothing accent
    }
    
    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
    }
    
    enum CornerRadius {
        static let squircle: CGFloat = 24 // Soft continuous curve approximation
    }
}

// MARK: - 1. LiquidGlass Material (Physics-Based)

struct LiquidGlassModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        // Logic for OS Versioning (Simulated for "iOS 26+")
        // In a real build, #available(iOS 26, *) would replace this check.
        // For now, we default to the manual stack as 2026 is < iOS 26.
        if #available(iOS 26, *) {
            content.glassEffect() // Hypothetical API
        } else {
            manualStack(content)
        }
    }
    
    @ViewBuilder
    private func manualStack(_ content: Content) -> some View {
        content
            .background(
                ZStack {
                    // A. Material & Blur
                    // Note: In strict SwiftUI, visualEffect or separate UIViewRepresentable is often needed for precise Gaussian blur radius in px.
                    // Here we use native material + color overlays to approximate.
                    
                    // Fallback solid for non-blur environments
                   if colorScheme == .dark {
                       Color.black.opacity(0.8)
                   } else {
                       Color.white.opacity(0.8)
                   }

                    // The "Thin Optical Glass" Simulation
                    Rectangle()
                        .fill(colorScheme == .dark ? DesignSystem.Colors.glassDark : DesignSystem.Colors.glassLight)
                        .background(.ultraThinMaterial) // Closest native approximation to blur(12-15px)
                        .environment(\.colorScheme, colorScheme) // Maintain scheme
                    
                    // B. Refraction highlight (Inner Border)
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.squircle, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .white.opacity(0.6), location: 0), // Top-left specular
                                    .init(color: .white.opacity(0.1), location: 1)  // Bottom-right fade
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                    
                    // B. Lens Thickness (Inner Shadow approximation)
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.squircle, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 10)
                        .blur(radius: 5) // Soften to create "inset glow/thickness" effect
                        .mask(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.squircle, style: .continuous))
                }
            )
            // C. Specular Highlights (Surface Sheen)
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .white.opacity(0.05),
                        .clear,
                        .clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .center
                )
                .mask(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.squircle, style: .continuous))
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.squircle, style: .continuous))
            // B. Outer Stroke (Silhouette)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.squircle, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
            )
            // Physics-based scaling handled by button styles usually, but can be added here if this acts as a container
    }
}

extension View {
    func liquidGlass() -> some View {
        self.modifier(LiquidGlassModifier())
    }
}

// MARK: - 2. Nothing Design Elements (Industrial/Dot Matrix)

// Font Extensions
extension Font {
    static let nothingHeader = Font.system(size: 24, weight: .semibold, design: .default)
    static let nothingBody = Font.system(size: 16, weight: .regular, design: .default)
    
    // Dot Matrix / Monospaced for Meta info
    static let nothingMeta = Font.system(size: 12, weight: .medium, design: .monospaced)
}

// Dot Matrix Text Component
struct DotMatrixText: View {
    let text: String
    
    var body: some View {
        Text(text.uppercased())
            .font(.nothingMeta)
            .kerning(1.2) // Wide tracking for industrial feel
            .foregroundStyle(.secondary)
    }
}

// Industrial Button Style
struct IndustrialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nothingBody)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - 3. Common Components

struct ToastView: View {
    let message: String
    let isWarning: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isWarning ? "exclamationmark.triangle" : "info.circle")
                .font(.system(size: 14, weight: .bold))
            
            Text(message)
                .font(.nothingBody)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .liquidGlass() // Apply our signature material
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}
