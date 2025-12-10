//
//  LockScreenPanelManager.swift
//  DynamicIsland
//
//  Manages the lock screen music panel window.
//

import SwiftUI
import AppKit
import SkyLightWindow
import Defaults
import QuartzCore

@MainActor
final class LockScreenPanelAnimator: ObservableObject {
    @Published var isPresented: Bool = false
}

@MainActor
class LockScreenPanelManager {
    static let shared = LockScreenPanelManager()

    private var panelWindow: NSWindow?
    private var hasDelegated = false
    private var collapsedFrame: NSRect?
    private var isPanelExpanded = false
    private var currentAdditionalHeight: CGFloat = 0
    private let collapsedPanelCornerRadius: CGFloat = 28
    private let expandedPanelCornerRadius: CGFloat = 52
    private(set) var latestFrame: NSRect?
    private let panelAnimator = LockScreenPanelAnimator()
    private var hideTask: Task<Void, Never>?
    private var screenChangeObserver: NSObjectProtocol?
    private var workspaceObservers: [NSObjectProtocol] = []

    private init() {
        print("[\(timestamp())] LockScreenPanelManager: initialized")
        registerScreenChangeObservers()
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }

    private func registerScreenChangeObservers() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenGeometryChange(reason: "screen-parameters")
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let wakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenGeometryChange(reason: "screens-did-wake")
        }

        workspaceObservers = [wakeObserver]
    }

    func showPanel() {
        print("[\(timestamp())] LockScreenPanelManager: showPanel")

        guard Defaults[.enableLockScreenMediaWidget] else {
            print("[\(timestamp())] LockScreenPanelManager: widget disabled")
            hidePanel()
            return
        }

        guard let screen = NSScreen.main else {
            print("[\(timestamp())] LockScreenPanelManager: no main screen available")
            return
        }

        let screenFrame = screen.frame
        let targetFrame = collapsedFrame(for: screenFrame)
        collapsedFrame = targetFrame
        isPanelExpanded = false
        currentAdditionalHeight = 0

        let window: NSWindow

        if let existingWindow = panelWindow {
            window = existingWindow
        } else {
            let newWindow = NSWindow(
                contentRect: targetFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )

            newWindow.isReleasedWhenClosed = false
            newWindow.isOpaque = false
            newWindow.backgroundColor = .clear
            newWindow.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            newWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            newWindow.isMovable = false
            newWindow.hasShadow = false

            ScreenCaptureVisibilityManager.shared.register(newWindow, scope: .entireInterface)

            panelWindow = newWindow
            window = newWindow
            hasDelegated = false
        }

        window.setFrame(targetFrame, display: true)
        latestFrame = targetFrame
        hideTask?.cancel()
        panelAnimator.isPresented = false
        LockScreenTimerWidgetManager.shared.notifyMusicPanelFrameChanged(animated: false)

        let hosting = NSHostingView(rootView: LockScreenMusicPanel(animator: panelAnimator))
        hosting.frame = NSRect(origin: .zero, size: targetFrame.size)
        window.contentView = hosting

        // Ensure the underlying window content is clipped to rounded corners
        if let content = window.contentView {
            content.wantsLayer = true
            content.layer?.masksToBounds = true
            content.layer?.cornerRadius = collapsedPanelCornerRadius
        }

        if !hasDelegated {
            SkyLightOperator.shared.delegateWindow(window)
            hasDelegated = true
        }

        // Keep the window alive and simply order it out on unlock to avoid SkyLight crashes.
        window.orderFrontRegardless()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.panelAnimator.isPresented = true
        }

        print("[\(timestamp())] LockScreenPanelManager: panel visible")
    }

    func updatePanelSize(expanded: Bool, additionalHeight: CGFloat = 0, animated: Bool = true) {
        guard let window = panelWindow, let baseFrame = collapsedFrame else {
            return
        }

        let baseSize = expanded ? LockScreenMusicPanel.expandedSize : LockScreenMusicPanel.collapsedSize
        let targetWidth = baseSize.width
        let targetHeight = baseSize.height + additionalHeight
        let originX = baseFrame.midX - (targetWidth / 2)
        let originY = baseFrame.origin.y
        let targetFrame = NSRect(x: originX, y: originY, width: targetWidth, height: targetHeight)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.45
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(targetFrame, display: true)
            }
        } else {
            window.setFrame(targetFrame, display: true)
        }

        latestFrame = targetFrame

        LockScreenTimerWidgetManager.shared.notifyMusicPanelFrameChanged(animated: animated)

        // Update corner radius to match the SwiftUI panel's style
        let targetRadius = expanded ? expandedPanelCornerRadius : collapsedPanelCornerRadius
        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.28)
            window.contentView?.layer?.cornerRadius = targetRadius
            CATransaction.commit()
        } else {
            window.contentView?.layer?.cornerRadius = targetRadius
        }

        isPanelExpanded = expanded
        currentAdditionalHeight = additionalHeight
    }

    func applyOffsetAdjustment(animated: Bool = true) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let newCollapsed = collapsedFrame(for: screenFrame)
        collapsedFrame = newCollapsed

        guard panelWindow != nil else { return }
        updatePanelSize(expanded: isPanelExpanded, additionalHeight: currentAdditionalHeight, animated: animated)
        LockScreenTimerWidgetManager.shared.notifyMusicPanelFrameChanged(animated: animated)
    }

    func hidePanel() {
        print("[\(timestamp())] LockScreenPanelManager: hidePanel")

        panelAnimator.isPresented = false
        hideTask?.cancel()

        guard let window = panelWindow else {
            print("LockScreenPanelManager: no panel to hide")
            latestFrame = nil
            return
        }

        hideTask = Task { [weak self, weak window] in
            try? await Task.sleep(for: .milliseconds(360))
            guard let self else { return }
            await MainActor.run {
                window?.orderOut(nil)
                window?.contentView = nil
                self.latestFrame = nil
                print("[\(self.timestamp())] LockScreenPanelManager: panel hidden")
            }
        }
    }

    private func handleScreenGeometryChange(reason: String) {
        guard let window = panelWindow else { return }
        guard window.isVisible || panelAnimator.isPresented else { return }
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.frame
        collapsedFrame = collapsedFrame(for: screenFrame)
        updatePanelSize(expanded: isPanelExpanded, additionalHeight: currentAdditionalHeight, animated: false)
        LockScreenTimerWidgetManager.shared.notifyMusicPanelFrameChanged(animated: false)

        print("[\(timestamp())] LockScreenPanelManager: realigned window due to \(reason)")
    }

    private func collapsedFrame(for screenFrame: NSRect) -> NSRect {
        let collapsedSize = LockScreenMusicPanel.collapsedSize
        let originX = screenFrame.midX - (collapsedSize.width / 2)
        let baseOriginY = screenFrame.origin.y + (screenFrame.height / 2) - collapsedSize.height - 32
        let defaultLowering: CGFloat = -28
        let userOffset = CGFloat(Defaults[.lockScreenMusicVerticalOffset])
        let clampedOffset = min(max(userOffset, -160), 160)
        let originY = baseOriginY + defaultLowering + clampedOffset
        return NSRect(x: originX, y: originY, width: collapsedSize.width, height: collapsedSize.height)
    }
}
