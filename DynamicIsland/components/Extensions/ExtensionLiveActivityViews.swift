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
    let suppressingCenterText: Bool
}

struct ExtensionLiveActivityStandaloneView: View {
    let payload: ExtensionLiveActivityPayload
    let layout: ExtensionStandaloneLayout
    let isHovering: Bool
    let notchState: NotchState

    private var descriptor: AtollLiveActivityDescriptor { payload.descriptor }
    private var contentHeight: CGFloat { layout.contentHeight }
    private var accentColor: Color { descriptor.accentColor.swiftUIColor }
    private var resolvedLeadingContent: AtollTrailingContent {
        resolvedExtensionLeadingContent(for: descriptor)
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

    private var shouldSuppressCenterText: Bool {
        layout.suppressingCenterText
    }

    var body: some View {
        HStack(spacing: 0) {
            ExtensionLeadingContentView(
                content: resolvedLeadingContent,
                badge: descriptor.badgeIcon,
                accent: accentColor,
                frameWidth: layout.leadingWidth,
                frameHeight: contentHeight,
                defaultIcon: descriptor.leadingIcon
            )
            .frame(width: layout.leadingWidth, height: contentHeight)

            Rectangle()
                .fill(Color.black)
                .frame(width: layout.centerWidth, height: contentHeight)
                .overlay(
                    Group {
                        if !shouldSuppressCenterText {
                            ExtensionCenterContentView(
                                descriptor: descriptor,
                                accent: accentColor,
                                width: layout.centerWidth,
                                style: resolvedCenterStyle
                            )
                        }
                    }
                )

            ExtensionMusicWingView(
                payload: payload,
                notchHeight: contentHeight,
                trailingWidth: layout.trailingWidth
            )
                .frame(width: layout.trailingWidth, height: contentHeight)
        }
        .frame(width: layout.totalWidth, height: layout.outerHeight + (isHovering ? 8 : 0))
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.8)),
            removal: .scale(scale: 0.95).combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.9))
        ))
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
    private var trailingRenderable: ExtensionTrailingRenderable {
        resolvedExtensionTrailingRenderable(for: descriptor)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            switch trailingRenderable {
            case let .content(content):
                if case .none = content {
                    EmptyView()
                } else {
                    ExtensionEdgeContentView(
                        content: content,
                        accent: accentColor,
                        availableWidth: trailingWidth,
                        alignment: .trailing
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            case let .indicator(indicator):
                ExtensionProgressIndicatorView(
                    indicator: indicator,
                    progress: descriptor.progress,
                    accent: accentColor,
                    estimatedDuration: descriptor.estimatedDuration,
                    maxVisualHeight: notchHeight
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            Spacer(minLength: 0)
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
    let defaultIcon: AtollIconDescriptor

    var body: some View {
        Group {
            switch content {
            case let .icon(iconDescriptor):
                ExtensionCompositeIconView(
                    leading: iconDescriptor,
                    badge: badge,
                    accent: accent,
                    size: frameHeight
                )
            case let .animation(data, size):
                let resolvedSize = CGSize(
                    width: min(size.width, frameHeight),
                    height: min(size.height, frameHeight)
                )
                ExtensionLottieView(data: data, size: resolvedSize)
                    .frame(width: frameHeight, height: frameHeight)
                    .background(
                        RoundedRectangle(cornerRadius: frameHeight * 0.18, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            default:
                ExtensionCompositeIconView(
                    leading: defaultIcon,
                    badge: badge,
                    accent: accent,
                    size: frameHeight
                )
            }
        }
        .frame(width: frameWidth, height: frameHeight)
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

struct ExtensionInlineSneakPeekView: View {
    let payload: ExtensionLiveActivityPayload?
    let title: String
    let subtitle: String
    let accentColor: Color
    let notchHeight: CGFloat
    let closedNotchWidth: CGFloat
    let isHovering: Bool
    let gestureProgress: CGFloat

    private var descriptor: AtollLiveActivityDescriptor? { payload?.descriptor }
    private var resolvedAccent: Color { descriptor?.accentColor.swiftUIColor ?? accentColor }

    private var contentHeight: CGFloat {
        max(0, notchHeight - (isHovering ? 0 : 12))
    }

    private var leadingWidth: CGFloat {
        let base = max(contentHeight, 44)
        return max(base * 0.85, base + gestureProgress / 2)
    }

    private var centerWidth: CGFloat {
        max(closedNotchWidth + (isHovering ? 8 : 0), 120)
    }

    private var trailingWidth: CGFloat {
        guard let payload else { return max(leadingWidth, 120) }
        return ExtensionLayoutMetrics.trailingWidth(
            for: payload,
            baseWidth: leadingWidth,
            maxWidth: leadingWidth + centerWidth * 0.6
        )
    }

    private var marqueeFrameWidth: CGFloat {
        max(48, centerWidth - 24)
    }

    private var resolvedTitle: String {
        title.isEmpty ? "Extension" : title
    }

    private var resolvedSubtitle: String {
        subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: 0) {
            leadingWing
                .frame(width: leadingWidth, height: contentHeight)

            Rectangle()
                .fill(Color.black)
                .frame(width: centerWidth, height: contentHeight)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        if !resolvedTitle.isEmpty {
                            MarqueeText(
                                .constant(resolvedTitle),
                                font: .system(size: 12, weight: .semibold),
                                nsFont: .subheadline,
                                textColor: .white,
                                minDuration: 0.4,
                                frameWidth: marqueeFrameWidth
                            )
                        }
                        if !resolvedSubtitle.isEmpty {
                            Text(resolvedSubtitle)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.75))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }

            trailingWing
                .frame(width: trailingWidth, height: contentHeight)
        }
        .frame(height: notchHeight + (isHovering ? 8 : 0), alignment: .center)
    }

    @ViewBuilder
    private var leadingWing: some View {
        if let descriptor {
            ExtensionLeadingContentView(
                content: resolvedExtensionLeadingContent(for: descriptor),
                badge: descriptor.badgeIcon,
                accent: resolvedAccent,
                frameWidth: leadingWidth,
                frameHeight: contentHeight,
                defaultIcon: descriptor.leadingIcon
            )
        } else {
            RoundedRectangle(cornerRadius: contentHeight * 0.25, style: .continuous)
                .fill(resolvedAccent.gradient)
        }
    }

    @ViewBuilder
    private var trailingWing: some View {
        if let payload {
            let descriptor = payload.descriptor
            switch resolvedExtensionTrailingRenderable(for: descriptor) {
            case let .content(content):
                if case .none = content {
                    spectrumPlaceholder
                } else {
                    VStack(alignment: .trailing, spacing: 6) {
                        ExtensionEdgeContentView(
                            content: content,
                            accent: resolvedAccent,
                            availableWidth: trailingWidth,
                            alignment: .trailing
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        Spacer(minLength: 0)
                    }
                    .padding(.trailing, 8)
                    .padding(.vertical, 6)
                }
            case .indicator:
                spectrumPlaceholder
            }
        } else {
            spectrumPlaceholder
        }
    }

    @ViewBuilder
    private var spectrumPlaceholder: some View {
        VStack {
            Rectangle()
                .fill(resolvedAccent.gradient)
                .mask {
                    AudioSpectrumView(isPlaying: .constant(true))
                        .frame(width: 18, height: 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
    }
}
