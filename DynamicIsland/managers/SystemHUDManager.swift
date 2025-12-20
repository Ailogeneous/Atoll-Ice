//
//  SystemHUDManager.swift
//  DynamicIsland
//
//  Created by GitHub Copilot on 06/09/25.
//

import Foundation
import Defaults
import Combine

class SystemHUDManager {
    static let shared = SystemHUDManager()
    
    private var changesObserver: SystemChangesObserver?
    private weak var coordinator: DynamicIslandViewCoordinator?
    private var isSetupComplete = false
    private var isSystemOperationInProgress = false
    
    private init() {
        // Set up observer for settings changes
        setupSettingsObserver()
    }
    
    private func setupSettingsObserver() {
        // Observe Vertical HUD toggle
        Defaults.publisher(.enableVerticalHUD, options: []).sink { [weak self] change in
            guard let self = self, self.isSetupComplete else {
                return
            }
            Task { @MainActor in
                if change.newValue {
                    // Always restart to ensure correct flags are applied
                    await self.startSystemObserver()
                } else if Defaults[.enableSystemHUD] || Defaults[.enableCustomOSD] || Defaults[.enableCircularHUD] {
                    // Restart to apply flags for the remaining active HUD
                    await self.startSystemObserver()
                } else {
                    await self.stopSystemObserver()
                }
            }
        }.store(in: &cancellables)
        
        // Observe master HUD toggle
        Defaults.publisher(.enableSystemHUD, options: []).sink { [weak self] change in
            guard let self = self, self.isSetupComplete else {
                return
            }
            Task { @MainActor in
                if change.newValue && !Defaults[.enableCustomOSD] && !Defaults[.enableVerticalHUD] && !Defaults[.enableCircularHUD] {
                     // Always restart to ensure correct flags are applied
                    await self.startSystemObserver()
                } else if !Defaults[.enableCustomOSD] && !Defaults[.enableVerticalHUD] && !Defaults[.enableCircularHUD] {
                    // Only stop if others are also disabled
                    await self.stopSystemObserver()
                } else if change.newValue == false && (Defaults[.enableCustomOSD] || Defaults[.enableVerticalHUD] || Defaults[.enableCircularHUD]) {
                     // If disabling system HUD but others are active, restart to update flags
                     await self.startSystemObserver()
                }
            }
        }.store(in: &cancellables)
        
        // Observe OSD toggle
        Defaults.publisher(.enableCustomOSD, options: []).sink { [weak self] change in
            guard let self = self, self.isSetupComplete else {
                return
            }
            Task { @MainActor in
                if change.newValue {
                     // Always restart to ensure correct flags are applied
                    await self.startSystemObserver()
                } else if Defaults[.enableSystemHUD] || Defaults[.enableVerticalHUD] || Defaults[.enableCircularHUD] {
                    // Restart to apply flags for the remaining active HUD
                    await self.startSystemObserver()
                } else {
                    await self.stopSystemObserver()
                }
            }
        }.store(in: &cancellables)
        
        // Observe Circular HUD toggle
        Defaults.publisher(.enableCircularHUD, options: []).sink { [weak self] change in
            guard let self = self, self.isSetupComplete else {
                return
            }
            Task { @MainActor in
                if change.newValue {
                     // Always restart to ensure correct flags are applied
                    await self.startSystemObserver()
                } else if Defaults[.enableSystemHUD] || Defaults[.enableCustomOSD] || Defaults[.enableVerticalHUD] {
                    // Restart to apply flags for the remaining active HUD
                    await self.startSystemObserver()
                } else {
                    await self.stopSystemObserver()
                }
            }
        }.store(in: &cancellables)
        
        // Observe individual HUD toggles
        Defaults.publisher(.enableVolumeHUD, options: []).sink { [weak self] change in
            guard let self = self, self.isSetupComplete, Defaults[.enableSystemHUD] else {
                return
            }
            self.changesObserver?.update(
                volumeEnabled: change.newValue,
                brightnessEnabled: Defaults[.enableBrightnessHUD],
                keyboardBacklightEnabled: Defaults[.enableKeyboardBacklightHUD]
            )
        }.store(in: &cancellables)
        
        Defaults.publisher(.enableBrightnessHUD, options: []).sink { [weak self] change in
            guard let self = self, self.isSetupComplete, Defaults[.enableSystemHUD] else {
                return
            }
            self.changesObserver?.update(
                volumeEnabled: Defaults[.enableVolumeHUD],
                brightnessEnabled: change.newValue,
                keyboardBacklightEnabled: Defaults[.enableKeyboardBacklightHUD]
            )
        }.store(in: &cancellables)

        Defaults.publisher(.enableKeyboardBacklightHUD, options: []).sink { [weak self] change in
            guard let self = self, self.isSetupComplete, Defaults[.enableSystemHUD] else {
                return
            }
            self.changesObserver?.update(
                volumeEnabled: Defaults[.enableVolumeHUD],
                brightnessEnabled: Defaults[.enableBrightnessHUD],
                keyboardBacklightEnabled: change.newValue
            )
        }.store(in: &cancellables)
        
        // Observe individual OSD toggles
        Defaults.publisher(.enableOSDVolume, options: []).sink { [weak self] change in
            guard let self = self, self.isSetupComplete, Defaults[.enableCustomOSD] else {
                return
            }
            self.changesObserver?.update(
                volumeEnabled: change.newValue,
                brightnessEnabled: Defaults[.enableOSDBrightness],
                keyboardBacklightEnabled: Defaults[.enableOSDKeyboardBacklight]
            )
        }.store(in: &cancellables)
        
        Defaults.publisher(.enableOSDBrightness, options: []).sink { [weak self] change in
            guard let self = self, self.isSetupComplete, Defaults[.enableCustomOSD] else {
                return
            }
            self.changesObserver?.update(
                volumeEnabled: Defaults[.enableOSDVolume],
                brightnessEnabled: change.newValue,
                keyboardBacklightEnabled: Defaults[.enableOSDKeyboardBacklight]
            )
        }.store(in: &cancellables)
        
        Defaults.publisher(.enableOSDKeyboardBacklight, options: []).sink { [weak self] change in
            guard let self = self, self.isSetupComplete, Defaults[.enableCustomOSD] else {
                return
            }
            self.changesObserver?.update(
                volumeEnabled: Defaults[.enableOSDVolume],
                brightnessEnabled: Defaults[.enableOSDBrightness],
                keyboardBacklightEnabled: change.newValue
            )
        }.store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    /// Public property to check if system operations are in progress
    var isOperationInProgress: Bool {
        return isSystemOperationInProgress
    }
    
    func setup(coordinator: DynamicIslandViewCoordinator) {
        self.coordinator = coordinator
        
        // Initialize OSD manager
        Task { @MainActor in
            CustomOSDWindowManager.shared.initialize()
        }
        
        // Start observer if any HUD/OSD is enabled
        if Defaults[.enableSystemHUD] || Defaults[.enableCustomOSD] || Defaults[.enableVerticalHUD] || Defaults[.enableCircularHUD] {
            Task { @MainActor in
                await startSystemObserver()
                self.isSetupComplete = true
            }
        } else {
            isSetupComplete = true
        }
    }
    
    @MainActor
    private func startSystemObserver() async {
        guard let coordinator = coordinator, !isSystemOperationInProgress else { return }
        
        isSystemOperationInProgress = true
        await stopSystemObserver() // Stop any existing observer
        
        changesObserver = SystemChangesObserver(coordinator: coordinator)
        
        // Determine which controls to enable based on HUD or OSD mode
        let volumeEnabled: Bool
        let brightnessEnabled: Bool
        let keyboardBacklightEnabled: Bool
        
        if Defaults[.enableCircularHUD] || Defaults[.enableVerticalHUD] {
            // Vertical and Circular HUD support all events
            volumeEnabled = true
            brightnessEnabled = true
            keyboardBacklightEnabled = true
        } else if Defaults[.enableCustomOSD] {
            volumeEnabled = Defaults[.enableOSDVolume]
            brightnessEnabled = Defaults[.enableOSDBrightness]
            keyboardBacklightEnabled = Defaults[.enableOSDKeyboardBacklight]
        } else {
            volumeEnabled = Defaults[.enableVolumeHUD]
            brightnessEnabled = Defaults[.enableBrightnessHUD]
            keyboardBacklightEnabled = Defaults[.enableKeyboardBacklightHUD]
        }
        
        changesObserver?.startObserving(
            volumeEnabled: volumeEnabled,
            brightnessEnabled: brightnessEnabled,
            keyboardBacklightEnabled: keyboardBacklightEnabled
        )
        
        // Force disable system HUD to ensure no duplicates
        SystemOSDManager.disableSystemHUD()
        
        print("System observer started (HUD: \(Defaults[.enableSystemHUD]), OSD: \(Defaults[.enableCustomOSD]), Vertical: \(Defaults[.enableVerticalHUD]))")
        isSystemOperationInProgress = false
    }
    
    @MainActor
    private func stopSystemObserver() async {
        guard !isSystemOperationInProgress else { return }
        
        isSystemOperationInProgress = true
        changesObserver?.stopObserving()
        changesObserver = nil
        
        // Re-enable system HUD when we stop observing
        SystemOSDManager.enableSystemHUD()
        
        print("System observer stopped")
        isSystemOperationInProgress = false
    }
    
    deinit {
        cancellables.removeAll()
        Task { @MainActor in
            await stopSystemObserver()
        }
    }
}