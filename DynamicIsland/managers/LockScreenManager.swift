//
//  LockScreenManager.swift
//  DynamicIsland
//
//  Created for lock screen detection feature
//  Monitors system lock/unlock events and provides real-time status updates
//

import Foundation
import Combine
import AppKit
import Defaults
import SwiftUI
import AVFoundation

enum LockScreenAnimationTimings {
    static let lockExpand: TimeInterval = 0.45
    static let unlockCollapse: TimeInterval = 0.82
}

@MainActor
class LockScreenManager: ObservableObject {
    static let shared = LockScreenManager()
    
    // MARK: - Coordinator
    private let coordinator = DynamicIslandViewCoordinator.shared
    private weak var viewModel: DynamicIslandViewModel?
    
    // MARK: - Published Properties
    @Published var isLocked: Bool = false
    @Published var isLockIdle: Bool = true
    @Published var lastUpdated: Date = .distantPast
    
    // MARK: - Private Properties
    private var debounceIdleTask: Task<Void, Never>?
    private var collapseTask: Task<Void, Never>?
    
    // MARK: - Helpers
    
    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
    
    // MARK: - Initialization
    private init() {
        setupObservers()
        print("LockScreenManager: 🔒 Initialized")
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        debounceIdleTask?.cancel()
        collapseTask?.cancel()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe screen locked event
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenLocked),
            name: .init("com.apple.screenIsLocked"),
            object: nil
        )
        
        // Observe screen unlocked event
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: .init("com.apple.screenIsUnlocked"),
            object: nil
        )
        
        print("LockScreenManager: ✅ Observers registered for lock/unlock events")
    }
    
    // MARK: - Event Handlers
    
    @objc private func screenLocked() {
        print("[\(timestamp())] LockScreenManager: 🔒 Screen LOCKED event received")
        LockSoundPlayer.shared.playLockChime()
        
        // Update state SYNCHRONOUSLY without Task/await to avoid any delay
        lastUpdated = Date()
        updateIdleState(locked: true)
        
        // Set locked state immediately without animation wrapper
        isLocked = true
        collapseTask?.cancel()

        viewModel?.closeForLockScreen()

        if coordinator.expandingView.show {
            let currentType = coordinator.expandingView.type
            coordinator.toggleExpandingView(status: false, type: currentType)
        }

        if coordinator.sneakPeek.show {
            coordinator.toggleSneakPeek(status: false, type: coordinator.sneakPeek.type)
        }
        
        // Show panel FIRST (creates and shows window on lock screen)
        print("[\(timestamp())] LockScreenManager: 🎵 Showing lock screen panel")
        LockScreenPanelManager.shared.showPanel()
        LockScreenLiveActivityWindowManager.shared.showLocked()
        LockScreenWeatherManager.shared.showWeatherWidget()
        LockScreenReminderWidgetManager.shared.showReminderWidget()
        
        // THEN trigger lock icon in Dynamic Island (only if enabled in settings)
        if Defaults[.enableLockScreenLiveActivity] {
            print("[\(timestamp())] LockScreenManager: 🔴 Starting lock icon live activity")
            coordinator.toggleExpandingView(status: true, type: .lockScreen)
        } else {
            print("[\(timestamp())] LockScreenManager: ⏭️ Lock icon disabled in settings")
        }
        
        print("[\(timestamp())] LockScreenManager: ✅ Lock screen activated")
    }
    
    @objc private func screenUnlocked() {
        print("[\(timestamp())] LockScreenManager: 🔓 Screen UNLOCKED event received")
        LockSoundPlayer.shared.playUnlockChime()
        
        // Hide panel window immediately and synchronously
        print("[\(timestamp())] LockScreenManager: 🚪 Hiding panel window")
        LockScreenPanelManager.shared.hidePanel()
        LockScreenLiveActivityWindowManager.shared.showUnlockAndScheduleHide()
        LockScreenWeatherManager.shared.hideWeatherWidget()
        LockScreenReminderWidgetManager.shared.hideReminderWidget()
        
        // Update state immediately
        if Defaults[.enableLockScreenLiveActivity] {
            collapseTask?.cancel()
            collapseTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(LockScreenAnimationTimings.unlockCollapse))
                guard let self = self, !Task.isCancelled else { return }
                await MainActor.run {
                    self.coordinator.toggleExpandingView(status: false, type: .lockScreen)
                }
            }
        }
        
        self.lastUpdated = Date()
    self.updateIdleState(locked: false)
        self.isLocked = false
        
        print("[\(self.timestamp())] LockScreenManager: ✅ Lock screen deactivated")
    }
    
    // MARK: - Idle State Management
    
    /// Copy EXACT logic from ScreenRecordingManager
    private func updateIdleState(locked: Bool) {
        if locked {
            isLockIdle = false
            debounceIdleTask?.cancel()
        } else {
            debounceIdleTask?.cancel()
            debounceIdleTask = Task { [weak self] in
                let configuredInterval = max(Defaults[.waitInterval], 0)
                let idleDelay = min(max(configuredInterval, 0.2), LockScreenAnimationTimings.unlockCollapse)
                try? await Task.sleep(for: .seconds(idleDelay))
                guard let self = self, !Task.isCancelled else { return }
                await MainActor.run {
                    if self.lastUpdated.timeIntervalSinceNow < -idleDelay {
                        withAnimation(.smooth(duration: 0.3)) {
                            self.isLockIdle = !self.isLocked
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Extensions

extension LockScreenManager {
    func configure(viewModel: DynamicIslandViewModel) {
        self.viewModel = viewModel
    }
    
    /// Get current lock status without async
    var currentLockStatus: Bool {
        return isLocked
    }
    
    /// Check if monitoring is available (for settings UI)
    var isMonitoringAvailable: Bool {
        return true // Always available on macOS
    }
}

// MARK: - Lock Sound Playback

@MainActor
final class LockSoundPlayer {
    static let shared = LockSoundPlayer()
    private let throttleInterval: TimeInterval = 0.25
    private var players: [SoundType: AVAudioPlayer] = [:]
    private var lastPlaybackDates: [SoundType: Date] = [:]

    private init() {}

    func playLockChime() {
        play(.lock)
    }

    func playUnlockChime() {
        play(.unlock)
    }

    private func play(_ type: SoundType) {
        guard Defaults[.enableLockSounds] else { return }
        guard shouldPlay(type) else { return }
        guard let player = resolvePlayer(for: type) else { return }

        player.currentTime = 0
        player.play()
        lastPlaybackDates[type] = Date()
    }

    private func shouldPlay(_ type: SoundType) -> Bool {
        guard let last = lastPlaybackDates[type] else { return true }
        return Date().timeIntervalSince(last) >= throttleInterval
    }

    private func resolvePlayer(for type: SoundType) -> AVAudioPlayer? {
        if let cached = players[type] {
            return cached
        }

        guard let url = Bundle.main.url(forResource: type.resourceName, withExtension: "mp3") else {
            Logger.log("Missing \(type.resourceName).mp3 in bundle", category: .warning)
            return nil
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[type] = player
            return player
        } catch {
            Logger.log("Failed to initialize lock sound player for \(type.resourceName): \(error.localizedDescription)", category: .error)
            return nil
        }
    }

    private enum SoundType: String {
        case lock
        case unlock

        var resourceName: String { rawValue }
    }
}
