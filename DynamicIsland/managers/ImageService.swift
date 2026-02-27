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
import Defaults

public protocol ImageServiceProtocol {
    func fetchImageData(from url: URL) async throws -> Data
}

public final class ImageService: ImageServiceProtocol {
    public static let shared = ImageService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        
        // Create proper cache directory path
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let artworkCachePath = cacheDir.appendingPathComponent("artwork_cache").path
        
        let cache = URLCache(memoryCapacity: 50 * 1024 * 1024, // 50MB
                             diskCapacity: 100 * 1024 * 1024, // 100MB
                             diskPath: artworkCachePath)
        config.urlCache = cache
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpShouldSetCookies = false
        self.session = URLSession(configuration: config)

        performLegacyCacheCleanupIfNeeded()
    }

    private func performLegacyCacheCleanupIfNeeded() {

        if !Defaults[.didClearLegacyURLCacheV1] {
            URLCache.shared.removeAllCachedResponses()
            Defaults[.didClearLegacyURLCacheV1] = true
        }
    }

    public func fetchImageData(from url: URL) async throws -> Data {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw URLError(.unsupportedURL)
        }
        do {
            let (data, _) = try await session.data(from: url)
            return data
        } catch {
            let shouldFallbackToCurl: Bool
            if let urlError = error as? URLError {
                shouldFallbackToCurl = [
                    .cannotFindHost,
                    .dnsLookupFailed,
                    .cannotConnectToHost,
                    .networkConnectionLost,
                    .timedOut
                ].contains(urlError.code)
            } else {
                shouldFallbackToCurl = false
            }

            guard shouldFallbackToCurl else {
                throw error
            }

            NSLog("🔎 ImageService URLSession fetch failed (\(error.localizedDescription)); retrying with curl for \(url.absoluteString)")
            return try fetchImageDataWithCurl(from: url)
        }
    }

    private func fetchImageDataWithCurl(from url: URL) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = [
            "-fL",
            "--silent",
            "--show-error",
            "--max-time",
            "12",
            url.absoluteString
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus == 0, !outputData.isEmpty {
            return outputData
        }

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "curl failed"
        throw NSError(
            domain: NSURLErrorDomain,
            code: URLError.cannotFindHost.rawValue,
            userInfo: [NSLocalizedDescriptionKey: errorMessage]
        )
    }
}
