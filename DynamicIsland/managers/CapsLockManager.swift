//
//  CapsLockManager.swift
//  DynamicIsland
//
//  Created for Caps Lock indicator feature
//  Monitors Caps Lock state and integrates with Dynamic Island
//

import Foundation
import Combine
import AppKit
import Defaults

@MainActor
class CapsLockManager: ObservableObject {
    static let shared = CapsLockManager()
    
    @Published var isCapsLockActive: Bool = false
    
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private let coordinator = DynamicIslandViewCoordinator.shared
    
    private init() {
        // Get initial state
        isCapsLockActive = NSEvent.modifierFlags.contains(.capsLock)
        
        // Monitor flag changes when app is focused
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
        
        // Monitor flag changes globally (even when app is not focused)
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event)
            }
        }
        
        print("CapsLockManager: ✅ Initialized with Caps Lock \(isCapsLockActive ? "ON" : "OFF")")
    }
    
    deinit {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        let newState = event.modifierFlags.contains(.capsLock)
        
        guard newState != isCapsLockActive else { return }
        
        isCapsLockActive = newState
        
        print("CapsLockManager: Caps Lock \(newState ? "ACTIVATED" : "DEACTIVATED")")
        
        // Only show/hide if feature is enabled
        guard Defaults[.enableCapsLockIndicator] else { return }
        
        if newState {
            // Show inline indicator
            coordinator.toggleSneakPeek(
                status: true,
                type: .capsLock,
                duration: .infinity, // Stay visible until deactivated
                value: 1.0,
                icon: ""
            )
        } else {
            // Hide indicator
            coordinator.toggleSneakPeek(
                status: false,
                type: .capsLock,
                duration: 0,
                value: 0,
                icon: ""
            )
        }
    }
}
