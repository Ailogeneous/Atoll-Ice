//
//  MouseCursor.swift
//  Ice
//

import CoreGraphics
import Foundation

/// A namespace for mouse cursor operations.
enum MouseCursor {
    private static let lock = NSLock()
    private static var cursorControlLockCount = 0

    /// Returns the location of the mouse cursor in the coordinate space used by
    /// the `AppKit` framework, with the origin at the bottom left of the screen.
    static var locationAppKit: CGPoint? {
        CGEvent(source: nil)?.unflippedLocation
    }

    /// Returns the location of the mouse cursor in the coordinate space used by
    /// the `CoreGraphics` framework, with the origin at the top left of the screen.
    static var locationCoreGraphics: CGPoint? {
        CGEvent(source: nil)?.location
    }

    /// Hides the mouse cursor and increments the hide cursor count.
    static func hide() {
        let result = CGDisplayHideCursor(CGMainDisplayID())
        if result != .success {
            Bridging.Logger.mouseCursor.error("CGDisplayHideCursor failed with error \(result.logString)")
        }
    }

    /// Decrements the hide cursor count and shows the mouse cursor if the count is `0`.
    static func show() {
        let result = CGDisplayShowCursor(CGMainDisplayID())
        if result != .success {
            Bridging.Logger.mouseCursor.error("CGDisplayShowCursor failed with error \(result.logString)")
        }
    }

    /// Moves the mouse cursor to the given point without generating events.
    ///
    /// - Parameter point: The point to move the cursor to in global display coordinates.
    static func warp(to point: CGPoint) {
        let result = CGWarpMouseCursorPosition(point)
        if result != .success {
            Bridging.Logger.mouseCursor.error("CGWarpMouseCursorPosition failed with error \(result.logString)")
        }
    }

    /// Disables user control over cursor movement while retaining programmatic control.
    static func lockUserCursorControl() {
        lock.lock()
        defer { lock.unlock() }

        cursorControlLockCount += 1
        guard cursorControlLockCount == 1 else {
            return
        }

        let result = CGAssociateMouseAndMouseCursorPosition(0)
        if result != .success {
            Bridging.Logger.mouseCursor.error("CGAssociateMouseAndMouseCursorPosition(false) failed with error \(result.logString)")
        }
    }

    /// Restores user control over cursor movement.
    static func unlockUserCursorControl() {
        lock.lock()
        defer { lock.unlock() }

        cursorControlLockCount = max(0, cursorControlLockCount - 1)
        guard cursorControlLockCount == 0 else {
            return
        }

        let result = CGAssociateMouseAndMouseCursorPosition(1)
        if result != .success {
            Bridging.Logger.mouseCursor.error("CGAssociateMouseAndMouseCursorPosition(true) failed with error \(result.logString)")
        }
    }
}

// MARK: - Bridging.Logger
private extension Bridging.Logger {
    static let mouseCursor = Bridging.Logger(category: "MouseCursor")
}
