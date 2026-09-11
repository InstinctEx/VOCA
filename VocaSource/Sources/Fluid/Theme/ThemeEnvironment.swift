import SwiftUI

private struct ThemeKey: EnvironmentKey {
    static var defaultValue: AppTheme = .dark
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    /// Applies an app theme to the view hierarchy.
    func appTheme(_ theme: AppTheme) -> some View {
        environment(\.theme, theme)
    }
}

struct AdaptiveAppTheme<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsStore.shared

    let accent: Color
    let content: Content

    init(accent: Color, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        let preferredScheme = self.settings.themePreference.preferredColorScheme
        let activeScheme = preferredScheme ?? self.colorScheme

        self.content
            .background(VocaWindowBackground())
            .appTheme(AppTheme.adaptive(accent: self.accent, colorScheme: activeScheme))
            .tint(self.accent)
            .preferredColorScheme(preferredScheme)
            .vocaMotionPolicy()
    }
}

// MARK: - Color Hex Initializer

extension Color {
    /// Custom surface colors are named by role in AppTheme, with paired appearances.
    init(rgb: UInt32) {
        self.init(.sRGB, red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255, opacity: 1)
    }

    /// Initialize a Color from a hex string (e.g., "#FF5733" or "FF5733")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let red = Double((rgb & 0xff0000) >> 16) / 255.0
        let green = Double((rgb & 0x00ff00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000ff) / 255.0

        self.init(red: red, green: green, blue: blue)
    }

    static var fluidGreen: Color {
        SettingsStore.shared.accentColor
    }
}

// Native glass on macOS 26; system material on earlier supported macOS versions.
struct VocaGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.theme) private var theme
    let radius: CGFloat
    var interactive = false
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency || self.contrast == .increased {
            content.background(self.theme.palette.elevatedCardBackground, in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.primary.opacity(self.contrast == .increased ? 0.5 : 0.12)).allowsHitTesting(false))
        } else if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(self.interactive), in: RoundedRectangle(cornerRadius: radius))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.primary.opacity(0.12)).allowsHitTesting(false))
        }
    }
}
extension View {
    func vocaGlass(cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        modifier(VocaGlass(radius: cornerRadius, interactive: interactive))
    }
}

struct VocaGlassGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 12) { self.content }
        } else { self.content }
    }
}

private struct VocaMotionPolicy: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.transaction { transaction in
            if self.reduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }
}
extension View {
    func vocaMotionPolicy() -> some View { self.modifier(VocaMotionPolicy()) }
}
struct VocaWindowBackground: View {
    @Environment(\.theme) private var theme
    var body: some View {
        self.theme.palette.windowBackground.ignoresSafeArea()
    }
}

// Shared VOCA page language. Panels hold content; glass is reserved for controls.
struct VocaPageHeader: View {
    @Environment(\.theme) private var theme
    let title: String
    let subtitle: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 27, weight: .semibold)).tracking(-0.5)
            Text(subtitle).font(.system(size: 14)).foregroundStyle(self.theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VocaSectionHeading: View {
    @Environment(\.theme) private var theme
    let title: String
    var detail: String = ""
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 15, weight: .semibold))
            Spacer()
            if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(self.theme.palette.secondaryText) }
        }
    }
}

struct VocaContentSurface: ViewModifier {
    @Environment(\.theme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        content
            .background(self.theme.palette.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(self.contrast == .increased ? Color.primary.opacity(0.5) : self.theme.palette.cardBorder.opacity(0.6))
                    .allowsHitTesting(false)
            }
    }
}
extension View {
    func vocaContentSurface() -> some View { modifier(VocaContentSurface()) }
}

/// VOCA's voice mark: a restrained waveform, shared by navigation and local AI.
struct VocaBrandMark: View {
    var size: CGFloat = 32
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(.primary.opacity(0.07))
            HStack(spacing: size * 0.075) {
                ForEach(Array([0.24, 0.48, 0.68, 0.42, 0.22].enumerated()), id: \.offset) { _, height in
                    Capsule().fill(.primary).frame(width: size * 0.075, height: size * height)
                }
            }
        }.frame(width: size, height: size).accessibilityLabel("VOCA")
    }
}

/// A disclosure is a full-width button, not a tiny chevron target.
struct VocaDisclosureStyle: DisclosureGroupStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(self.reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    configuration.label
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                }.frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                    .contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityValue(configuration.isExpanded ? "Expanded" : "Collapsed")
            if configuration.isExpanded { configuration.content }
        }
    }
}

private struct VocaDetailViewport: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.scrollEdgeEffectHidden(true, for: .top).clipped()
        } else { content.clipped() }
    }
}
extension View {
    func vocaDetailViewport() -> some View { modifier(VocaDetailViewport()) }
}
