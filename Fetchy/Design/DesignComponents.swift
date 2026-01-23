import SwiftUI

// MARK: - Design System Constants

enum DesignSystem {
    enum Colors {
        static let glassLight = Color.white.opacity(0.4)
        static let glassDark = Color.black.opacity(0.6)
        static let borderLight = Color.white.opacity(0.6)
        static let borderDark = Color.white.opacity(0.1)
        static let nothingRed = Color(red: 0.85, green: 0.1, blue: 0.1)
    }
    
    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
    }
    
    enum CornerRadius {
        static let squircle: CGFloat = 24
        static let card: CGFloat = 16
    }
}

// MARK: - 1. LiquidGlass Material (Physics-Based)

struct LiquidGlassModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = DesignSystem.CornerRadius.squircle) {
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Optimized manual stack to prevent distortion on tall views
                    // Fallback solid
                    if colorScheme == .dark {
                        Color.black.opacity(0.8)
                    } else {
                        Color.white.opacity(0.8)
                    }

                    // A. Material & Blur
                    Rectangle()
                        .fill(colorScheme == .dark ? DesignSystem.Colors.glassDark : DesignSystem.Colors.glassLight)
                        .background(.ultraThinMaterial)
                    
                    // B. Refraction & Lens Thickness
                    // Using an overlay stroke instead of inner geometry for better stability
                }
            )
            // B. Refraction highlight (Inner Border)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .white.opacity(0.4), location: 0),
                                .init(color: .white.opacity(0.05), location: 1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            // C. Specular Highlights
            .overlay(
                contentHeightClippingSheen()
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // Outer Silhouette
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.05), lineWidth: 0.5)
            )
    }
    
    @ViewBuilder
    private func contentHeightClippingSheen() -> some View {
        // Simplified sheen that doesn't stretch weirdly on tall items
        GeometryReader { _ in
            LinearGradient(
                gradient: Gradient(colors: [.white.opacity(0.05), .clear]),
                startPoint: .topLeading,
                endPoint: .center
            )
        }
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = DesignSystem.CornerRadius.squircle) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - 2. Nothing Design Elements (Industrial/Dot Matrix)

// Font Extensions
extension Font {
    static let nothingHeader = Font.system(size: 20, weight: .semibold, design: .default)
    static let nothingBody = Font.system(size: 15, weight: .regular, design: .default)
    static let nothingMeta = Font.system(size: 11, weight: .medium, design: .monospaced)
}

// Dot Matrix Text Component
struct DotMatrixText: View {
    let text: String
    
    var body: some View {
        Text(text.uppercased())
            .font(.nothingMeta)
            .kerning(1.2)
            .foregroundStyle(.secondary)
    }
}

// Industrial Button Style
struct IndustrialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nothingBody)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
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
    var isWarning: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isWarning ? "exclamationmark.triangle" : "info.circle")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isWarning ? .yellow : DesignSystem.Colors.nothingRed)
            
            Text(message)
                .font(.nothingMeta)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .liquidGlass(cornerRadius: 12)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}
