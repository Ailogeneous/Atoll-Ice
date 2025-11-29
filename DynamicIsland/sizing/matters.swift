//
//
//  matters.swift
//  DynamicIsland
//
//
//  Created by Harsh Vardhan  Goswami  on 05/08/24.
//

import Defaults
import Foundation
import SwiftUI

let downloadSneakSize: CGSize = .init(width: 65, height: 1)
let batterySneakSize: CGSize = .init(width: 160, height: 1)

let openNotchSize: CGSize = .init(width: 640, height: 190)
private let minimalisticBaseOpenNotchSize: CGSize = .init(width: 420, height: 180)
private let minimalisticLyricsExtraHeight: CGFloat = 40
let minimalisticTimerCountdownTopPadding: CGFloat = 12
let minimalisticTimerCountdownContentHeight: CGFloat = 82
let minimalisticTimerCountdownBlockHeight: CGFloat = minimalisticTimerCountdownTopPadding + minimalisticTimerCountdownContentHeight
let statsSecondRowContentHeight: CGFloat = 120
let statsGridSpacingHeight: CGFloat = 12
let notchShadowPaddingStandard: CGFloat = 18
let notchShadowPaddingMinimalistic: CGFloat = 12

@MainActor
var minimalisticOpenNotchSize: CGSize {
    var size = minimalisticBaseOpenNotchSize

    if Defaults[.enableLyrics] {
        size.height += minimalisticLyricsExtraHeight
    }
    
    let reminderCount = ReminderLiveActivityManager.shared.activeWindowReminders.count
    if reminderCount > 0 {
        let reminderHeight = ReminderLiveActivityManager.additionalHeight(forRowCount: reminderCount)
        size.height += reminderHeight
    }

    if DynamicIslandViewCoordinator.shared.timerLiveActivityEnabled && TimerManager.shared.isExternalTimerActive {
        size.height += minimalisticTimerCountdownBlockHeight
    }

    return size
}
let cornerRadiusInsets: (opened: (top: CGFloat, bottom: CGFloat), closed: (top: CGFloat, bottom: CGFloat)) = (opened: (top: 19, bottom: 24), closed: (top: 6, bottom: 14))
let minimalisticCornerRadiusInsets: (opened: (top: CGFloat, bottom: CGFloat), closed: (top: CGFloat, bottom: CGFloat)) = (opened: (top: 35, bottom: 35), closed: cornerRadiusInsets.closed)

func statsAdjustedNotchSize(
    from baseSize: CGSize,
    isStatsTabActive: Bool,
    secondRowProgress: CGFloat
) -> CGSize {
    guard isStatsTabActive, Defaults[.enableStatsFeature] else {
        return baseSize
    }

    let enabledGraphsCount = [
        Defaults[.showCpuGraph],
        Defaults[.showMemoryGraph],
        Defaults[.showGpuGraph],
        Defaults[.showNetworkGraph],
        Defaults[.showDiskGraph]
    ].filter { $0 }.count

    guard enabledGraphsCount >= 4 else {
        return baseSize
    }

    let clampedProgress = max(0, min(secondRowProgress, 1))
    guard clampedProgress > 0 else {
        return baseSize
    }

    var adjustedSize = baseSize
    let extraHeight = (statsSecondRowContentHeight + statsGridSpacingHeight) * clampedProgress
    adjustedSize.height += extraHeight
    return adjustedSize
}

func notchShadowPaddingValue(isMinimalistic: Bool) -> CGFloat {
    isMinimalistic ? notchShadowPaddingMinimalistic : notchShadowPaddingStandard
}

func addShadowPadding(to size: CGSize, isMinimalistic: Bool) -> CGSize {
    CGSize(width: size.width, height: size.height + notchShadowPaddingValue(isMinimalistic: isMinimalistic))
}

enum MusicPlayerImageSizes {
    static let cornerRadiusInset: (opened: CGFloat, closed: CGFloat) = (opened: 13.0, closed: 4.0)
    static let size = (opened: CGSize(width: 90, height: 90), closed: CGSize(width: 20, height: 20))
}

func getScreenFrame(_ screen: String? = nil) -> CGRect? {
    var selectedScreen = NSScreen.main

    if let customScreen = screen {
        selectedScreen = NSScreen.screens.first(where: { $0.localizedName == customScreen })
    }
    
    if let screen = selectedScreen {
        return screen.frame
    }
    
    return nil
}

func getClosedNotchSize(screen: String? = nil) -> CGSize {
    // Default notch size, to avoid using optionals
    var notchHeight: CGFloat = Defaults[.nonNotchHeight]
    var notchWidth: CGFloat = 185

    var selectedScreen = NSScreen.main

    if let customScreen = screen {
        selectedScreen = NSScreen.screens.first(where: { $0.localizedName == customScreen })
    }

    // Check if the screen is available
    if let screen = selectedScreen {
        // Calculate and set the exact width of the notch
        if let topLeftNotchpadding: CGFloat = screen.auxiliaryTopLeftArea?.width,
           let topRightNotchpadding: CGFloat = screen.auxiliaryTopRightArea?.width
        {
            notchWidth = screen.frame.width - topLeftNotchpadding - topRightNotchpadding + 4
        }

        // Check if the Mac has a notch
        if screen.safeAreaInsets.top > 0 {
            // This is a display WITH a notch - use notch height settings
            notchHeight = Defaults[.notchHeight]
            if Defaults[.notchHeightMode] == .matchRealNotchSize {
                notchHeight = screen.safeAreaInsets.top
            } else if Defaults[.notchHeightMode] == .matchMenuBar {
                notchHeight = screen.frame.maxY - screen.visibleFrame.maxY
            }
        } else {
            // This is a display WITHOUT a notch - use non-notch height settings
            notchHeight = Defaults[.nonNotchHeight]
            if Defaults[.nonNotchHeightMode] == .matchMenuBar {
                notchHeight = screen.frame.maxY - screen.visibleFrame.maxY
            }
        }
    }

    return .init(width: notchWidth, height: notchHeight)
}
