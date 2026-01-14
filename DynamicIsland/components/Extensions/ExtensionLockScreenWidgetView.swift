import SwiftUI
import Defaults
import AtollExtensionKit

struct ExtensionLockScreenWidgetView: View {
    let payload: ExtensionLockScreenWidgetPayload

    private var descriptor: AtollLockScreenWidgetDescriptor { payload.descriptor }
    private var accentColor: Color { descriptor.accentColor.swiftUIColor }

    var body: some View {
        ZStack {
            backgroundView
            contentView
                .padding(.horizontal, descriptor.layoutStyle == .circular ? 10 : 16)
                .padding(.vertical, descriptor.layoutStyle == .circular ? 10 : 12)
        }
        .frame(width: descriptor.size.width, height: descriptor.size.height)
        .clipShape(RoundedRectangle(cornerRadius: descriptor.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: descriptor.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
        .onAppear {
            logWidgetDiagnostics("Rendering extension lock screen widget \(payload.descriptor.id) for \(payload.bundleIdentifier)")
        }
        .onDisappear {
            logWidgetDiagnostics("Lock screen widget \(payload.descriptor.id) removed")
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch descriptor.layoutStyle {
        case .inline, .card, .custom:
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(descriptor.content.enumerated()), id: \.offset) { index, element in
                    view(for: element)
                        .frame(maxWidth: .infinity, alignment: alignment(for: element))
                        .accessibilityIdentifier("extension-widget-element-\(payload.id)-\(index)")
                }
            }
        case .circular:
            ZStack {
                ForEach(Array(descriptor.content.enumerated()), id: \.offset) { index, element in
                    view(for: element)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .accessibilityIdentifier("extension-widget-element-\(payload.id)-\(index)")
                }
            }
        }
    }

    @ViewBuilder
    private func view(for element: AtollWidgetContentElement) -> some View {
        switch element {
        case let .text(text, font: font, color: color, alignment: _):
            Text(text)
                .font(font.swiftUIFont())
                .foregroundStyle((color?.swiftUIColor) ?? Color.white.opacity(0.9))
                .lineLimit(2)
        case let .icon(iconDescriptor, tint):
            ExtensionIconView(
                descriptor: iconDescriptor,
                tint: (tint?.swiftUIColor) ?? accentColor,
                size: CGSize(width: 28, height: 28),
                cornerRadius: 8
            )
        case let .progress(indicator, value, color):
            ExtensionProgressIndicatorView(
                indicator: indicator,
                progress: value,
                accent: (color?.swiftUIColor) ?? accentColor,
                estimatedDuration: nil
            )
        case let .graph(data, color, size):
            ExtensionGraphView(data: data, color: color.swiftUIColor, size: size)
                .frame(width: size.width, height: size.height)
        case let .gauge(value, minValue, maxValue, style, color):
            ExtensionGaugeView(
                value: value,
                minValue: minValue,
                maxValue: maxValue,
                style: style,
                accent: (color?.swiftUIColor) ?? accentColor
            )
                .frame(maxWidth: .infinity)
        case let .spacer(height):
            Color.clear
                .frame(height: height)
        case let .divider(color, thickness):
            Rectangle()
                .fill(color.swiftUIColor.opacity(0.4))
                .frame(height: thickness)
        }
    }

    private func alignment(for element: AtollWidgetContentElement) -> Alignment {
        switch element {
        case let .text(_, _, _, alignment):
            return alignment.swiftUI
        default:
            return .leading
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch descriptor.material {
        case .frosted:
            RoundedRectangle(cornerRadius: descriptor.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        case .liquid:
            RoundedRectangle(cornerRadius: descriptor.cornerRadius, style: .continuous)
                .fill(.regularMaterial)
        case .solid:
            RoundedRectangle(cornerRadius: descriptor.cornerRadius, style: .continuous)
                .fill(accentColor.opacity(0.9))
        case .semiTransparent:
            RoundedRectangle(cornerRadius: descriptor.cornerRadius, style: .continuous)
                .fill(accentColor.opacity(0.35))
        case .clear:
            Color.clear
        }
    }
}

private func logWidgetDiagnostics(_ message: String) {
    guard Defaults[.extensionDiagnosticsLoggingEnabled] else { return }
    Logger.log(message, category: .extensions)
}

private struct ExtensionGraphView: View {
    let data: [Double]
    let color: Color
    let size: CGSize

    var body: some View {
        GeometryReader { proxy in
            let minValue = data.min() ?? 0
            let maxValue = data.max() ?? 1
            let range = max(maxValue - minValue, 0.0001)
            let step = proxy.size.width / CGFloat(max(data.count - 1, 1))
            Path { path in
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * step
                    let normalized = (value - minValue) / range
                    let y = proxy.size.height - (CGFloat(normalized) * proxy.size.height)
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct ExtensionGaugeView: View {
    let value: Double
    let minValue: Double
    let maxValue: Double
    let style: AtollWidgetContentElement.GaugeStyle
    let accent: Color

    var body: some View {
        switch style {
        case .circular:
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(normalizedValue))
                    .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.3), value: normalizedValue)
                Text("\(Int(normalizedValue * 100))%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(width: 54, height: 54)
        case .linear:
            GeometryReader { proxy in
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(accent)
                            .frame(width: proxy.size.width * CGFloat(normalizedValue), height: 8)
                            .animation(.smooth(duration: 0.3), value: normalizedValue)
                    }
            }
            .frame(height: 8)
        }
    }

    private var normalizedValue: Double {
        guard maxValue > minValue else { return 0 }
        return min(max((value - minValue) / (maxValue - minValue), 0), 1)
    }
}

private extension AtollWidgetContentElement.TextAlignment {
    var swiftUI: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}
