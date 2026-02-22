import SwiftUI

// MARK: - Design System Constants

enum DesignSystem {
    enum Colors {
        // Semantic glass colors
        static func glass(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.black.opacity(0.6) : Color.white.opacity(0.4)
        }
        
        static func border(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
        }
        
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

// MARK: - 1. LiquidGlass Material (Optimized Physics-Based)

struct LiquidGlassModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = DesignSystem.CornerRadius.squircle) {
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect()
        } else {
            optimizedManualStack(content)
        }
    }
    
    @ViewBuilder
    private func optimizedManualStack(_ content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)) // Ensure content is clipped
            .background(
                ZStack {
                    // Optimized Material Layer
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(DesignSystem.Colors.glass(for: colorScheme))
                        .if(availableiOS: 15.0) {
                            if #available(iOS 15.0, *) {
                                $0.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                            } else {
                                $0
                            }
                        }
                    
                    // Refraction Highlight (Inner border)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(colorScheme == .dark ? 0.3 : 0.6), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .overlay(
                // Silhouette Border
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DesignSystem.Colors.border(for: colorScheme), lineWidth: 0.5)
            )
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = DesignSystem.CornerRadius.squircle) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - 2. Design Elements

extension Font {
    // Balanced Font System - Toned down for Apple HIG harmony
    static let nothingHeader = Font.system(size: 20, weight: .semibold, design: .default)
    static let nothingBody = Font.system(size: 15, weight: .regular, design: .default)
    static let nothingMeta = Font.system(size: 11, weight: .semibold, design: .default) // Standard design instead of monospaced
}

struct DotMatrixText: View {
    let text: String
    var usesUppercase: Bool = true
    
    var body: some View {
        Text(usesUppercase ? text.uppercased() : text)
            .font(.nothingMeta)
            .kerning(0.5) // Reduced kerning
            .if(availableiOS: 15.0) {
                if #available(iOS 15.0, *) {
                    $0.foregroundStyle(.secondary)
                } else {
                    $0
                }
            } otherwise: {
                $0.foregroundColor(.secondary)
            }
    }
}

struct IndustrialButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .if(availableiOS: 15.0) {
                $0.animation(.interactiveSpring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            } otherwise: {
                $0.animation(.interactiveSpring(response: 0.2, dampingFraction: 0.7))
            }
    }
}

// MARK: - 3. Common Components

struct ToastView: View {
    @Environment(\.colorScheme) var colorScheme
    let message: String
    var isWarning: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundColor(isWarning ? .yellow : DesignSystem.Colors.nothingRed)
            
            Text(message)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .if(availableiOS: 15.0) {
                    if #available(iOS 15.0, *) {
                        $0.fill(.thinMaterial)
                    } else {
                        $0
                    }
                } otherwise: {
                    $0.fill(colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.8))
                }
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Helper Extensions for iOS 14
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, @ViewBuilder transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        @ViewBuilder then trueTransform: (Self) -> TrueContent,
        @ViewBuilder otherwise falseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            trueTransform(self)
        } else {
            falseTransform(self)
        }
    }

    @ViewBuilder
    func `if`<TrueContent: View>(
        availableiOS version: Double,
        @ViewBuilder then trueTransform: (Self) -> TrueContent
    ) -> some View {
        if #available(iOS 15.0, *) {
             trueTransform(self)
        } else {
             self
        }
    }

    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        availableiOS version: Double,
        @ViewBuilder then trueTransform: (Self) -> TrueContent,
        @ViewBuilder otherwise falseTransform: (Self) -> FalseContent
    ) -> some View {
        if #available(iOS 15.0, *) {
             trueTransform(self)
        } else {
             falseTransform(self)
        }
    }
}
