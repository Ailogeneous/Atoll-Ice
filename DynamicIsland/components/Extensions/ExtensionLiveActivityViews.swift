import SwiftUI
import Defaults
import AtollExtensionKit

struct ExtensionStandaloneLayout {
    let totalWidth: CGFloat
    let outerHeight: CGFloat
    let contentHeight: CGFloat
    let leadingWidth: CGFloat
    let centerWidth: CGFloat
    let trailingWidth: CGFloat
}

struct ExtensionLiveActivityStandaloneView: View {
    let payload: ExtensionLiveActivityPayload
    let layout: ExtensionStandaloneLayout
    let isHovering: Bool

    private var descriptor: AtollLiveActivityDescriptor { payload.descriptor }
    private var contentHeight: CGFloat { layout.contentHeight }
    private var accentColor: Color { descriptor.accentColor.swiftUIColor }
    private var resolvedLeadingContent: AtollTrailingContent {
        descriptor.leadingContent ?? .icon(descriptor.leadingIcon)
    }
    private var resolvedCenterStyle: ExtensionCenterContentView.Style {
        switch descriptor.centerTextStyle {
        case .inline:
            return .inline
        case .standard:
            return .stacked
        case .inheritUser:
            return Defaults[.sneakPeekStyles] == .inline ? .inline : .stacked
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ExtensionLeadingContentView(
                content: resolvedLeadingContent,
                badge: descriptor.badgeIcon,
                accent: accentColor,
                frameWidth: layout.leadingWidth,
                frameHeight: contentHeight
            )
            .frame(width: layout.leadingWidth, height: contentHeight)

            Rectangle()
                .fill(Color.black)
                .frame(width: layout.centerWidth, height: contentHeight)
                .overlay(
                    ExtensionCenterContentView(
                        descriptor: descriptor,
                        accent: accentColor,
                        width: layout.centerWidth,
                        style: resolvedCenterStyle
                    )
                )

            ExtensionMusicWingView(
                payload: payload,
                notchHeight: contentHeight,
                trailingWidth: layout.trailingWidth
            )
                .frame(width: layout.trailingWidth, height: contentHeight)
        }
        .frame(width: layout.totalWidth, height: layout.outerHeight + (isHovering ? 8 : 0))
        .animation(.smooth(duration: 0.25), value: payload.id)
        .onAppear {
            logExtensionDiagnostics("Displaying extension live activity \(payload.descriptor.id) for \(payload.bundleIdentifier) as standalone view")
        }
        .onDisappear {
            logExtensionDiagnostics("Hid extension live activity \(payload.descriptor.id) standalone view")
        }
    }

}

struct ExtensionMusicWingView: View {
    let payload: ExtensionLiveActivityPayload
    let notchHeight: CGFloat
    let trailingWidth: CGFloat

    private var descriptor: AtollLiveActivityDescriptor { payload.descriptor }
    private var accentColor: Color { descriptor.accentColor.swiftUIColor }

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if case .none = descriptor.trailingContent {
                EmptyView()
            } else {
                ExtensionEdgeContentView(
                    content: descriptor.trailingContent,
                    accent: accentColor,
                    availableWidth: trailingWidth,
                    alignment: .trailing
                )
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let indicator = descriptor.progressIndicator, indicator != .none {
                ExtensionProgressIndicatorView(
                    indicator: indicator,
                    progress: descriptor.progress,
                    accent: accentColor,
                    estimatedDuration: descriptor.estimatedDuration
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .onAppear {
            logExtensionDiagnostics("Displaying extension live activity \(payload.descriptor.id) within music wing")
        }
        .onDisappear {
            logExtensionDiagnostics("Hid extension live activity \(payload.descriptor.id) from music wing")
        }
    }
}

struct ExtensionLeadingContentView: View {
    let content: AtollTrailingContent
    let badge: AtollIconDescriptor?
    let accent: Color
    let frameWidth: CGFloat
    let frameHeight: CGFloat

    var body: some View {
        if case let .icon(iconDescriptor) = content {
            ExtensionCompositeIconView(
                leading: iconDescriptor,
                badge: badge,
                accent: accent,
                size: frameHeight
            )
        } else {
            ExtensionEdgeContentView(
                content: content,
                accent: accent,
                availableWidth: frameWidth,
                alignment: .leading
            )
        }
    }
}

struct ExtensionCenterContentView: View {
    enum Style {
        case stacked
        case inline
    }

    let descriptor: AtollLiveActivityDescriptor
    let accent: Color
    let width: CGFloat
    let style: Style

    var body: some View {
        switch style {
        case .stacked:
            VStack(alignment: .leading, spacing: 2) {
                Text(descriptor.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let subtitle = descriptor.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .inline:
            HStack(alignment: .center, spacing: 8) {
                MarqueeText(
                    .constant(descriptor.title),
                    font: .system(size: 13, weight: .semibold),
                    nsFont: .body,
                    textColor: .white,
                    minDuration: 0.4,
                    frameWidth: max(40, width * 0.55)
                )
                Spacer(minLength: 4)
                if let subtitle = descriptor.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

private func logExtensionDiagnostics(_ message: String) {
    guard Defaults[.extensionDiagnosticsLoggingEnabled] else { return }
    Logger.log(message, category: .extensions)
}
