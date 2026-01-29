/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * Originally from boring.notch project
 * Modified and adapted for Atoll (DynamicIsland)
 * See NOTICE for details.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import Cocoa
import Defaults
import Foundation
import IOKit.ps
import SwiftUI

/// A view model that manages and monitors the battery status of the device
class BatteryStatusViewModel: ObservableObject {

    private var wasCharging: Bool = false
    private var powerSourceChangedCallback: IOPowerSourceCallbackType?
    private var runLoopSource: Unmanaged<CFRunLoopSource>?
    var animations: DynamicIslandAnimations = DynamicIslandAnimations()
    private let lowBatteryAlertSoundPlayer = AudioPlayer()
    private let lowBatteryAlertThresholds: [Float] = [20, 15, 10, 5]

    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared

    @Published private(set) var levelBattery: Float = 0.0
    @Published private(set) var maxCapacity: Float = 0.0
    @Published private(set) var isPluggedIn: Bool = false
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var isInLowPowerMode: Bool = false
    @Published private(set) var isInitial: Bool = false
    @Published private(set) var timeToFullCharge: Int = 0
    @Published private(set) var statusText: String = ""

    private let managerBattery = BatteryActivityManager.shared
    private var managerBatteryId: Int?

    static let shared = BatteryStatusViewModel()

    /// Initializes the view model with a given BoringViewModel instance
    /// - Parameter vm: The BoringViewModel instance
    private init() {
        setupPowerStatus()
        setupMonitor()
    }

    /// Sets up the initial power status by fetching battery information
    private func setupPowerStatus() {
        let batteryInfo = managerBattery.initializeBatteryInfo()
        updateBatteryInfo(batteryInfo)
    }

    /// Sets up the monitor to observe battery events
    private func setupMonitor() {
        managerBatteryId = managerBattery.addObserver { [weak self] event in
            guard let self = self else { return }
            self.handleBatteryEvent(event)
        }
    }

    /// Handles battery events and updates the corresponding properties
    /// - Parameter event: The battery event to handle
    private func handleBatteryEvent(_ event: BatteryActivityManager.BatteryEvent) {
        switch event {
        case .powerSourceChanged(let isPluggedIn):
            print("🔌 Power source: \(isPluggedIn ? "Connected" : "Disconnected")")
            withAnimation {
                self.isPluggedIn = isPluggedIn
                self.statusText = isPluggedIn ? "Plugged In" : "Unplugged"
                self.notifyImportanChangeStatus()
            }

        case .batteryLevelChanged(let level):
            print("🔋 Battery level: \(Int(level))%")
            let previousLevel = self.levelBattery
            self.handleLowBatteryAlertIfNeeded(previousLevel: previousLevel, newLevel: level)
            withAnimation {
                self.levelBattery = level
            }

        case .lowPowerModeChanged(let isEnabled):
            print("⚡ Low power mode: \(isEnabled ? "Enabled" : "Disabled")")
            self.notifyImportanChangeStatus()
            withAnimation {
                self.isInLowPowerMode = isEnabled
                self.statusText = "Low Power: \(self.isInLowPowerMode ? "On" : "Off")"
            }

        case .isChargingChanged(let isCharging):
            print("🔌 Charging: \(isCharging ? "Yes" : "No")")
            print("maxCapacity: \(self.maxCapacity)")
            print("levelBattery: \(self.levelBattery)")
            self.notifyImportanChangeStatus()
            withAnimation {
                self.isCharging = isCharging
                self.statusText =
                    isCharging
                    ? "Charging battery"
                    : (self.levelBattery < self.maxCapacity ? "Not charging" : "Full charge")
            }

        case .timeToFullChargeChanged(let time):
            print("🕒 Time to full charge: \(time) minutes")
            withAnimation {
                self.timeToFullCharge = time
            }

        case .maxCapacityChanged(let capacity):
            print("🔋 Max capacity: \(capacity)")
            withAnimation {
                self.maxCapacity = capacity
            }

        case .error(let description):
            print("⚠️ Error: \(description)")
        }
    }

    /// Updates the battery information with the given BatteryInfo instance
    /// - Parameter batteryInfo: The BatteryInfo instance containing the battery data
    private func updateBatteryInfo(_ batteryInfo: BatteryInfo) {
        withAnimation {
            self.levelBattery = batteryInfo.currentCapacity
            self.isPluggedIn = batteryInfo.isPluggedIn
            self.isCharging = batteryInfo.isCharging
            self.isInLowPowerMode = batteryInfo.isInLowPowerMode
            self.timeToFullCharge = batteryInfo.timeToFullCharge
            self.maxCapacity = batteryInfo.maxCapacity
            self.statusText = batteryInfo.isPluggedIn ? "Plugged In" : "Unplugged"
        }
    }

    /// Notifies important changes in the battery status with an optional delay
    /// - Parameter delay: The delay before notifying the change, default is 0.0
    private func notifyImportanChangeStatus(delay: Double = 0.0) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            self.coordinator.toggleExpandingView(status: true, type: .battery)
        }
    }

    private func handleLowBatteryAlertIfNeeded(previousLevel: Float, newLevel: Float) {
        guard Defaults[.playLowBatteryAlertSound] else { return }
        guard !isPluggedIn, !isCharging else { return }
        guard newLevel < previousLevel else { return }

        for threshold in lowBatteryAlertThresholds {
            if previousLevel >= threshold && newLevel < threshold {
                self.statusText = "Low battery"
                notifyImportanChangeStatus()
                playLowBatteryAlertSound()
                break
            }
        }
    }

    private func playLowBatteryAlertSound() {
        lowBatteryAlertSoundPlayer.play(fileName: "lowbattery", fileExtension: "mp3")
    }

    deinit {
        print("🔌 Cleaning up battery monitoring...")
        if let managerBatteryId: Int = managerBatteryId {
            managerBattery.removeObserver(byId: managerBatteryId)
        }
    }

}
