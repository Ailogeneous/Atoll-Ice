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

import AppKit
import Combine
import Foundation

enum FullDiskAccessAuthorization {
    private static let probeURLs: [URL] = [
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"),
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/DoNotDisturb/DB/ModeConfigurations.json")
    ]

    static func hasPermission() -> Bool {
        for url in probeURLs {
            if canReadProtectedResource(at: url) {
                return true
            }
        }
        return false
    }

    private static func canReadProtectedResource(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return false
        }

        do {
            let handle = try FileHandle(forReadingFrom: url)
            try handle.close()
            return true
        } catch {
            return false
        }
    }
}

@MainActor
final class FullDiskAccessPermissionStore: ObservableObject {
    static let shared = FullDiskAccessPermissionStore()

    @Published private(set) var isAuthorized: Bool = FullDiskAccessAuthorization.hasPermission()

    private var pollingTask: Task<Void, Never>?

    private init() {}

    deinit {
        pollingTask?.cancel()
    }

    func refreshStatus() {
        updateAuthorizationStatus(to: FullDiskAccessAuthorization.hasPermission())
    }

    func requestAccessPrompt() {
#if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Full Disk Access Required"
        alert.informativeText = "Dynamic Island needs Full Disk Access to detect custom Focus indicators and power the Shelf. Click Continue to open Full Disk Access settings, then press the + button and select Dynamic Island (we'll reveal it in Finder for you)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            openSystemSettings()
            revealAppBundleInFinder()
        }
#endif
        beginPollingForStatusChanges()
    }

    func openSystemSettings() {
#if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
#endif
    }

    private func revealAppBundleInFinder() {
#if os(macOS)
        let bundleURL = Bundle.main.bundleURL
        NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
#endif
    }

    private func beginPollingForStatusChanges() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }

            for _ in 0..<40 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let status = FullDiskAccessAuthorization.hasPermission()

                await MainActor.run {
                    self.updateAuthorizationStatus(to: status)
                }

                if status {
                    break
                }
            }
        }
    }

    private func updateAuthorizationStatus(to newValue: Bool) {
        guard newValue != isAuthorized else { return }
        isAuthorized = newValue
    }
}
