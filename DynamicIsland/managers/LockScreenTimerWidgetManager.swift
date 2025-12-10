import Foundation
import Combine
import Defaults
import SwiftUI
import AppKit
import SkyLightWindow
import QuartzCore

@MainActor
final class LockScreenTimerWidgetAnimator: ObservableObject {
    @Published var isPresented: Bool

    init(isPresented: Bool = false) {
        self.isPresented = isPresented
    }
}

@MainActor
final class LockScreenTimerWidgetManager {
    static let shared = LockScreenTimerWidgetManager()

    private let timerManager = TimerManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var isLocked: Bool = false

    private init() {
        observeTimerState()
        observeDefaults()
    }

    func handleLockStateChange(isLocked: Bool) {
        self.isLocked = isLocked
        if isLocked {
            updateVisibility()
        } else {
            LockScreenTimerWidgetPanelManager.shared.hide()
        }
    }

    func refreshPositionForOffsets(animated: Bool) {
        LockScreenTimerWidgetPanelManager.shared.refreshPosition(animated: animated)
    }

    func notifyMusicPanelFrameChanged(animated: Bool) {
        LockScreenTimerWidgetPanelManager.shared.refreshRelativeToMusicPanel(animated: animated)
    }

    private func observeTimerState() {
        timerManager.$isTimerActive
            .combineLatest(timerManager.$activeSource)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateVisibility()
            }
            .store(in: &cancellables)
    }

    private func observeDefaults() {
        Defaults.publisher(.enableLockScreenTimerWidget, options: [])
            .receive(on: RunLoop.main)
            .sink { [weak self] change in
                guard let self else { return }
                if change.newValue {
                    self.updateVisibility()
                } else {
                    LockScreenTimerWidgetPanelManager.shared.hide()
                }
            }
            .store(in: &cancellables)

        Defaults.publisher(.lockScreenTimerVerticalOffset, options: [])
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshPositionForOffsets(animated: true)
            }
            .store(in: &cancellables)
    }

    private func updateVisibility() {
        guard shouldDisplayWidget() else {
            LockScreenTimerWidgetPanelManager.shared.hide()
            return
        }
        LockScreenTimerWidgetPanelManager.shared.showWidget()
    }

    private func shouldDisplayWidget() -> Bool {
        guard Defaults[.enableLockScreenTimerWidget] else { return false }
        guard isLocked else { return false }
        return timerManager.hasManualTimerRunning
    }
}

@MainActor
final class LockScreenTimerWidgetPanelManager {
    static let shared = LockScreenTimerWidgetPanelManager()
    static let hideAnimationDurationNanoseconds: UInt64 = 360_000_000

    private var window: NSWindow?
    private var hasDelegated = false
    private let animator = LockScreenTimerWidgetAnimator()
    private var hideTask: Task<Void, Never>?
    private(set) var latestFrame: NSRect?
    private var screenChangeObserver: NSObjectProtocol?
    private var workspaceObservers: [NSObjectProtocol] = []

    private init() {
        registerScreenChangeObservers()
    }

    func showWidget() {
        guard let screen = NSScreen.main else { return }
        let window = ensureWindow()
        let frame = targetFrame(on: screen)
        window.setFrame(frame, display: true)
        latestFrame = frame
        window.alphaValue = 1
        window.orderFrontRegardless()
        hideTask?.cancel()
        hideTask = nil
        animator.isPresented = true
        LockScreenReminderWidgetPanelManager.shared.refreshPosition(animated: true)
    }

    func hide(animated: Bool = true) {
        guard let window else { return }
        hideTask?.cancel()
        animator.isPresented = false

        let delay: UInt64 = animated ? Self.hideAnimationDurationNanoseconds : 0
        if delay == 0 {
            window.orderOut(nil)
            hideTask = nil
            latestFrame = nil
            LockScreenReminderWidgetPanelManager.shared.refreshPosition(animated: true)
            return
        }

        hideTask = Task { [weak window, weak self] in
            try? await Task.sleep(nanoseconds: delay)
            await MainActor.run {
                window?.orderOut(nil)
                self?.hideTask = nil
                self?.latestFrame = nil
                LockScreenReminderWidgetPanelManager.shared.refreshPosition(animated: true)
            }
        }
    }


    func refreshPosition(animated: Bool) {
        guard let window, window.isVisible, let screen = NSScreen.main else { return }
        let frame = targetFrame(on: screen)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: true)
        }
        latestFrame = frame
        LockScreenReminderWidgetPanelManager.shared.refreshPosition(animated: animated)
    }

    func refreshRelativeToMusicPanel(animated: Bool) {
        guard window?.isVisible == true else { return }
        refreshPosition(animated: animated)
    }

    private func ensureWindow() -> NSWindow {
        if let window {
            if window.contentView == nil {
                window.contentView = hostingView()
            }
            return window
        }

        let frame = NSRect(origin: .zero, size: LockScreenTimerWidget.preferredSize)
        let newWindow = NSWindow(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        newWindow.isReleasedWhenClosed = false
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear
        newWindow.hasShadow = false
        newWindow.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        newWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        newWindow.ignoresMouseEvents = false
        newWindow.isMovable = false
        newWindow.contentView = hostingView()

        ScreenCaptureVisibilityManager.shared.register(newWindow, scope: .entireInterface)

        window = newWindow

        if !hasDelegated {
            SkyLightOperator.shared.delegateWindow(newWindow)
            hasDelegated = true
        }

        return newWindow
    }

    private func hostingView() -> NSHostingView<LockScreenTimerWidget> {
        let view = LockScreenTimerWidget(animator: animator)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: LockScreenTimerWidget.preferredSize)
        hosting.wantsLayer = true
        hosting.layer?.masksToBounds = true
        hosting.layer?.cornerRadius = LockScreenTimerWidget.cornerRadius
        return hosting
    }

    private func targetFrame(on screen: NSScreen) -> NSRect {
        let size = LockScreenTimerWidget.preferredSize
        let originX = screen.frame.midX - (size.width / 2)
        let defaultLowering: CGFloat = -18
        var baseY = screen.frame.midY + 24 + defaultLowering

        if let musicFrame = LockScreenPanelManager.shared.latestFrame {
            baseY = musicFrame.maxY + 28 + defaultLowering
        }

        let offset = CGFloat(clampedTimerOffset())
        var originY = baseY + offset

        if let musicFrame = LockScreenPanelManager.shared.latestFrame {
            originY = max(originY, musicFrame.maxY + 12)
        }

        if let weatherFrame = LockScreenWeatherPanelManager.shared.latestFrame {
            originY = min(originY, weatherFrame.minY - size.height - 20)
        } else {
            let topLimit = screen.frame.maxY - size.height - 72
            originY = min(originY, topLimit)
        }

        let minY = screen.frame.minY + 100
        originY = max(originY, minY)

        return NSRect(x: originX, y: originY, width: size.width, height: size.height)
    }

    private func clampedTimerOffset() -> Double {
        let raw = Defaults[.lockScreenTimerVerticalOffset]
        return min(max(raw, -160), 160)
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

    private func handleScreenGeometryChange(reason: String) {
        guard window?.isVisible == true else { return }
        refreshPosition(animated: false)
        print("LockScreenTimerWidgetPanelManager: realigned window due to \(reason)")
    }
}
