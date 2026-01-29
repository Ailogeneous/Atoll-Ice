/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
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

import Foundation
import Combine
import Defaults

@MainActor
final class LockScreenReminderWidgetManager: ObservableObject {
    static let shared = LockScreenReminderWidgetManager()

    @Published private(set) var snapshot: LockScreenReminderWidgetSnapshot?

    private let reminderManager = ReminderLiveActivityManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        observeDefaults()
        observeLockState()
        observeReminderSnapshots()
    }

    private func observeLockState() {
        LockScreenManager.shared.$isLocked
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] locked in
                self?.handleLockStateChange(isLocked: locked)
            }
            .store(in: &cancellables)
    }

    private func observeReminderSnapshots() {
        reminderManager.$lockScreenSnapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.handleSnapshotUpdate(snapshot)
            }
            .store(in: &cancellables)
    }

    private func handleLockStateChange(isLocked: Bool) {
        Logger.log("LockScreenReminderWidgetManager: handleLockStateChange(isLocked: \(isLocked))", category: .lifecycle)
        guard Defaults[.enableLockScreenReminderWidget] else {
            LockScreenReminderWidgetPanelManager.shared.hide()
            return
        }

        if isLocked {
            if let latest = reminderManager.lockScreenSnapshot ?? snapshot {
                snapshot = latest
                LockScreenReminderWidgetPanelManager.shared.show(with: latest)
            } else {
                LockScreenReminderWidgetPanelManager.shared.hide()
            }
        } else {
            LockScreenReminderWidgetPanelManager.shared.hide()
        }
    }

    private func observeDefaults() {
        Defaults.publisher(.enableLockScreenReminderWidget, options: [])
            .sink { [weak self] change in
                guard let self else { return }
                if change.newValue {
                    if LockScreenManager.shared.currentLockStatus {
                        self.handleSnapshotUpdate(self.reminderManager.lockScreenSnapshot)
                    }
                } else {
                    self.snapshot = nil
                    LockScreenReminderWidgetPanelManager.shared.hide()
                }
            }
            .store(in: &cancellables)

        Defaults.publisher(.lockScreenReminderChipStyle, options: [])
            .sink { [weak self] _ in
                guard let self else { return }
                self.handleSnapshotUpdate(self.reminderManager.lockScreenSnapshot)
            }
            .store(in: &cancellables)
    }

    private func handleSnapshotUpdate(_ newSnapshot: LockScreenReminderWidgetSnapshot?) {
        guard Defaults[.enableLockScreenReminderWidget] else {
            snapshot = nil
            LockScreenReminderWidgetPanelManager.shared.hide()
            return
        }

        snapshot = newSnapshot

        guard LockScreenManager.shared.currentLockStatus else { return }

        if let newSnapshot {
            Logger.log("LockScreenReminderWidgetManager: Updating snapshot on lock screen", category: .ui)
            LockScreenReminderWidgetPanelManager.shared.show(with: newSnapshot)
        } else {
            LockScreenReminderWidgetPanelManager.shared.hide()
        }
    }

}

