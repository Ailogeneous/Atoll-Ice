//
//  LockScreenLiveActivityWindowManager.swift
//  DynamicIsland
//
//  Delegates the lock screen live activity layout to SkyLight so it remains visible when the display is locked.
//

import AppKit
import Defaults
import SkyLightWindow
import SwiftUI
import QuartzCore

@MainActor
class LockScreenLiveActivityWindowManager {
    static let shared = LockScreenLiveActivityWindowManager()

    private var window: NSWindow?
    private var hasDelegated = false
    private var hideTask: Task<Void, Never>?
    private var hostingView: NSHostingView<LockScreenLiveActivityOverlay>?
    private let overlayModel = LockScreenLiveActivityOverlayModel()
    private let overlayAnimator = LockIconAnimator(initiallyLocked: LockScreenManager.shared.isLocked)
    private weak var viewModel: DynamicIslandViewModel?

    private init() {}

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }

    private func windowSize(for notchSize: CGSize) -> CGSize {
        let indicatorWidth = max(0, notchSize.height - 12)
        let horizontalPadding = cornerRadiusInsets.closed.bottom

        let totalWidth = notchSize.width + (indicatorWidth * 2) + (horizontalPadding * 2)

        return CGSize(width: totalWidth, height: notchSize.height)
    }

    private func frame(for windowSize: CGSize, on screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        let originX = screenFrame.origin.x + (screenFrame.width / 2) - (windowSize.width / 2)
        let originY = screenFrame.origin.y + screenFrame.height - windowSize.height

        return NSRect(x: originX, y: originY, width: windowSize.width, height: windowSize.height)
    }

    private func ensureWindow(windowSize: CGSize, screen: NSScreen) -> NSWindow {
        if let window {
            return window
        }

        let window = NSWindow(
            contentRect: frame(for: windowSize, on: screen),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.alphaValue = 0
        window.animationBehavior = .none

        ScreenCaptureVisibilityManager.shared.register(window, scope: .entireInterface)

        self.window = window
        self.hasDelegated = false
        return window
    }

    private func lockContext() -> (notchSize: CGSize, screen: NSScreen)? {
        guard let screen = NSScreen.main else {
            print("[\(timestamp())] LockScreenLiveActivityWindowManager: no main screen available")
            return nil
        }

        guard let viewModel else {
            print("[\(timestamp())] LockScreenLiveActivityWindowManager: no view model configured")
            return nil
        }

        var notchSize = viewModel.closedNotchSize
        if notchSize.width <= 0 || notchSize.height <= 0 {
            notchSize = getClosedNotchSize(screen: screen.localizedName)
        }

        return (notchSize, screen)
    }

    private func present(notchSize: CGSize, on screen: NSScreen) {
        guard Defaults[.enableLockScreenLiveActivity] else {
            hideImmediately()
            return
        }

        let windowSize = windowSize(for: notchSize)
        let window = ensureWindow(windowSize: windowSize, screen: screen)
        let targetFrame = frame(for: windowSize, on: screen)
        window.setFrame(targetFrame, display: true)

        let overlayView = LockScreenLiveActivityOverlay(model: overlayModel, animator: overlayAnimator, notchSize: notchSize)

        if let hostingView {
            hostingView.rootView = overlayView
            hostingView.frame = CGRect(origin: .zero, size: targetFrame.size)
        } else {
            let view = NSHostingView(rootView: overlayView)
            view.frame = CGRect(origin: .zero, size: targetFrame.size)
            hostingView = view
            window.contentView = view
        }

        if window.contentView !== hostingView {
            window.contentView = hostingView
        }

        window.displayIfNeeded()

        if !hasDelegated {
            SkyLightOperator.shared.delegateWindow(window)
            hasDelegated = true
        }

        window.orderFrontRegardless()
        window.alphaValue = 1
    }

    func showLocked() {
        hideTask?.cancel()
        guard let context = lockContext() else { return }

        overlayAnimator.update(isLocked: true)
        overlayModel.scale = 0.6
        overlayModel.opacity = 0

        present(notchSize: context.notchSize, on: context.screen)

        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                self.overlayModel.scale = 1
            }
            withAnimation(.easeOut(duration: 0.18)) {
                self.overlayModel.opacity = 1
            }
        }

        print("[\(timestamp())] LockScreenLiveActivityWindowManager: showing locked state")
    }

    func showUnlockAndScheduleHide() {
        hideTask?.cancel()
        guard let context = lockContext() else { return }

        overlayModel.scale = 1
        overlayModel.opacity = 1

        present(notchSize: context.notchSize, on: context.screen)

        overlayAnimator.update(isLocked: false)

        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(LockScreenAnimationTimings.unlockCollapse))
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                self.hideWithAnimation()
            }
        }
    }

    func hideImmediately() {
        hideTask?.cancel()
        hideTask = nil

        hideWithAnimation()
    }

    private func hideWithAnimation() {
        guard let window else { return }

        withAnimation(.smooth(duration: LockScreenAnimationTimings.unlockCollapse)) {
            overlayModel.opacity = 0
            overlayModel.scale = 0.7
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = LockScreenAnimationTimings.unlockCollapse
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + LockScreenAnimationTimings.unlockCollapse + 0.02) {
            window.orderOut(nil)
        }

        print("[\(timestamp())] LockScreenLiveActivityWindowManager: HUD hidden")
    }

    func configure(viewModel: DynamicIslandViewModel) {
        self.viewModel = viewModel
    }
}
