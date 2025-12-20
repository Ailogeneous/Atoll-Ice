#if os(macOS)
import AppKit
import SwiftUI
import SkyLightWindow
import QuartzCore
import Defaults
import Combine

@MainActor
final class CircularHUDWindowManager {
    static let shared = CircularHUDWindowManager()
    
    private var windows: [NSScreen: OSDWindow] = [:]
    private var hideWorkItem: DispatchWorkItem?
    private let displayDuration: TimeInterval = 2.0
    private let animationDuration: TimeInterval = 0.2
    
    private var cancellables = Set<AnyCancellable>()
    
    // Layout constants removed in favor of dynamic calculation
    
    private init() {
        setupSizeObserver()
    }
    
    private func setupSizeObserver() {
        Defaults.publisher(.circularHUDSize, options: []).sink { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateWindowLayout()
            }
        }.store(in: &cancellables)
    }
    
    private func updateWindowLayout() {
        guard !windows.isEmpty else { return }
        
        for (screen, window) in windows {
            let screenFrame = screen.frame
            let hudSize = Defaults[.circularHUDSize]
            let windowSize = hudSize + 80 // Padding
            
            let x = screenFrame.midX - (windowSize / 2)
            let y = screenFrame.midY - (windowSize / 2)
            let newFrame = NSRect(x: x, y: y, width: windowSize, height: windowSize)
            
            window.nsWindow.setFrame(newFrame, display: true, animate: true)
        }
    }
    
    func show(type: SneakContentType, value: CGFloat, icon: String = "") {
        guard Defaults[.enableCircularHUD] else { return }
        
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        
        // Show on all screens
        for screen in screens {
            let windowContext = ensureWindow(for: type, screen: screen)
            updateContent(window: windowContext, type: type, value: value, icon: icon)
            
            // Ensure visible
            windowContext.nsWindow.orderFrontRegardless()
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animationDuration
                windowContext.nsWindow.animator().alphaValue = 1
            }
        }
        
        scheduleHide()
    }
    
    private func ensureWindow(for type: SneakContentType, screen: NSScreen) -> OSDWindow {
        if let existing = windows[screen] {
            return existing
        }
        
        let osdView = CircularHUDView(type: .constant(type), value: .constant(0), icon: .constant(""))
        let hostingView = NSHostingView(rootView: osdView)
        
        let screenFrame = screen.frame
        
        let hudSize = Defaults[.circularHUDSize]
        let windowSize = hudSize + 80 // Padding
        
        // Position at center of screen
        let x = screenFrame.midX - (windowSize / 2)
        let y = screenFrame.midY - (windowSize / 2)
        let frame = NSRect(x: x, y: y, width: windowSize, height: windowSize)
        
        let win = NSWindow(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        win.hasShadow = false
        win.contentView = hostingView
        win.alphaValue = 0
        
        SkyLightOperator.shared.delegateWindow(win)
        
        let windowStruct = OSDWindow(nsWindow: win, hostingView: hostingView, type: type)
        windows[screen] = windowStruct
        return windowStruct
    }
    
    private func updateContent(window: OSDWindow, type: SneakContentType, value: CGFloat, icon: String) {
        let osdView = CircularHUDView(type: .constant(type), value: .constant(value), icon: .constant(icon))
        window.hostingView.rootView = osdView
    }
    
    private func scheduleHide() {
        hideWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.hideWindow()
            }
        }
        
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration, execute: workItem)
    }
    
    private func hideWindow() {
        for window in windows.values {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animationDuration
                window.nsWindow.animator().alphaValue = 0
            } completionHandler: {
                 // Keep window around but hidden for faster subsequent shows
            }
        }
    }
    
    // Helper struct
    private struct OSDWindow {
        let nsWindow: NSWindow
        let hostingView: NSHostingView<CircularHUDView>
        let type: SneakContentType
    }
}
#endif
