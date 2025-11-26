import AppKit
import SwiftUI
import SkyLightWindow

@MainActor
final class LockScreenReminderWidgetPanelManager {
    static let shared = LockScreenReminderWidgetPanelManager()

    private var window: NSWindow?
    private var hasDelegated = false

    var isVisible: Bool {
        window?.isVisible == true
    }

    private init() {}

    func show(with snapshot: LockScreenReminderWidgetSnapshot) {
        render(snapshot: snapshot, makeVisible: true)
    }

    func update(with snapshot: LockScreenReminderWidgetSnapshot) {
        render(snapshot: snapshot, makeVisible: false)
    }

    func hide() {
        guard let window else { return }
        window.orderOut(nil)
        window.contentView = nil
    }

    private func render(snapshot: LockScreenReminderWidgetSnapshot, makeVisible: Bool) {
        guard let screen = NSScreen.main else { return }
        if !makeVisible, window == nil {
            return
        }

        let view = LockScreenReminderWidget(snapshot: snapshot)
        let hostingView = NSHostingView(rootView: view)
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: fittingSize)

        let window = ensureWindow()
        window.setFrame(frame(for: fittingSize, on: screen), display: true)
        window.contentView = hostingView

        if makeVisible {
            window.orderFrontRegardless()
        }
    }

    private func ensureWindow() -> NSWindow {
        if let window {
            return window
        }

        let frame = NSRect(origin: .zero, size: CGSize(width: 220, height: 48))
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
        newWindow.ignoresMouseEvents = true
        newWindow.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        newWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        ScreenCaptureVisibilityManager.shared.register(newWindow, scope: .entireInterface)

        window = newWindow
        if !hasDelegated {
            SkyLightOperator.shared.delegateWindow(newWindow)
            hasDelegated = true
        }
        return newWindow
    }

    private func frame(for size: CGSize, on screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        let originX = screenFrame.midX - (size.width / 2)
        let musicTop = LockScreenPanelManager.shared.latestFrame?.maxY ?? (screenFrame.midY - 32)

        let defaultWeatherBottom = screenFrame.midY + (screenFrame.height * 0.14)
        let weatherBottom = LockScreenWeatherPanelManager.shared.latestFrame?.minY ?? min(screenFrame.maxY - 120, max(defaultWeatherBottom, musicTop + size.height + 80))

        let marginAboveMusic: CGFloat = 16
        let marginBelowWeather: CGFloat = 16

        let constrainedWeatherBottom = max(weatherBottom, musicTop + size.height + marginAboveMusic + marginBelowWeather)
        let centerY = (musicTop + constrainedWeatherBottom) / 2
        let lowerBound = screenFrame.minY + 80
        let upperBound = constrainedWeatherBottom - marginBelowWeather - size.height

        var proposedY = centerY - (size.height / 2)
        if proposedY < lowerBound {
            proposedY = lowerBound
        }
        if upperBound > lowerBound {
            proposedY = min(proposedY, upperBound)
        }

        return NSRect(x: originX, y: proposedY, width: size.width, height: size.height)
    }
}

