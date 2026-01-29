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

import SwiftUI
import Defaults

struct LockScreenLiveActivity: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject private var lockScreenManager = LockScreenManager.shared
    @StateObject private var iconAnimator = LockIconAnimator(initiallyLocked: LockScreenManager.shared.isLocked)
    @State private var isHovering: Bool = false
    @State private var gestureProgress: CGFloat = 0
    @State private var isExpanded: Bool = false

    private var expandAnimation: Animation {
        .smooth(duration: LockScreenAnimationTimings.lockExpand)
    }

    private var collapseAnimation: Animation {
        .smooth(duration: LockScreenAnimationTimings.unlockCollapse)
    }

    private var iconColor: Color {
        .white
    }
    
    private var indicatorDimension: CGFloat {
        max(0, vm.effectiveClosedNotchHeight - 12)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left - Lock icon with subtle glow
            Color.clear
                .overlay(alignment: .leading) {
                    if isExpanded {
                        LockIconProgressView(progress: iconAnimator.progress, iconColor: iconColor)
                            .frame(width: indicatorDimension, height: indicatorDimension)
                    }
                }
                .frame(width: isExpanded ? max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12) + gestureProgress / 2) : 0, height: vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12))
            
            // Center - Black fill
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + (isHovering ? 8 : 0))
            
            // Right - Empty for symmetry with animation
            Color.clear
                .frame(width: isExpanded ? max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12) + gestureProgress / 2) : 0, height: vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12))
        }
        .frame(height: vm.effectiveClosedNotchHeight + (isHovering ? 8 : 0))
        .onAppear {
            iconAnimator.update(isLocked: lockScreenManager.isLocked, animated: false)
            let shouldStartExpanded = lockScreenManager.isLocked || !lockScreenManager.isLockIdle
            withAnimation(expandAnimation) {
                isExpanded = shouldStartExpanded
            }
        }
        .onDisappear {
            // Collapse immediately when removed from hierarchy
            isExpanded = false
        }
        .onChange(of: lockScreenManager.isLockIdle) { _, newValue in
            if newValue {
                withAnimation(collapseAnimation) {
                    isExpanded = false
                }
            } else if lockScreenManager.isLocked {
                withAnimation(expandAnimation) {
                    isExpanded = true
                }
            }
        }
        .onChange(of: lockScreenManager.isLocked) { _, newValue in
            iconAnimator.update(isLocked: newValue)
            if newValue {
                withAnimation(expandAnimation) {
                    isExpanded = true
                }
            } else {
                withAnimation(collapseAnimation) {
                    isExpanded = false
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: lockScreenManager.isLocked)
        .animation(.easeOut(duration: 0.25), value: isExpanded)
    }
}
