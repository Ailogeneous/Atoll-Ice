//
//  ClipboardWindowManager.swift
//  DynamicIsland
//
//  Created by Ebullioscopic on 12/08/25.
//

import SwiftUI
import AppKit

class ClipboardWindowManager: ObservableObject {
    static let shared = ClipboardWindowManager()
    
    private var clipboardWindow: NSWindow?
    
    private init() {}
    
    func showClipboardWindow() {
        if let existingWindow = clipboardWindow {
            // Ensure window appears above fullscreen apps
            existingWindow.level = .screenSaver
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()  // Force window to front even above fullscreen
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Clipboard Manager"
        window.isMovableByWindowBackground = true
        window.level = .screenSaver  // Use screenSaver level to appear above fullscreen apps
        window.isReleasedWhenClosed = false
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]  // Allow on all spaces and above fullscreen
        
        // Set minimum and maximum sizes
        window.minSize = NSSize(width: 350, height: 250)
        window.maxSize = NSSize(width: 600, height: 500)
        
        // Center the window on the current screen (important for fullscreen apps)
        let currentScreen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = currentScreen.frame  // Use full frame instead of visibleFrame for fullscreen compatibility
        let windowFrame = window.frame
        let x = (screenFrame.width - windowFrame.width) / 2 + screenFrame.minX
        let y = (screenFrame.height - windowFrame.height) / 2 + screenFrame.minY
        window.setFrameOrigin(NSPoint(x: x, y: y))
        
        // Set the content view
        let contentView = ClipboardWindow()
        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView
        
        // Handle window closing
        window.delegate = WindowDelegate { [weak self] window in
            ScreenCaptureVisibilityManager.shared.unregister(window)
            self?.clipboardWindow = nil
        }

        ScreenCaptureVisibilityManager.shared.register(window, scope: .panelsOnly)
        
        self.clipboardWindow = window
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()  // Force window to front even above fullscreen apps
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideClipboardWindow() {
        clipboardWindow?.close()
    }
    
    func toggleClipboardWindow() {
        if let window = clipboardWindow, window.isVisible {
            hideClipboardWindow()
        } else {
            showClipboardWindow()
        }
    }
    
    var isWindowVisible: Bool {
        return clipboardWindow?.isVisible ?? false
    }
}

private class WindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: (NSWindow) -> Void

    init(onClose: @escaping (NSWindow) -> Void) {
        self.onClose = onClose
        super.init()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide instead of close when user clicks close button
        sender.orderOut(nil)
        onClose(sender)
        return false
    }
}
