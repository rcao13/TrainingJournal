import SwiftUI
import UIKit

extension Color {
    /// A colour with separate light- and dark-mode values.
    static func adaptive(light: UInt32, dark: UInt32, lightOpacity: Double = 1, darkOpacity: Double = 1) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? .hex(dark, alpha: darkOpacity)
                : .hex(light, alpha: lightOpacity)
        })
    }

    static func hex(_ value: UInt32, opacity: Double = 1) -> Color {
        Color(uiColor: .hex(value, alpha: opacity))
    }
}

private extension UIColor {
    static func hex(_ value: UInt32, alpha: Double) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: alpha)
    }
}

/// App palette. Light mode is monochrome (ink, grey, deep navy accent) on frosted glass;
/// dark mode is "Midnight": charcoal, periwinkle accent, mint for done/ready.
/// The accent itself lives in the AccentColor asset so system controls pick it up.
enum Theme {
    static let ink = Color.adaptive(light: 0x111111, dark: 0xEDEFF3)
    static let secondary = Color.adaptive(light: 0x7C7C82, dark: 0x8B919C)
    static let accent = Color.accentColor
    /// Done sets and recovered muscles.
    static let ready = Color.adaptive(light: 0x111111, dark: 0x5ED3A8)
    /// Empty tracks, pills and subtle fills.
    static let track = Color.adaptive(light: 0x111111, dark: 0xFFFFFF, lightOpacity: 0.07, darkOpacity: 0.08)
    /// List rows that sit on the app background.
    static let rowFill = Color.adaptive(light: 0xFFFFFF, dark: 0x171A20, lightOpacity: 0.72)
    static let cardFill = Color.hex(0x171A20)
    static let cardBorder = Color.hex(0xFFFFFF, opacity: 0.07)
    /// Text drawn on an accent-filled button.
    static let onAccent = Color.adaptive(light: 0xFFFFFF, dark: 0x0E1014)
}

extension Font {
    /// Large figures (weights, reps, timers): semibold with tabular digits so they don't jitter.
    static func numeral(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold).monospacedDigit()
    }
}

/// The screen backdrop: a faint neutral mesh in light mode (so glass has something to refract),
/// and charcoal with a soft blue glow at the top in dark mode.
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .dark {
            ZStack {
                Color.hex(0x0E1014)
                RadialGradient(
                    colors: [Color.hex(0x1A2040, opacity: 0.7), .clear],
                    center: .top, startRadius: 0, endRadius: 520
                )
            }
        } else {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.6, 0.45], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: [
                    .hex(0xF1F2F5), .hex(0xECEEF3), .hex(0xF6F5F2),
                    .hex(0xE9ECF2), .hex(0xF8F8F6), .hex(0xECEEF4),
                    .hex(0xF0F2F5), .hex(0xE8EBF1), .hex(0xF4F3F0),
                ]
            )
        }
    }
}

/// Card container: Liquid Glass in light mode, a bordered charcoal card in dark mode.
private struct AppCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let padding: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        let padded = content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
        if colorScheme == .dark {
            padded
                .background(Theme.cardFill, in: .rect(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.cardBorder, lineWidth: 1))
        } else {
            padded
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
        }
    }
}

/// A soft glow behind accent elements, used in dark mode only.
private struct AccentGlowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var color: Color = .accentColor

    func body(content: Content) -> some View {
        content.shadow(color: colorScheme == .dark ? color.opacity(0.55) : .clear, radius: 8)
    }
}

extension View {
    func appCard(padding: CGFloat = 16) -> some View {
        modifier(AppCardModifier(padding: padding))
    }

    func accentGlow(_ color: Color = .accentColor) -> some View {
        modifier(AccentGlowModifier(color: color))
    }

    /// Hides the default list/form background so the app backdrop shows through.
    func themedBackground() -> some View {
        scrollContentBackground(.hidden)
            .background { AppBackground().ignoresSafeArea() }
    }

    /// Row background that matches the theme when a list sits on the app backdrop.
    func themedRow() -> some View {
        listRowBackground(Theme.rowFill)
    }
}

/// Small capsule buttons, e.g. "+ 5", "+15s".
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium).monospacedDigit())
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Theme.track, in: .capsule)
            .contentShape(.capsule)
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

/// Full-width accent capsule for the main action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(isEnabled ? Color.accentColor : Theme.secondary.opacity(0.4), in: .capsule)
            .contentShape(.capsule)
            .accentGlow()
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// A thin progress ring.
struct ProgressRing: View {
    let progress: Double
    var color: Color = .accentColor
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .accentGlow(color)
        }
    }
}
