//
//  DisplayServicesDynamic.swift
//  DynamicIsland
//
//  Created by AI Assistant on 25/12/2025.
//
//  Lightweight wrapper that resolves DisplayServices symbols at runtime so we
//  can call the private brightness APIs without linking against the framework.
//

import Foundation
import Darwin

final class DisplayServicesDynamic {
    static let shared = DisplayServicesDynamic()

    private let handle: UnsafeMutableRawPointer?

    private typealias GetBrightnessFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFn = @convention(c) (UInt32, Float) -> Int32

    private let getBrightnessFn: GetBrightnessFn?
    private let setBrightnessFn: SetBrightnessFn?

    private init() {
        handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)

        if handle == nil, let errorPointer = dlerror() {
            let message = String(cString: errorPointer)
            NSLog("⚠️ DisplayServicesDynamic: dlopen failed - %@", message)
        }

        getBrightnessFn = handle.flatMap { dlsym($0, "DisplayServicesGetBrightness") }
            .map { unsafeBitCast($0, to: GetBrightnessFn.self) }

        setBrightnessFn = handle.flatMap { dlsym($0, "DisplayServicesSetBrightness") }
            .map { unsafeBitCast($0, to: SetBrightnessFn.self) }
    }

    func setBrightness(displayID: UInt32, value: Float) -> Int32? {
        guard let fn = setBrightnessFn else { return nil }
        return fn(displayID, value)
    }

    func getBrightness(displayID: UInt32) -> (status: Int32, value: Float)? {
        guard let fn = getBrightnessFn else { return nil }
        var brightness: Float = 0
        let status = fn(displayID, &brightness)
        return (status, brightness)
    }

    deinit {
        if let handle {
            dlclose(handle)
        }
    }
}
