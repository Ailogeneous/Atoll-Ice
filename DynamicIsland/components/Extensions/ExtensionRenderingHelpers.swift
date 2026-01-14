import SwiftUI
import AppKit
import AtollExtensionKit

// MARK: - Color Conversion

extension AtollColorDescriptor {
    var swiftUIColor: Color {
        if isAccent {
            return .accentColor
        }
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    var nsColor: NSColor {
        if isAccent {
            return NSColor.controlAccentColor
        }
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

// MARK: - Font Conversion

extension AtollFontDescriptor {
    func swiftUIFont() -> Font {
        let design = self.design.swiftUI
        let weight = self.weight.swiftUI
        var font = Font.system(size: size, weight: weight, design: design)
        if isMonospacedDigit {
            font = font.monospacedDigit()
        }
        return font
    }

    func nsFont() -> NSFont {
        let weight = weight.nsFont
        let font: NSFont
        switch design {
        case .serif:
            font = NSFont.userFont(ofSize: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
        case .rounded:
            if let descriptor = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.rounded) {
                font = NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
            } else {
                font = NSFont.systemFont(ofSize: size, weight: weight)
            }
        case .monospaced:
            font = NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .default:
            font = NSFont.systemFont(ofSize: size, weight: weight)
        }
        return font
    }
}

private extension AtollFontWeight {
    var swiftUI: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }

    var nsFont: NSFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}

private extension AtollFontDesign {
    var swiftUI: Font.Design {
        switch self {
        case .default: return .default
        case .serif: return .serif
        case .rounded: return .rounded
        case .monospaced: return .monospaced
        }
    }
}

// MARK: - Icon Rendering

struct ExtensionIconView: View {
    let descriptor: AtollIconDescriptor
    let tint: Color
    let size: CGSize
    let cornerRadius: CGFloat

    var body: some View {
        switch descriptor {
        case let .symbol(name, glyphSize, weight):
            Image(systemName: name)
                .font(.system(size: glyphSize, weight: weight.swiftUI))
                .foregroundStyle(tint)
                .frame(width: size.width, height: size.height)
        case let .image(data, targetSize, radius):
            if let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: targetSize.width, height: targetSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            } else {
                fallbackSymbol
            }
        case let .appIcon(bundleIdentifier, targetSize, radius):
            if let icon = AppIconAsNSImage(for: bundleIdentifier) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: targetSize.width, height: targetSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            } else {
                fallbackSymbol
            }
        case .lottie, .none:
            fallbackSymbol
        }
    }

    private var fallbackSymbol: some View {
        Image(systemName: "app.dashed")
            .font(.system(size: size.width * 0.6, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size.width, height: size.height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius(for: descriptor), style: .continuous)
                    .fill(tint.opacity(0.15))
            )
    }

    private func cornerRadius(for descriptor: AtollIconDescriptor) -> CGFloat {
        switch descriptor {
        case .image(_, _, let radius): return radius
        case .appIcon(_, _, let radius): return radius
        default: return cornerRadius
        }
    }
}

struct ExtensionCompositeIconView: View {
    let leading: AtollIconDescriptor
    let badge: AtollIconDescriptor?
    let accent: Color
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ExtensionIconView(
                descriptor: leading,
                tint: accent,
                size: CGSize(width: size, height: size),
                cornerRadius: size * 0.18
            )
            if let badge {
                ExtensionIconView(
                    descriptor: badge,
                    tint: .white,
                    size: CGSize(width: max(size * 0.35, 12), height: max(size * 0.35, 12)),
                    cornerRadius: size * 0.12
                )
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: size * 0.4, height: size * 0.4)
                )
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Progress Rendering

struct ExtensionProgressIndicatorView: View {
    let indicator: AtollProgressIndicator
    let progress: Double
    let accent: Color
    let estimatedDuration: TimeInterval?

    var body: some View {
        switch indicator {
        case let .ring(diameter, strokeWidth):
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: strokeWidth)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(progress, 1))))
                    .stroke(accent, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.25), value: progress)
            }
            .frame(width: diameter, height: diameter)
        case let .bar(width, height, cornerRadius):
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: width ?? 80, height: height)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(accent)
                        .frame(width: (width ?? 80) * CGFloat(max(0, min(progress, 1))), height: height)
                        .animation(.smooth(duration: 0.25), value: progress)
                }
        case let .percentage(font):
            Text("\(Int(progress * 100))%")
                .font(font.swiftUIFont())
                .foregroundStyle(accent)
                .monospacedDigit()
        case let .countdown(font):
            Text(countdownText)
                .font(font.swiftUIFont())
                .foregroundStyle(accent)
                .monospacedDigit()
        case .lottie:
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(accent)
        case .none:
            EmptyView()
        }
    }

    private var countdownText: String {
        guard let estimatedDuration else { return formatPercent }
        let remaining = max(estimatedDuration * (1 - progress), 0)
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var formatPercent: String {
        "\(Int(progress * 100))%"
    }
}

// MARK: - Edge Content Rendering

struct ExtensionEdgeContentView: View {
    let content: AtollTrailingContent
    let accent: Color
    let availableWidth: CGFloat
    let alignment: Alignment

    var body: some View {
        switch content {
        case let .text(value, font: font):
            Text(value)
                .font(font.swiftUIFont())
                .foregroundStyle(accent)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: alignment)
        case let .marquee(value, font: font, minDuration: duration):
            MarqueeText(
                .constant(value),
                font: font.swiftUIFont(),
                nsFont: .body,
                textColor: accent,
                minDuration: duration,
                frameWidth: max(24, availableWidth - 12)
            )
        case let .countdownText(targetDate, font: font):
            ExtensionCountdownTextView(targetDate: targetDate, font: font, accent: accent)
                .frame(maxWidth: .infinity, alignment: alignment)
        case let .icon(descriptor):
            ExtensionIconView(
                descriptor: descriptor,
                tint: accent,
                size: CGSize(width: 26, height: 26),
                cornerRadius: 6
            )
        case let .spectrum(color: colorDescriptor):
            Rectangle()
                .fill((colorDescriptor.isAccent ? accent : colorDescriptor.swiftUIColor).gradient)
                .frame(width: 48, height: 14)
                .mask {
                    AudioSpectrumView(isPlaying: .constant(true))
                        .frame(width: 16, height: 12)
                }
        case .animation:
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(accent)
        case .none:
            EmptyView()
        }
    }
}

struct ExtensionCountdownTextView: View {
    let targetDate: Date
    let font: AtollFontDescriptor
    let accent: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(formattedRemaining(since: context.date))
                .font(font.swiftUIFont())
                .foregroundStyle(accent)
                .monospacedDigit()
        }
    }

    private func formattedRemaining(since date: Date) -> String {
        let remaining = max(Int(targetDate.timeIntervalSince(date)), 0)
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Layout Metrics

enum ExtensionLayoutMetrics {
    static func trailingWidth(for payload: ExtensionLiveActivityPayload, baseWidth: CGFloat, maxWidth: CGFloat? = nil) -> CGFloat {
        var width = edgeWidth(for: payload.descriptor.trailingContent, baseWidth: baseWidth, maxWidth: maxWidth)
        if let indicator = payload.descriptor.progressIndicator {
            width = max(width, widthForProgress(indicator))
        }
        if let maxWidth {
            width = min(width, maxWidth)
        }
        return width
    }

    static func edgeWidth(for content: AtollTrailingContent, baseWidth: CGFloat, maxWidth: CGFloat? = nil) -> CGFloat {
        var width = widthForContent(content, baseWidth: baseWidth)
        if let maxWidth {
            width = min(width, maxWidth)
        }
        return width
    }

    private static func widthForContent(_ content: AtollTrailingContent, baseWidth: CGFloat) -> CGFloat {
        switch content {
        case let .text(text, font: font):
            let measured = ExtensionTextMeasurer.width(for: text, font: font.nsFont())
            return max(baseWidth, measured + 32)
        case let .marquee(text, font: font, _):
            let measured = ExtensionTextMeasurer.width(for: text, font: font.nsFont())
            return max(baseWidth, min(measured + 40, baseWidth * 2))
        case let .countdownText(targetDate, font: font):
            let sample = targetDate.timeIntervalSinceNow >= 3600 ? "00:00:00" : "00:00"
            let measured = ExtensionTextMeasurer.width(for: sample, font: font.nsFont())
            return max(baseWidth, measured + 24)
        case .icon:
            return max(baseWidth, 52)
        case .spectrum:
            return max(baseWidth, 56)
        case let .animation(data: _, size: size):
            return max(baseWidth, size.width + 16)
        case .none:
            return baseWidth
        }
    }

    private static func widthForProgress(_ indicator: AtollProgressIndicator) -> CGFloat {
        switch indicator {
        case let .ring(diameter, _):
            return diameter + 20
        case let .bar(width, _, _):
            return (width ?? 72) + 12
        case .percentage:
            return 60
        case .countdown:
            return 74
        case let .lottie(_, size):
            return size.width + 16
        case .none:
            return 0
        }
    }
}

enum ExtensionTextMeasurer {
    static func width(for text: String, font: NSFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return max(1, text.size(withAttributes: attributes).width)
    }
}
