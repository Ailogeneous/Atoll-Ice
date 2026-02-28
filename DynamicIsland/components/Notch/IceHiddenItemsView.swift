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
import Defaults
import SwiftUI

struct IceHiddenItemsView: View {
    @EnvironmentObject var itemManager: MenuBarItemManager
    @EnvironmentObject var imageCache: MenuBarItemImageCache
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject private var reminderManager = ReminderLiveActivityManager.shared
    @AppStorage(IceDefaultsKey.enableNotchHiddenListMode.rawValue) private var enableNotchHiddenListMode = true
    @Default(.enableReminderLiveActivity) private var enableReminderLiveActivity
    @Default(.reminderSneakPeekDuration) private var reminderSneakPeekDuration
    @State private var lastKnownItems = [MenuBarItem]()
    @State private var missingExpectedHiddenCount = 0
    @State private var didInitialCenterScroll = false
    @State private var isHoveringItemList = false
    @State private var latchedReminderOverlayText: String?
    @State private var latchedReminderOverlayAccent: Color = .white
    @State private var overlayVisibleUntil: Date = .distantPast
    @State private var overlayDismissTask: Task<Void, Never>?
    @State private var isNotchTransitioning = false
    @State private var notchTransitionTask: Task<Void, Never>?
    private let reminderTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let virtualCopyCount = 5
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

    private var reminderOverlayEntry: ReminderLiveActivityManager.ReminderEntry? {
        guard enableReminderLiveActivity else { return nil }
        return reminderManager.activeReminder ?? reminderManager.activeWindowReminders.first
    }

    private var liveReminderOverlayText: String? {
        guard let reminder = reminderOverlayEntry else {
            return nil
        }
        return reminderSneakPeekText(for: reminder, now: reminderManager.currentDate)
    }

    private var liveReminderOverlayAccent: Color {
        guard let reminder = reminderOverlayEntry else {
            return .white
        }
        return reminderColor(for: reminder, now: reminderManager.currentDate)
    }

    private var reminderOverlayText: String? {
        if let liveReminderOverlayText {
            return liveReminderOverlayText
        }

        guard overlayVisibleUntil > Date() else {
            return nil
        }

        return latchedReminderOverlayText
    }

    private var reminderOverlayAccent: Color {
        if liveReminderOverlayText != nil {
            return liveReminderOverlayAccent
        }

        return latchedReminderOverlayAccent
    }

    private var reminderOverlaySignature: String {
        guard let entry = reminderOverlayEntry else { return "none" }
        let text = reminderSneakPeekText(for: entry, now: reminderManager.currentDate)
        return "\(entry.id)|\(text)"
    }

    private var shouldUseVirtualizedRepeats: Bool {
        enableNotchHiddenListMode && displayedItems.count > 1
    }

    private var virtualItemCount: Int {
        if shouldUseVirtualizedRepeats {
            return displayedItems.count * virtualCopyCount
        }
        return displayedItems.count
    }

    private var renderedItemIndices: Range<Int> {
        0..<virtualItemCount
    }

    private func renderedItem(for index: Int) -> MenuBarItem {
        if shouldUseVirtualizedRepeats {
            let baseIndex = index % displayedItems.count
            return displayedItems[baseIndex]
        }
        return displayedItems[index]
    }

    private func renderedItemID(for index: Int, item: MenuBarItem) -> String {
        if shouldUseVirtualizedRepeats {
            return "virtual-\(index)-\(item.windowID)-\(item.ownerPID)"
        }
        return "base-\(item.windowID)-\(item.ownerPID)"
    }

    private var centerItemID: String? {
        guard shouldUseVirtualizedRepeats else {
            return nil
        }
        let centerCopy = virtualCopyCount / 2
        let centerIndex = centerCopy * displayedItems.count
        guard renderedItemIndices.contains(centerIndex) else { return nil }
        let item = renderedItem(for: centerIndex)
        return renderedItemID(for: centerIndex, item: item)
    }

    private func updateMissingExpectedHiddenCount() {
        missingExpectedHiddenCount = itemManager.expectedHiddenMissingCount()
    }

    private func recoverExpectedHiddenItems(limit: Int?) {
        Task {
            _ = await itemManager.recoverExpectedHiddenItemsToPolicy(limit: limit)
            await itemManager.cacheItemsIfNeeded()

            if ScreenCapture.cachedCheckPermissions() {
                await imageCache.updateCacheWithoutChecks(sections: [.hidden])
            }

            await MainActor.run {
                updateMissingExpectedHiddenCount()
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
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 8) {
                            ForEach(renderedItemIndices, id: \.self) { index in
                                let item = renderedItem(for: index)
                                IceHiddenItemView(item: item)
                                    .id(renderedItemID(for: index, item: item))
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
                    .overlay {
                        GeometryReader { geo in
                            if let overlayText = reminderOverlayText {
                                let accent = reminderOverlayAccent
                                let frameWidth = max(0, geo.size.width - 20)

                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(accent)
                                        .frame(width: 8, height: 12)

                                    MarqueeText(
                                        .constant(overlayText),
                                        textColor: accent,
                                        minDuration: 1,
                                        frameWidth: frameWidth
                                    )
                                }
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(.black.opacity(0.8))
                                )
                                .opacity(isHoveringItemList ? 0 : 1)
                                .animation(.easeInOut(duration: 0.3), value: isHoveringItemList)
                            }
                        }
                        // Keep the hidden items list fully interactive under the overlay.
                        .allowsHitTesting(false)
                    }
                    .onHover { hovering in
                        isHoveringItemList = hovering
                    }
                    .contextMenu {
                        Button("Copy Section Widths") {
                            logMenuBarSectionWidths()
                        }
                        Divider()
                        Button("Open Ice Settings") {
                            AppDelegate.iceAppState.openSettingsWindow()
                        }
                        Button("Hard Reset Hidden List") {
                            Task {
                                await performHardResetHiddenList(itemManager: itemManager, imageCache: imageCache)
                            }
                        }
                    }
                    .onAppear {
                        Task {
                            await itemManager.cacheItemsIfNeeded()
                            await MainActor.run {
                                refreshReminderOverlayLatch()
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
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .allowsHitTesting(!isFullscreenBlackMenuBar)
        .onChange(of: isFullscreenBlackMenuBar) { _, isBlocked in
            if isBlocked {
                vm.isHoveringIceMenu = false
            }
        }
        .onReceive(refreshTimer) { _ in
            guard vm.notchState == .open, !isNotchTransitioning else { return }
            Task {
                await itemManager.cacheItemsIfNeeded()
                if ScreenCapture.cachedCheckPermissions() {
                    await imageCache.updateCacheWithoutChecks(sections: [.hidden])
                }
                await MainActor.run {
                    refreshReminderOverlayLatch()
                    if !items.isEmpty {
                        lastKnownItems = items
                    }
                    updateMissingExpectedHiddenCount()
                }
            }
        }
        .onChange(of: reminderOverlaySignature) { _, _ in
            refreshReminderOverlayLatch()
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
        .onChange(of: vm.notchState) { _, _ in
            notchTransitionTask?.cancel()
            isNotchTransitioning = true
            notchTransitionTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                isNotchTransitioning = false
            }
        }
        .onDisappear {
            notchTransitionTask?.cancel()
            notchTransitionTask = nil
            overlayDismissTask?.cancel()
            overlayDismissTask = nil
        }
    }

    private func reminderColor(for reminder: ReminderLiveActivityManager.ReminderEntry, now: Date) -> Color {
        let window = TimeInterval(reminderSneakPeekDuration)
        let remaining = reminder.event.start.timeIntervalSince(now)
        if remaining <= window {
            return .red
        }
        return Color(nsColor: reminder.event.calendar.color).ensureMinimumBrightness(factor: 0.7)
    }

    private func reminderSneakPeekText(for entry: ReminderLiveActivityManager.ReminderEntry, now: Date) -> String {
        let fallbackTitle: String = {
            switch entry.event.type {
            case .reminder:
                return "Upcoming Reminder"
            case .event, .birthday:
                return "Upcoming Event"
            }
        }()
        let title = entry.event.title.isEmpty ? fallbackTitle : entry.event.title
        let remaining = max(entry.event.start.timeIntervalSince(now), 0)
        let window = TimeInterval(reminderSneakPeekDuration)

        if window > 0 && remaining <= window {
            return "\(title) • now"
        }

        let minutes = Int(ceil(remaining / 60))
        let timeString = reminderTimeFormatter.string(from: entry.event.start)

        if minutes <= 0 {
            return "\(title) • now • \(timeString)"
        } else if minutes == 1 {
            return "\(title) • in 1 min • \(timeString)"
        } else {
            return "\(title) • in \(minutes) min • \(timeString)"
        }
    }

    private func refreshReminderOverlayLatch() {
        guard let liveReminderOverlayText else {
            if overlayVisibleUntil <= Date() {
                clearReminderOverlayLatch()
            }
            return
        }

        latchedReminderOverlayText = liveReminderOverlayText
        latchedReminderOverlayAccent = liveReminderOverlayAccent
        extendOverlayVisibility(for: liveReminderOverlayText)
    }

    private func extendOverlayVisibility(for text: String) {
        let hold = overlayHoldDuration(for: text)
        let target = Date().addingTimeInterval(hold)
        if target > overlayVisibleUntil {
            overlayVisibleUntil = target
        }
        scheduleOverlayDismiss()
    }

    private func scheduleOverlayDismiss() {
        overlayDismissTask?.cancel()
        let target = overlayVisibleUntil
        overlayDismissTask = Task { @MainActor in
            let delay = target.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard Date() >= self.overlayVisibleUntil else { return }
            self.clearReminderOverlayLatch()
        }
    }

    private func clearReminderOverlayLatch() {
        latchedReminderOverlayText = nil
        overlayVisibleUntil = .distantPast
    }

    private func overlayHoldDuration(for text: String) -> TimeInterval {
        let estimatedReadAndScroll = (Double(text.count) * 0.22) + 5.0
        return min(30, max(8, estimatedReadAndScroll))
    }

    private func logMenuBarSectionWidths() {
        let visibleWidth = sectionWidth(for: .visible)
        let hiddenWidth = sectionWidth(for: .hidden)
        let alwaysHiddenWidth = sectionWidth(for: .alwaysHidden)
        let total = visibleWidth + hiddenWidth + alwaysHiddenWidth
        let payload = "visible=\(formatWidth(visibleWidth)) hidden=\(formatWidth(hiddenWidth)) alwaysHidden=\(formatWidth(alwaysHiddenWidth)) total=\(formatWidth(total))"

        NSLog("🔎 IceHiddenItemsView section widths \(payload)")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(payload, forType: .string)
    }

    private func sectionWidth(for section: MenuBarSection.Name) -> CGFloat {
        itemManager.itemCache
            .managedItems(for: section)
            .reduce(0) { $0 + $1.frame.width }
    }

    private func formatWidth(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
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
                    .renderingMode(.template)
                    .foregroundStyle(.white.opacity(0.92))
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
                Button("Hard Reset Hidden List") {
                    Task {
                        await performHardResetHiddenList(itemManager: itemManager, imageCache: imageCache)
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
                Button("Hard Reset Hidden List") {
                    Task {
                        await performHardResetHiddenList(itemManager: itemManager, imageCache: imageCache)
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

private func performHardResetHiddenList(
    itemManager: MenuBarItemManager,
    imageCache: MenuBarItemImageCache
) async {
    await itemManager.forceRefreshCache(clearExisting: true)
    await itemManager.recoverTempShownItemsToHiddenSection()
    _ = await itemManager.recoverExpectedHiddenItemsToPolicy(limit: nil, includeOverflowHiddenItems: true)
    await itemManager.forceRefreshCache(clearExisting: true)
    await MainActor.run {
        itemManager.persistExpectedHiddenFromCurrentCache()
    }

    if ScreenCapture.cachedCheckPermissions() {
        await imageCache.updateCacheWithoutChecks(sections: MenuBarSection.Name.allCases)
    }
}
