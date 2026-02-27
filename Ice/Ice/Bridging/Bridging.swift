//
//  Bridging.swift
//  Ice
//

import ApplicationServices
import Cocoa
import CoreGraphics
import OSLog

/// A namespace for bridged functionality.
enum Bridging {
    // MARK: - Bridged Types

    typealias CGSConnectionID = Int32
    typealias CGSSpaceID = size_t

    enum CGSSpaceType: UInt32 {
        case user = 0
        case system = 2
        case fullscreen = 4
    }

    struct CGSSpaceMask: OptionSet {
        let rawValue: UInt32

        static let includesCurrent = CGSSpaceMask(rawValue: 1 << 0)
        static let includesOthers = CGSSpaceMask(rawValue: 1 << 1)
        static let includesUser = CGSSpaceMask(rawValue: 1 << 2)

        static let includesVisible = CGSSpaceMask(rawValue: 1 << 16)

        static let currentSpace: CGSSpaceMask = [.includesUser, .includesCurrent]
        static let otherSpaces: CGSSpaceMask = [.includesOthers, .includesCurrent]
        static let allSpaces: CGSSpaceMask = [.includesUser, .includesOthers, .includesCurrent]
        static let allVisibleSpaces: CGSSpaceMask = [.includesVisible, .allSpaces]
    }

    // MARK: - CGSConnection Functions

    @_silgen_name("CGSMainConnectionID")
    fileprivate static func CGSMainConnectionID() -> CGSConnectionID

    @_silgen_name("CGSCopyConnectionProperty")
    fileprivate static func CGSCopyConnectionProperty(
        _ cid: CGSConnectionID,
        _ targetCID: CGSConnectionID,
        _ key: CFString,
        _ outValue: inout Unmanaged<CFTypeRef>?
    ) -> CGError

    @_silgen_name("CGSSetConnectionProperty")
    fileprivate static func CGSSetConnectionProperty(
        _ cid: CGSConnectionID,
        _ targetCID: CGSConnectionID,
        _ key: CFString,
        _ value: CFTypeRef
    ) -> CGError

    // MARK: - CGSEvent Functions

    @_silgen_name("CGSEventIsAppUnresponsive")
    fileprivate static func CGSEventIsAppUnresponsive(
        _ cid: CGSConnectionID,
        _ psn: inout ProcessSerialNumber
    ) -> Bool

    // MARK: - CGSSpace Functions

    @_silgen_name("CGSGetActiveSpace")
    fileprivate static func CGSGetActiveSpace(_ cid: CGSConnectionID) -> CGSSpaceID

    @_silgen_name("CGSCopySpacesForWindows")
    fileprivate static func CGSCopySpacesForWindows(
        _ cid: CGSConnectionID,
        _ mask: CGSSpaceMask,
        _ windowIDs: CFArray
    ) -> Unmanaged<CFArray>?

    @_silgen_name("CGSSpaceGetType")
    fileprivate static func CGSSpaceGetType(
        _ cid: CGSConnectionID,
        _ sid: CGSSpaceID
    ) -> CGSSpaceType

    // MARK: - CGSWindow Functions

    @_silgen_name("CGSGetWindowList")
    fileprivate static func CGSGetWindowList(
        _ cid: CGSConnectionID,
        _ targetCID: CGSConnectionID,
        _ count: Int32,
        _ list: UnsafeMutablePointer<CGWindowID>,
        _ outCount: inout Int32
    ) -> CGError

    @_silgen_name("CGSGetOnScreenWindowList")
    fileprivate static func CGSGetOnScreenWindowList(
        _ cid: CGSConnectionID,
        _ targetCID: CGSConnectionID,
        _ count: Int32,
        _ list: UnsafeMutablePointer<CGWindowID>,
        _ outCount: inout Int32
    ) -> CGError

    @_silgen_name("CGSGetProcessMenuBarWindowList")
    fileprivate static func CGSGetProcessMenuBarWindowList(
        _ cid: CGSConnectionID,
        _ targetCID: CGSConnectionID,
        _ count: Int32,
        _ list: UnsafeMutablePointer<CGWindowID>,
        _ outCount: inout Int32
    ) -> CGError

    @_silgen_name("CGSGetWindowCount")
    fileprivate static func CGSGetWindowCount(
        _ cid: CGSConnectionID,
        _ targetCID: CGSConnectionID,
        _ outCount: inout Int32
    ) -> CGError

    @_silgen_name("CGSGetOnScreenWindowCount")
    fileprivate static func CGSGetOnScreenWindowCount(
        _ cid: CGSConnectionID,
        _ targetCID: CGSConnectionID,
        _ outCount: inout Int32
    ) -> CGError

    @_silgen_name("CGSGetScreenRectForWindow")
    fileprivate static func CGSGetScreenRectForWindow(
        _ cid: CGSConnectionID,
        _ wid: CGWindowID,
        _ outRect: inout CGRect
    ) -> CGError

    // MARK: - Deprecated Functions

    /// Returns a PSN for a given PID.
    @_silgen_name("GetProcessForPID")
    fileprivate static func GetProcessForPID(
        _ pid: pid_t,
        _ psn: inout ProcessSerialNumber
    ) -> OSStatus

    // MARK: - Logger

    /// A type that encapsulates logging behavior for Ice.
    struct Logger {
        /// The unified logger at the base of this logger.
        private let base: os.Logger

        /// Creates a logger for Ice using the specified category.
        init(category: String) {
            self.base = os.Logger(subsystem: IceConstants.bundleIdentifier, category: category)
        }

        /// Logs the given informative message to the logger.
        func info(_ message: String) {
            base.info("\(message, privacy: .public)")
        }

        /// Logs the given debug message to the logger.
        func debug(_ message: String) {
            base.debug("\(message, privacy: .public)")
        }

        /// Logs the given error message to the logger.
        func error(_ message: String) {
            base.error("\(message, privacy: .public)")
        }

        /// Logs the given warning message to the logger.
        func warning(_ message: String) {
            base.warning("\(message, privacy: .public)")
        }
    }
}

// MARK: - CGSConnection

extension Bridging {
    /// Sets a value for the given key in the current connection to the window server.
    ///
    /// - Parameters:
    ///   - value: The value to set for `key`.
    ///   - key: A key associated with the current connection to the window server.
    static func setConnectionProperty(_ value: Any?, forKey key: String) {
        let result = CGSSetConnectionProperty(
            CGSMainConnectionID(),
            CGSMainConnectionID(),
            key as CFString,
            value as CFTypeRef
        )
        if result != .success {
            Bridging.Logger.bridging.error("CGSSetConnectionProperty failed with error \(result.logString)")
        }
    }

    /// Returns the value for the given key in the current connection to the window server.
    ///
    /// - Parameter key: A key associated with the current connection to the window server.
    /// - Returns: The value associated with `key` in the current connection to the window server.
    static func getConnectionProperty(forKey key: String) -> Any? {
        var value: Unmanaged<CFTypeRef>?
        let result = CGSCopyConnectionProperty(
            CGSMainConnectionID(),
            CGSMainConnectionID(),
            key as CFString,
            &value
        )
        if result != .success {
            Bridging.Logger.bridging.error("CGSCopyConnectionProperty failed with error \(result.logString)")
        }
        return value?.takeRetainedValue()
    }
}

// MARK: - CGSWindow

extension Bridging {
    /// Returns the frame for the window with the specified identifier.
    ///
    /// - Parameter windowID: An identifier for a window.
    /// - Returns: The frame -- specified in screen coordinates -- of the window associated
    ///   with `windowID`, or `nil` if the operation failed.
    static func getWindowFrame(for windowID: CGWindowID) -> CGRect? {
        var rect = CGRect.zero
        let result = CGSGetScreenRectForWindow(CGSMainConnectionID(), windowID, &rect)
        guard result == .success else {
            Bridging.Logger.bridging.error("CGSGetScreenRectForWindow failed with error \(result.logString)")
            return nil
        }
        return rect
    }
}

// MARK: Private Window List Helpers
extension Bridging {
    private static func getWindowCount() -> Int {
        var count: Int32 = 0
        let result = CGSGetWindowCount(CGSMainConnectionID(), 0, &count)
        if result != .success {
            Bridging.Logger.bridging.error("CGSGetWindowCount failed with error \(result.logString)")
        }
        return Int(count)
    }

    private static func getOnScreenWindowCount() -> Int {
        var count: Int32 = 0
        let result = CGSGetOnScreenWindowCount(CGSMainConnectionID(), 0, &count)
        if result != .success {
            Bridging.Logger.bridging.error("CGSGetOnScreenWindowCount failed with error \(result.logString)")
        }
        return Int(count)
    }

    private static func getWindowList() -> [CGWindowID] {
        let windowCount = getWindowCount()
        var list = [CGWindowID](repeating: 0, count: windowCount)
        var realCount: Int32 = 0
        let result = CGSGetWindowList(
            CGSMainConnectionID(),
            0,
            Int32(windowCount),
            &list,
            &realCount
        )
        guard result == .success else {
            Bridging.Logger.bridging.error("CGSGetWindowList failed with error \(result.logString)")
            return []
        }
        return [CGWindowID](list[..<Int(realCount)])
    }

    private static func getOnScreenWindowList() -> [CGWindowID] {
        let windowCount = getOnScreenWindowCount()
        var list = [CGWindowID](repeating: 0, count: windowCount)
        var realCount: Int32 = 0
        let result = CGSGetOnScreenWindowList(
            CGSMainConnectionID(),
            0,
            Int32(windowCount),
            &list,
            &realCount
        )
        guard result == .success else {
            Bridging.Logger.bridging.error("CGSGetOnScreenWindowList failed with error \(result.logString)")
            return []
        }
        return [CGWindowID](list[..<Int(realCount)])
    }

    private static func getMenuBarWindowList() -> [CGWindowID] {
        let windowCount = getWindowCount()
        var list = [CGWindowID](repeating: 0, count: windowCount)
        var realCount: Int32 = 0
        let result = CGSGetProcessMenuBarWindowList(
            CGSMainConnectionID(),
            0,
            Int32(windowCount),
            &list,
            &realCount
        )
        guard result == .success else {
            Bridging.Logger.bridging.error("CGSGetProcessMenuBarWindowList failed with error \(result.logString)")
            return []
        }
        return [CGWindowID](list[..<Int(realCount)])
    }

    private static func getOnScreenMenuBarWindowList() -> [CGWindowID] {
        let onScreenList = Set(getOnScreenWindowList())
        return getMenuBarWindowList().filter(onScreenList.contains)
    }
}

// MARK: Public Window List API
extension Bridging {
    /// Options that determine the window identifiers to return in a window list.
    struct WindowListOption: OptionSet {
        let rawValue: Int

        /// Specifies windows that are currently on-screen.
        static let onScreen = WindowListOption(rawValue: 1 << 0)

        /// Specifies windows that represent items in the menu bar.
        static let menuBarItems = WindowListOption(rawValue: 1 << 1)

        /// Specifies windows on the currently active space.
        static let activeSpace = WindowListOption(rawValue: 1 << 2)
    }

    /// The total number of windows.
    static var windowCount: Int {
        getWindowCount()
    }

    /// The number of windows currently on-screen.
    static var onScreenWindowCount: Int {
        getOnScreenWindowCount()
    }

    /// Returns a list of window identifiers using the given options.
    ///
    /// - Parameter option: Options that filter the returned list.
    static func getWindowList(option: WindowListOption = []) -> [CGWindowID] {
        let list = if option.contains(.menuBarItems) {
            if option.contains(.onScreen) {
                getOnScreenMenuBarWindowList()
            } else {
                getMenuBarWindowList()
            }
        } else if option.contains(.onScreen) {
            getOnScreenWindowList()
        } else {
            getWindowList()
        }
        return if option.contains(.activeSpace) {
            list.filter(isWindowOnActiveSpace)
        } else {
            list
        }
    }
}

// MARK: - CGSSpace

extension Bridging {
    /// Options that determine the space identifiers to return in a space list.
    enum SpaceListOption {
        case allSpaces, visibleSpaces
    }

    /// The identifier of the active space.
    static var activeSpaceID: CGSSpaceID {
        CGSGetActiveSpace(CGSMainConnectionID())
    }

    /// Returns an array of identifiers for the spaces containing the window with
    /// the given identifier.
    ///
    /// - Parameter windowID: An identifier for a window.
    static func getSpaceList(for windowID: CGWindowID, option: SpaceListOption) -> [CGSSpaceID] {
        let mask: CGSSpaceMask = switch option {
        case .allSpaces: .allSpaces
        case .visibleSpaces: .allVisibleSpaces
        }
        guard let spaces = CGSCopySpacesForWindows(CGSMainConnectionID(), mask, [windowID] as CFArray) else {
            Bridging.Logger.bridging.error("CGSCopySpacesForWindows failed")
            return []
        }
        guard let spaceIDs = spaces.takeRetainedValue() as? [CGSSpaceID] else {
            Bridging.Logger.bridging.error("CGSCopySpacesForWindows returned array of unexpected type")
            return []
        }
        return spaceIDs
    }

    /// Returns a Boolean value that indicates whether the window with the
    /// given identifier is on the active space.
    ///
    /// - Parameter windowID: An identifier for a window.
    static func isWindowOnActiveSpace(_ windowID: CGWindowID) -> Bool {
        getSpaceList(for: windowID, option: .allSpaces).contains(activeSpaceID)
    }

    /// Returns a Boolean value that indicates whether the space with the given
    /// identifier is a fullscreen space.
    ///
    /// - Parameter spaceID: An identifier for a space.
    static func isSpaceFullscreen(_ spaceID: CGSSpaceID) -> Bool {
        let type = CGSSpaceGetType(CGSMainConnectionID(), spaceID)
        return type == .fullscreen
    }
}

// MARK: - Process Responsivity

extension Bridging {
    /// Constants that indicate the responsivity of an app.
    enum Responsivity {
        case responsive, unresponsive, unknown
    }

    /// Returns the responsivity of the given process.
    ///
    /// - Parameter pid: The Unix process identifier of the process to check.
    static func responsivity(for pid: pid_t) -> Responsivity {
        var psn = ProcessSerialNumber()
        let result = GetProcessForPID(pid, &psn)
        guard result == noErr else {
            Bridging.Logger.bridging.error("GetProcessForPID failed with error \(result)")
            return .unknown
        }
        if CGSEventIsAppUnresponsive(CGSMainConnectionID(), &psn) {
            return .unresponsive
        }
        return .responsive
    }
}

// MARK: - Bridging.Logger
extension Bridging.Logger {
    static let bridging = Bridging.Logger(category: "Bridging")
}
