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
import SwiftUI

struct IceHiddenItemsView: View {
    @EnvironmentObject var itemManager: MenuBarItemManager
    @EnvironmentObject var imageCache: MenuBarItemImageCache
    @EnvironmentObject var vm: DynamicIslandViewModel
    @AppStorage(IceDefaultsKey.enableNotchHiddenListMode.rawValue) private var enableNotchHiddenListMode = true
    @State private var lastKnownItems = [MenuBarItem]()
    @State private var isRecoveringExpectedHidden = false
    @State private var missingExpectedHiddenCount = 0
    @State private var didInitialCenterScroll = false
    @State private var lastRecoveryTriggerDate = Date.distantPast
    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let recoveryTriggerInterval: TimeInterval = 1
    private let infiniteRepeatCopies = 15
    private let edgeFadeWidth: CGFloat = 72
    
    var items: [MenuBarItem] {
        itemManager.itemCache.managedItems(for: .hidden)
    }

    var displayedItems: [MenuBarItem] {
        items.isEmpty ? lastKnownItems : items
    }

    private var appState: AppState {
        AppDelegate.iceAppState
    }

    private var isFullscreenBlackMenuBar: Bool {
        appState.isActiveSpaceFullscreen && appState.menuBarManager.isMenuBarHiddenBySystem
    }

    private struct RenderedHiddenItem: Identifiable {
        let id: String
        let item: MenuBarItem
    }

    private var renderedItems: [RenderedHiddenItem] {
        guard enableNotchHiddenListMode, displayedItems.count > 1 else {
            return displayedItems.map { item in
                RenderedHiddenItem(id: "base-\(item.windowID)-\(item.ownerPID)", item: item)
            }
        }

        return (0..<infiniteRepeatCopies).flatMap { copy in
            displayedItems.enumerated().map { index, item in
                RenderedHiddenItem(
                    id: "copy-\(copy)-\(index)-\(item.windowID)-\(item.ownerPID)",
                    item: item
                )
            }
        }
    }

    private var centerItemID: String? {
        guard enableNotchHiddenListMode, displayedItems.count > 1 else {
            return nil
        }
        let centerCopy = infiniteRepeatCopies / 2
        guard let first = displayedItems.first else {
            return nil
        }
        return "copy-\(centerCopy)-0-\(first.windowID)-\(first.ownerPID)"
    }

    private func updateMissingExpectedHiddenCount() {
        missingExpectedHiddenCount = itemManager.expectedHiddenMissingCount()
    }

    private func recoverExpectedHiddenItems(limit: Int?) {
        guard !isRecoveringExpectedHidden else {
            return
        }

        Task {
            await MainActor.run {
                isRecoveringExpectedHidden = true
            }

            _ = await itemManager.recoverExpectedHiddenItemsToPolicy(limit: limit)
            await itemManager.cacheItemsIfNeeded()

            if ScreenCapture.cachedCheckPermissions() {
                await imageCache.updateCacheWithoutChecks(sections: [.hidden])
            }

            await MainActor.run {
                isRecoveringExpectedHidden = false
                updateMissingExpectedHiddenCount()
            }
        }
    }

    private func triggerExpectedHiddenRecoveryIfNeeded() {
        guard !enableNotchHiddenListMode else { return }
        guard vm.notchState == .open else { return }
        guard vm.isHoveringIceMenu else { return }
        guard !isFullscreenBlackMenuBar else { return }
        guard !isRecoveringExpectedHidden else { return }
        guard Date.now.timeIntervalSince(lastRecoveryTriggerDate) >= recoveryTriggerInterval else { return }

        lastRecoveryTriggerDate = .now

        Task {
            guard  itemManager.hasExpectedHiddenMismatch() else {
                return
            }

            await MainActor.run {
                isRecoveringExpectedHidden = true
            }

            let didRecover = await itemManager.recoverExpectedHiddenItemsToPolicy()

            await itemManager.cacheItemsIfNeeded()
            if ScreenCapture.cachedCheckPermissions() {
                await imageCache.updateCacheWithoutChecks(sections: [.hidden])
            }

            await MainActor.run {
                isRecoveringExpectedHidden = false
                if didRecover, vm.notchState == .open {
                    withAnimation(.smooth) {
                        vm.close()
                    }
                }
            }
        }
    }
    
    var body: some View {
        Group {
            if displayedItems.isEmpty {
                EmptyView()
                    .onAppear {
                        Task {
                            await itemManager.cacheItemsIfNeeded()
                        }
                    }
            } else if isRecoveringExpectedHidden {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Recovering hidden items…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .frame(height: 32)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(renderedItems) { rendered in
                                IceHiddenItemView(item: rendered.item)
                                    .id(rendered.id)
                            }

                            if enableNotchHiddenListMode, missingExpectedHiddenCount > 0 {
                                ForEach(0..<missingExpectedHiddenCount, id: \.self) { index in
                                    Button {
                                        recoverExpectedHiddenItems(limit: 1)
                                    } label: {
                                        Image(systemName: "arrow.clockwise.circle.fill")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.85))
                                            .frame(width: 18, height: 18)
                                    }
                                    .buttonStyle(.plain)
                                    .contentShape(Rectangle())
                                    .help("Recover missing icon \(index + 1)")
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .visualEffect { content, geo in
                            let frame = geo.frame(in: .scrollView)
                            return content.offset(y: -frame.minY)
                        }
                    }
                    .frame(height: 32)
                    .fixedSize(horizontal: false, vertical: true)
                    .clipped()
                    .overlay(alignment: .leading) {
                        LinearGradient(
                            colors: [.black.opacity(0.9), .black.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: edgeFadeWidth)
                        .allowsHitTesting(false)
                    }
                    .overlay(alignment: .trailing) {
                        LinearGradient(
                            colors: [.black.opacity(0), .black.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: edgeFadeWidth)
                        .allowsHitTesting(false)
                    }
                    .contextMenu {
                        Button("Open Ice Settings") {
                            AppDelegate.iceAppState.openSettingsWindow()
                        }
                        Button("Recover Hidden Items") {
                            if enableNotchHiddenListMode {
                                recoverExpectedHiddenItems(limit: nil)
                            } else {
                                Task {
                                    await itemManager.recoverTempShownItemsToHiddenSection()
                                    await itemManager.cacheItemsIfNeeded()
                                    if ScreenCapture.cachedCheckPermissions() {
                                        await imageCache.updateCacheWithoutChecks(sections: [.hidden])
                                    }
                                }
                            }
                        }
                    }
                    .onAppear {
                        Task {
                            await itemManager.cacheItemsIfNeeded()
                            await MainActor.run {
                                updateMissingExpectedHiddenCount()
                                if !didInitialCenterScroll, let centerItemID {
                                    didInitialCenterScroll = true
                                    proxy.scrollTo(centerItemID, anchor: .center)
                                }
                            }
                        }
                    }
                    .onChange(of: displayedItems.map(\.windowID)) { _, _ in
                        updateMissingExpectedHiddenCount()
                        guard enableNotchHiddenListMode, let centerItemID else {
                            return
                        }
                        DispatchQueue.main.async {
                            proxy.scrollTo(centerItemID, anchor: .center)
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .allowsHitTesting(!isFullscreenBlackMenuBar && !isRecoveringExpectedHidden)
        .onChange(of: isFullscreenBlackMenuBar) { _, isBlocked in
            if isBlocked {
                vm.isHoveringIceMenu = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSScrollView.didLiveScrollNotification)) { _ in
            triggerExpectedHiddenRecoveryIfNeeded()
        }
        .onReceive(refreshTimer) { _ in
            guard vm.notchState == .open else { return }
            guard !isRecoveringExpectedHidden else { return }
            Task {
                await itemManager.cacheItemsIfNeeded()
                if ScreenCapture.cachedCheckPermissions() {
                    await imageCache.updateCacheWithoutChecks(sections: [.hidden])
                }
                await MainActor.run {
                    if !items.isEmpty {
                        lastKnownItems = items
                    }
                    updateMissingExpectedHiddenCount()
                }
            }
        }
        .onChange(of: items.map(\.windowID)) { _, newWindowIDs in
            guard !newWindowIDs.isEmpty else { return }
            lastKnownItems = items
            updateMissingExpectedHiddenCount()
        }
        .onChange(of: enableNotchHiddenListMode) { _, _ in
            didInitialCenterScroll = false
            updateMissingExpectedHiddenCount()
        }
    }
}

struct IceHiddenItemView: View {
    @EnvironmentObject var imageCache: MenuBarItemImageCache
    @EnvironmentObject var itemManager: MenuBarItemManager
    @EnvironmentObject var vm: DynamicIslandViewModel
    
    let item: MenuBarItem

    private func waitForMenuWindowOpen(ownerPID: pid_t, baselineWindowIDs: Set<CGWindowID>) async {
        MouseCursor.lockUserCursorControl()
        MouseCursor.hide()
        defer {
            MouseCursor.show()
            MouseCursor.unlockUserCursorControl()
        }

        let popupLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        let timeout = Date.now.addingTimeInterval(0.8)

        while Date.now < timeout {
            let windows = WindowInfo.getOnScreenWindows(excludeDesktopWindows: true)
            let didOpenMenu = windows.contains { window in
                window.ownerPID == ownerPID &&
                window.isOnScreen &&
                (
                    !baselineWindowIDs.contains(window.windowID) ||
                    window.layer == popupLevel
                ) &&
                window.layer != kCGStatusWindowLevel
            }

            if didOpenMenu {
                return
            }

            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    private func moveToRecentHiddenPositionAndClick(
        item resolvedItem: MenuBarItem,
        mouseButton: CGMouseButton,
        buttonName: String
    ) async {
        let allItems = MenuBarItem.getMenuBarItems(onScreenOnly: false, activeSpaceOnly: true)

        guard let hiddenControl = allItems.first(where: { $0.info == .hiddenControlItem }) else {
            NSLog("🔎 IceHiddenItemsView \(buttonName) click missing hidden control; direct click fallback")
            try? await itemManager.click(item: resolvedItem, with: mouseButton)
            return
        }

        let itemToActOn = allItems.first {
            $0.windowID == resolvedItem.windowID ||
            $0.info == resolvedItem.info ||
            ($0.ownerPID == resolvedItem.ownerPID && $0.title == resolvedItem.title)
        } ?? resolvedItem

        if
            let hiddenSection = AppDelegate.iceAppState.menuBarManager.section(withName: .hidden),
            hiddenSection.isHidden
        {
            await MainActor.run {
                hiddenSection.show()
            }
            try? await Task.sleep(for: .milliseconds(120))
        }

        do {
            try await itemManager.slowMove(item: itemToActOn, to: .leftOfItem(hiddenControl))
        } catch {
            NSLog("🔎 IceHiddenItemsView \(buttonName) move-to-recent failed item=\(itemToActOn.logString) error=\(error)")
        }

        let latest = MenuBarItem(windowID: itemToActOn.windowID) ?? itemToActOn
        let baselineWindowIDs = Set(
            WindowInfo.getOnScreenWindows(excludeDesktopWindows: true)
                .filter { $0.ownerPID == latest.ownerPID }
                .map(\.windowID)
        )

        do {
            try await itemManager.click(item: latest, with: mouseButton)
            await waitForMenuWindowOpen(ownerPID: latest.ownerPID, baselineWindowIDs: baselineWindowIDs)
        } catch {
            NSLog("🔎 IceHiddenItemsView \(buttonName) direct click failed after move item=\(latest.logString) error=\(error)")
        }
    }
    
    private var image: NSImage? {
        guard let image = imageCache.images[item.info],
              let screen = imageCache.screen else {
            return nil
        }
        let size = CGSize(
            width: CGFloat(image.width) / screen.backingScaleFactor,
            height: CGFloat(image.height) / screen.backingScaleFactor
        )
        return NSImage(cgImage: image, size: size)
    }
    
    var body: some View {
        if let image {
            Button {
                triggerClick(.left)
            } label: {
                Image(nsImage: image)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .contextMenu {
                Button("Open Menu Item") {
                    triggerClick(.left)
                }
                Button("Right Click Menu Item") {
                    triggerClick(.right)
                }
                Divider()
                Button("Open Ice Settings") {
                    AppDelegate.iceAppState.openSettingsWindow()
                }
                Button("Recover Hidden Items") {
                    Task {
                        await itemManager.recoverTempShownItemsToHiddenSection()
                    }
                }
            }
            .help(item.displayName)
        } else {
            Button {
                triggerClick(.left)
            } label: {
                Image(systemName: "app.badge")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .contextMenu {
                Button("Open Menu Item") {
                    triggerClick(.left)
                }
                Button("Right Click Menu Item") {
                    triggerClick(.right)
                }
                Divider()
                Button("Open Ice Settings") {
                    AppDelegate.iceAppState.openSettingsWindow()
                }
                Button("Recover Hidden Items") {
                    Task {
                        await itemManager.recoverTempShownItemsToHiddenSection()
                    }
                }
            }
            .help(item.displayName)
        }
    }

    private func triggerClick(_ mouseButton: CGMouseButton) {
        Task {
            let buttonName = mouseButton == .left ? "left" : "right"
            NSLog("🔎 IceHiddenItemsView \(buttonName) click item=\(item.logString) windowID=\(item.windowID)")
            try? await Task.sleep(for: .milliseconds(120))
            await MainActor.run {
                if vm.notchState == .open {
                    NSLog("🔎 IceHiddenItemsView \(buttonName) click collapsing notch before item trigger")
                    withAnimation(.smooth) {
                        vm.close()
                    }
                }
            }
            try? await Task.sleep(for: .milliseconds(220))
            await itemManager.cacheItemsIfNeeded()
            if ScreenCapture.cachedCheckPermissions() {
                await imageCache.updateCacheWithoutChecks(sections: [.hidden])
            }
            try? await Task.sleep(for: .milliseconds(25))
            let resolvedItem = await MainActor.run {
                let hiddenItems = itemManager.itemCache.managedItems(for: .hidden)
                return hiddenItems.first {
                    $0.windowID == item.windowID ||
                    $0.info == item.info ||
                    ($0.ownerPID == item.ownerPID && $0.title == item.title)
                } ?? MenuBarItem(windowID: item.windowID) ?? item
            }
            NSLog("🔎 IceHiddenItemsView \(buttonName) click resolved item=\(resolvedItem.logString) windowID=\(resolvedItem.windowID)")
            await moveToRecentHiddenPositionAndClick(
                item: resolvedItem,
                mouseButton: mouseButton,
                buttonName: buttonName
            )
        }
    }
}
