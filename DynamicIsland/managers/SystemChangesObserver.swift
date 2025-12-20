import Foundation
import CoreGraphics
import Defaults
import AppKit

final class SystemChangesObserver: MediaKeyInterceptorDelegate {
    private weak var coordinator: DynamicIslandViewCoordinator?
    private let volumeController = SystemVolumeController.shared
    private let brightnessController = SystemBrightnessController.shared
    private let keyboardBacklightController = SystemKeyboardBacklightController.shared
    private let mediaKeyInterceptor = MediaKeyInterceptor.shared

    private let standardVolumeStep: Float = 1.0 / 16.0
    private let standardBrightnessStep: Float = 1.0 / 16.0
    private let fineStepDivisor: Float = 4.0

    private var volumeEnabled = false
    private var brightnessEnabled = false
    private var keyboardBacklightEnabled = false

    init(coordinator: DynamicIslandViewCoordinator) {
        self.coordinator = coordinator
    }

    func startObserving(volumeEnabled: Bool, brightnessEnabled: Bool, keyboardBacklightEnabled: Bool) {
        self.volumeEnabled = volumeEnabled
        self.brightnessEnabled = brightnessEnabled
        self.keyboardBacklightEnabled = keyboardBacklightEnabled

        volumeController.onVolumeChange = { [weak self] volume, muted in
            guard let self, self.volumeEnabled else { return }
            let value = muted ? 0 : volume
            self.sendVolumeNotification(value: value)
        }
        volumeController.onRouteChange = { [weak self] in
            guard let self, self.volumeEnabled else { return }
            self.sendVolumeNotification(value: self.volumeController.isMuted ? 0 : self.volumeController.currentVolume)
        }
        volumeController.start()

        brightnessController.onBrightnessChange = { [weak self] brightness in
            guard let self, self.brightnessEnabled else { return }
            self.sendBrightnessNotification(value: brightness)
        }
        brightnessController.start()

        configureKeyboardBacklightCallback()
        if keyboardBacklightEnabled {
            keyboardBacklightController.start()
        }

        mediaKeyInterceptor.delegate = self
        let tapStarted = mediaKeyInterceptor.start()
        if !tapStarted {
            NSLog("⚠️ Media key interception unavailable; system HUD will remain visible")
        }
        mediaKeyInterceptor.configuration = MediaKeyConfiguration(
            interceptVolume: volumeEnabled,
            interceptBrightness: brightnessEnabled,
            interceptCommandModifiedBrightness: keyboardBacklightEnabled
        )
    }

    func update(volumeEnabled: Bool, brightnessEnabled: Bool, keyboardBacklightEnabled: Bool) {
        self.volumeEnabled = volumeEnabled
        self.brightnessEnabled = brightnessEnabled
        let backlightStateChanged = self.keyboardBacklightEnabled != keyboardBacklightEnabled
        self.keyboardBacklightEnabled = keyboardBacklightEnabled

        if keyboardBacklightEnabled {
            configureKeyboardBacklightCallback()
        } else {
            keyboardBacklightController.onBacklightChange = nil
        }

        if backlightStateChanged {
            if keyboardBacklightEnabled {
                keyboardBacklightController.start()
            } else {
                keyboardBacklightController.stop()
            }
        }

        mediaKeyInterceptor.configuration = MediaKeyConfiguration(
            interceptVolume: volumeEnabled,
            interceptBrightness: brightnessEnabled,
            interceptCommandModifiedBrightness: keyboardBacklightEnabled
        )
    }

    func stopObserving() {
        mediaKeyInterceptor.stop()
        mediaKeyInterceptor.delegate = nil

        volumeController.stop()
        volumeController.onVolumeChange = nil
        volumeController.onRouteChange = nil

        brightnessController.stop()
        brightnessController.onBrightnessChange = nil

        keyboardBacklightController.stop()
        keyboardBacklightController.onBacklightChange = nil
    }

    // MARK: - MediaKeyInterceptorDelegate

    func mediaKeyInterceptor(
        _ interceptor: MediaKeyInterceptor,
        didReceiveVolumeCommand direction: MediaKeyDirection,
        step: MediaKeyStep,
        isRepeat: Bool,
        modifiers: NSEvent.ModifierFlags
    ) {
        guard volumeEnabled else { return }
        
        // Elastic Limit Detection (Vertical HUD)
        if Defaults[.enableVerticalHUD] {
            let volume = volumeController.currentVolume
            if direction == .up && volume >= 0.99 {
                Task { @MainActor in VerticalHUDWindowManager.shared.triggerBump(direction: 1) }
            } else if direction == .down && volume <= 0.01 {
                Task { @MainActor in VerticalHUDWindowManager.shared.triggerBump(direction: -1) }
            }
        }
        
        let baseStep = stepSize(for: step, base: standardVolumeStep)
        let delta = direction == .up ? baseStep : -baseStep
        volumeController.adjust(by: delta)
    }

    func mediaKeyInterceptorDidToggleMute(_ interceptor: MediaKeyInterceptor) {
        guard volumeEnabled else { return }
        volumeController.toggleMute()
    }

    func mediaKeyInterceptor(
        _ interceptor: MediaKeyInterceptor,
        didReceiveBrightnessCommand direction: MediaKeyDirection,
        step: MediaKeyStep,
        isRepeat: Bool,
        modifiers: NSEvent.ModifierFlags
    ) {
        // Elastic Limit Detection (Vertical HUD)
        if Defaults[.enableVerticalHUD] {
            let brightness = brightnessController.currentBrightness
            if direction == .up && brightness >= 0.99 {
                Task { @MainActor in VerticalHUDWindowManager.shared.triggerBump(direction: 1) }
            } else if direction == .down && brightness <= 0.01 {
                Task { @MainActor in VerticalHUDWindowManager.shared.triggerBump(direction: -1) }
            }
        }
        
        let baseStep = stepSize(for: step, base: standardBrightnessStep)
        let delta = direction == .up ? baseStep : -baseStep
        if modifiers.contains(.command) && keyboardBacklightEnabled {
            keyboardBacklightController.adjust(by: delta)
        } else if brightnessEnabled {
            brightnessController.adjust(by: delta)
        }
    }

    // MARK: - HUD Dispatch

    private func sendVolumeNotification(value: Float) {
        if HUDSuppressionCoordinator.shared.shouldSuppressVolumeHUD {
            return
        }
        
        // Send to Circular HUD if enabled
        if Defaults[.enableCircularHUD] {
            Task { @MainActor in
                CircularHUDWindowManager.shared.show(type: .volume, value: CGFloat(value))
            }
            return
        }
        
        // Send to Vertical HUD if enabled
        if Defaults[.enableVerticalHUD] {
            Task { @MainActor in
                VerticalHUDWindowManager.shared.show(type: .volume, value: CGFloat(value))
            }
            return
        }
        
        // Send to custom OSD if enabled
        if Defaults[.enableCustomOSD] && Defaults[.enableOSDVolume] {
            Task { @MainActor in
                CustomOSDWindowManager.shared.showVolume(value: CGFloat(value))
            }
        }
        
        // Send to notch HUD if enabled and OSD/Vertical/Circular is not enabled
        if Defaults[.enableSystemHUD] && !Defaults[.enableCustomOSD] && !Defaults[.enableVerticalHUD] && !Defaults[.enableCircularHUD] && Defaults[.enableVolumeHUD] {
            Task { @MainActor in
                guard let coordinator else { return }
                coordinator.toggleSneakPeek(
                    status: true,
                    type: .volume,
                    value: CGFloat(value),
                    icon: ""
                )
            }
        }
    }

    private func sendBrightnessNotification(value: Float) {
        // Send to Circular HUD if enabled
        if Defaults[.enableCircularHUD] {
            Task { @MainActor in
                CircularHUDWindowManager.shared.show(type: .brightness, value: CGFloat(value))
            }
            return
        }
        
        // Send to Vertical HUD if enabled
        if Defaults[.enableVerticalHUD] {
            Task { @MainActor in
                VerticalHUDWindowManager.shared.show(type: .brightness, value: CGFloat(value))
            }
            return
        }

        // Send to custom OSD if enabled
        if Defaults[.enableCustomOSD] && Defaults[.enableOSDBrightness] {
            Task { @MainActor in
                CustomOSDWindowManager.shared.showBrightness(value: CGFloat(value))
            }
        }
        
        // Send to notch HUD if enabled and OSD/Vertical/Circular is not enabled
        if Defaults[.enableSystemHUD] && !Defaults[.enableCustomOSD] && !Defaults[.enableVerticalHUD] && !Defaults[.enableCircularHUD] && Defaults[.enableBrightnessHUD] {
            Task { @MainActor in
                guard let coordinator else { return }
                coordinator.toggleSneakPeek(
                    status: true,
                    type: .brightness,
                    value: CGFloat(value),
                    icon: ""
                )
            }
        }
    }

    private func sendKeyboardBacklightNotification(value: Float) {
        // Send to Circular HUD if enabled
        if Defaults[.enableCircularHUD] {
            Task { @MainActor in
                CircularHUDWindowManager.shared.show(type: .backlight, value: CGFloat(value))
            }
            return
        }
        
        // Send to Vertical HUD if enabled
        if Defaults[.enableVerticalHUD] {
            Task { @MainActor in
                VerticalHUDWindowManager.shared.show(type: .backlight, value: CGFloat(value))
            }
            return
        }

        // Send to custom OSD if enabled
        if Defaults[.enableCustomOSD] && Defaults[.enableOSDKeyboardBacklight] {
            Task { @MainActor in
                CustomOSDWindowManager.shared.showBacklight(value: CGFloat(value))
            }
        }
        
        // Send to notch HUD if enabled and OSD/Vertical/Circular is not enabled
        if Defaults[.enableSystemHUD] && !Defaults[.enableCustomOSD] && !Defaults[.enableVerticalHUD] && !Defaults[.enableCircularHUD] && Defaults[.enableKeyboardBacklightHUD] {
            Task { @MainActor in
                guard let coordinator else { return }
                coordinator.toggleSneakPeek(
                    status: true,
                    type: .backlight,
                    value: CGFloat(value),
                    icon: ""
                )
            }
        }
    }

    private func configureKeyboardBacklightCallback() {
        if keyboardBacklightEnabled {
            keyboardBacklightController.onBacklightChange = { [weak self] value in
                guard let self, self.keyboardBacklightEnabled else { return }
                self.sendKeyboardBacklightNotification(value: value)
            }
        } else {
            keyboardBacklightController.onBacklightChange = nil
        }
    }
}

private extension SystemChangesObserver {
    func stepSize(for step: MediaKeyStep, base: Float) -> Float {
        switch step {
        case .standard:
            return base
        case .fine:
            return base / fineStepDivisor
        }
    }
}


