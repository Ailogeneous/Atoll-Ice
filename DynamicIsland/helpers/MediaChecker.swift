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

import Foundation

@MainActor
final class MediaChecker: Sendable {
    enum MediaCheckerError: Error {
        case missingResources
        case processExecutionFailed
        case timeout
    }

    func checkDeprecationStatus() async throws -> Bool {
        guard let scriptURL = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
              let nowPlayingTestClientPath = Bundle.main.url(forResource: "MediaRemoteAdapterTestClient", withExtension: nil)?.path,
              //let frameworkPath = Bundle.main.privateFrameworksPath?.appending("/MediaRemoteAdapter.framework")
              //let frameworkPath = Optional("/System/Library/PrivateFrameworks/MediaRemoteAdapter.framework")
                let frameworkPath =
                    Bundle.main.resourceURL?
                        .appendingPathComponent("MediaRemoteAdapter.framework")
                        .path
        else {
            throw MediaCheckerError.missingResources
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptURL.path, frameworkPath, nowPlayingTestClientPath, "test"]

        do {
            try process.run()
        } catch {
            throw MediaCheckerError.processExecutionFailed
        }

        // Timeout after 10 seconds
        let didExit: Bool = try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask {
                process.waitUntilExit()
                return true
            }
            group.addTask {
                try await Task.sleep(for: .seconds(10))
                if process.isRunning {
                    process.terminate()
                }
                return false
            }
            for try await exited in group {
                if exited {
                    group.cancelAll()
                    return true
                }
            }
            throw MediaCheckerError.timeout
        }

        if !didExit {
            throw MediaCheckerError.timeout
        }

        let isDeprecated = process.terminationStatus == 1
        return isDeprecated
    }
}
