//
//  IdleAnimationManager.swift
//  DynamicIsland
//
//  Created by AI Assistant on 11/10/2025.
//  Manages custom idle animations (Lottie files) for the Atoll
//

import Foundation
import Defaults
import AppKit

class IdleAnimationManager {
    static let shared = IdleAnimationManager()
    
    // Storage directory for user-imported animations
    private let storageDirectory: URL
    
    private init() {
        // Create storage directory in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDirectory = appSupport.appendingPathComponent("DynamicIsland/IdleAnimations", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        
        print("📁 [IdleAnimationManager] Storage directory: \(storageDirectory.path)")
    }
    
    // MARK: - Initialization
    
    /// Load bundled animations from the LottieAnimations folder and built-in face
    func initializeDefaultAnimations() {
        var animations: [CustomIdleAnimation] = []
        
        // Add built-in face as first option
        let builtInFace = CustomIdleAnimation(
            name: "Classic Face",
            source: .builtInFace,
            speed: 1.0,
            isBuiltIn: true
        )
        animations.append(builtInFace)
        
        // Load bundled Lottie files
        if let bundledAnimations = loadBundledAnimations() {
            animations.append(contentsOf: bundledAnimations)
        }
        
        // Get existing animations
        var existing = Defaults[.customIdleAnimations]
        
        if existing.isEmpty {
            // First launch - set everything
            Defaults[.customIdleAnimations] = animations
            Defaults[.selectedIdleAnimation] = builtInFace
            print("✅ [IdleAnimationManager] First launch: Initialized with \(animations.count) animations")
        } else {
            // Subsequent launch - ensure all bundled animations are present
            let existingIDs = Set(existing.map { $0.id })
            let existingNames = Set(existing.filter { $0.isBuiltIn }.map { $0.name })
            
            // Add any missing bundled animations
            for bundledAnim in animations where bundledAnim.isBuiltIn {
                if !existingNames.contains(bundledAnim.name) {
                    existing.insert(bundledAnim, at: existing.firstIndex(where: { !$0.isBuiltIn }) ?? existing.count)
                    print("➕ [IdleAnimationManager] Added missing bundled animation: \(bundledAnim.name)")
                }
            }
            
            Defaults[.customIdleAnimations] = existing
            print("✅ [IdleAnimationManager] Subsequent launch: \(existing.count) total animations (\(animations.count - 1) bundled + built-in face)")
        }
    }
    
    // MARK: - Bundled Animations
    
    /// Load animations from the LottieAnimations folder in the bundle
    private func loadBundledAnimations() -> [CustomIdleAnimation]? {
        print("📦 [IdleAnimationManager] Loading bundled animations...")
        
        // The JSON files are added as individual resources, not in a folder
        let bundledFiles = ["Dog waiting", "Moody Dog", "Orange Cat Peeping"]
        var animations: [CustomIdleAnimation] = []
        
        for filename in bundledFiles {
            if let url = Bundle.main.url(forResource: filename, withExtension: "json") {
                let animation = CustomIdleAnimation(
                    name: filename,
                    source: .lottieFile(url),
                    speed: 1.0,
                    isBuiltIn: true
                )
                animations.append(animation)
                print("✅ [IdleAnimationManager] Loaded bundled animation: \(filename)")
            } else {
                print("⚠️ [IdleAnimationManager] Could not find bundled animation: \(filename).json")
            }
        }
        
        guard !animations.isEmpty else {
            print("⚠️ [IdleAnimationManager] No bundled animations found")
            return nil
        }
        
        print("📦 [IdleAnimationManager] Loaded \(animations.count) bundled animations")
        return animations
    }
    
    // MARK: - User Animations
    
    /// Load user-imported animations from storage directory
    private func loadStoredUserAnimations() -> [CustomIdleAnimation]? {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension.lowercased() == "json" }
            
            let animations = jsonFiles.map { url -> CustomIdleAnimation in
                let name = url.deletingPathExtension().lastPathComponent
                return CustomIdleAnimation(
                    name: name,
                    source: .lottieFile(url),
                    speed: 1.0,
                    isBuiltIn: false
                )
            }
            
            if !animations.isEmpty {
                print("💾 [IdleAnimationManager] Loaded \(animations.count) stored user animations")
            }
            return animations.isEmpty ? nil : animations
            
        } catch {
            print("❌ [IdleAnimationManager] Error loading stored animations: \(error)")
            return nil
        }
    }
    
    // MARK: - Import & Export
    
    /// Import a Lottie JSON file from URL (either local file or download from remote)
    func importLottieFile(from url: URL, name: String? = nil, speed: CGFloat = 1.0) -> Result<CustomIdleAnimation, Error> {
        let fileName = name ?? url.deletingPathExtension().lastPathComponent
        
        // If it's a remote URL, download it first
        if url.scheme == "http" || url.scheme == "https" {
            return importRemoteAnimation(from: url, name: fileName, speed: speed)
        }
        
        // Local file import
        return importLocalFile(from: url, name: fileName, speed: speed)
    }
    
    /// Import a local Lottie JSON file
    private func importLocalFile(from sourceURL: URL, name: String, speed: CGFloat) -> Result<CustomIdleAnimation, Error> {
        do {
            // Validate it's a JSON file
            guard sourceURL.pathExtension.lowercased() == "json" else {
                return .failure(AnimationImportError.invalidFileType)
            }
            
            // Validate JSON content (basic check)
            let data = try Data(contentsOf: sourceURL)
            guard let _ = try? JSONSerialization.jsonObject(with: data) else {
                return .failure(AnimationImportError.invalidJSON)
            }
            
            // Generate unique filename
            let uniqueFileName = "\(UUID().uuidString).json"
            let destinationURL = storageDirectory.appendingPathComponent(uniqueFileName)
            
            // Copy file to storage
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            
            // Create animation object (transforms will be stored separately)
            let animation = CustomIdleAnimation(
                name: name,
                source: .lottieFile(destinationURL),
                speed: speed,
                isBuiltIn: false
            )
            
            // Add to defaults
            var animations = Defaults[.customIdleAnimations]
            animations.append(animation)
            Defaults[.customIdleAnimations] = animations
            
            print("✅ [IdleAnimationManager] Imported local file: \(name)")
            return .success(animation)
            
        } catch {
            print("❌ [IdleAnimationManager] Import failed: \(error)")
            return .failure(error)
        }
    }
    
    /// Import animation from remote URL
    private func importRemoteAnimation(from url: URL, name: String, speed: CGFloat) -> Result<CustomIdleAnimation, Error> {
        // For remote URLs, we store the URL directly (no download)
        // The LottieView will handle downloading when needed
        
        let animation = CustomIdleAnimation(
            name: name,
            source: .lottieURL(url),
            speed: speed,
            isBuiltIn: false
        )
        
        // Add to defaults
        var animations = Defaults[.customIdleAnimations]
        animations.append(animation)
        Defaults[.customIdleAnimations] = animations
        
        print("✅ [IdleAnimationManager] Added remote animation: \(name)")
        return .success(animation)
    }
    
    // MARK: - Management
    
    /// Delete an animation (only user-added ones, not built-in)
    func deleteAnimation(_ animation: CustomIdleAnimation) -> Bool {
        guard !animation.isBuiltIn else {
            print("⚠️ [IdleAnimationManager] Cannot delete built-in animation")
            return false
        }
        
        // Remove from defaults
        var animations = Defaults[.customIdleAnimations]
        guard let index = animations.firstIndex(of: animation) else {
            return false
        }
        animations.remove(at: index)
        Defaults[.customIdleAnimations] = animations
        
        // If it's a local file, delete it from storage
        if case .lottieFile(let url) = animation.source {
            // Only delete if it's in our storage directory (not bundled)
            if url.path.contains(storageDirectory.path) {
                try? FileManager.default.removeItem(at: url)
                print("🗑️ [IdleAnimationManager] Deleted file: \(url.lastPathComponent)")
            }
        }
        
        // If deleted animation was selected, select the first one
        if Defaults[.selectedIdleAnimation] == animation {
            Defaults[.selectedIdleAnimation] = animations.first
        }
        
        print("✅ [IdleAnimationManager] Deleted animation: \(animation.name)")
        return true
    }
    
    /// Update animation properties
    func updateAnimation(_ animation: CustomIdleAnimation, name: String? = nil, speed: CGFloat? = nil) {
        var animations = Defaults[.customIdleAnimations]
        guard let index = animations.firstIndex(where: { $0.id == animation.id }) else {
            return
        }
        
        if let name = name {
            animations[index].name = name
        }
        if let speed = speed {
            animations[index].speed = speed
        }
        
        Defaults[.customIdleAnimations] = animations
        
        // Update selected animation if it's the same one
        if Defaults[.selectedIdleAnimation]?.id == animation.id {
            Defaults[.selectedIdleAnimation] = animations[index]
        }
        
        print("✅ [IdleAnimationManager] Updated animation: \(animation.name)")
    }
}

// MARK: - Error Types
enum AnimationImportError: LocalizedError {
    case invalidFileType
    case invalidJSON
    case downloadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidFileType:
            return "Only .json files are supported"
        case .invalidJSON:
            return "Invalid Lottie JSON format"
        case .downloadFailed:
            return "Failed to download animation"
        }
    }
}
