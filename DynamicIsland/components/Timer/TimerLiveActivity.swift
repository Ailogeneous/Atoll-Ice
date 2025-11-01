//
//  TimerLiveActivity.swift
//  DynamicIsland
//
//  Created by Ebullioscopic on 2025-01-13.
//

import SwiftUI
import Defaults

struct TimerLiveActivity: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject var timerManager = TimerManager.shared
    @State private var isHovering: Bool = false
    @Default(.timerShowsCountdown) private var showsCountdown
    @Default(.timerShowsProgress) private var showsProgress
    @Default(.timerProgressStyle) private var progressStyle
    @Default(.timerIconColorMode) private var colorMode
    @Default(.timerSolidColor) private var solidColor
    @Default(.timerPresets) private var timerPresets
    
    private var iconAreaWidth: CGFloat {
        max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12))
    }

    private var countdownWidth: CGFloat {
        guard showsCountdown else { return 0 }
        let characters = max(timerManager.formattedRemainingTime().count, 4)
        let base = CGFloat(characters) * 9.5 + 24
        return max(base, 72)
    }

    private var clampedProgress: Double {
        min(max(timerManager.progress, 0), 1)
    }

    private var glyphColor: Color {
        switch colorMode {
        case .adaptive:
            return activePresetColor ?? timerManager.timerColor
        case .solid:
            return solidColor
        }
    }

    private var showsRingProgress: Bool {
        showsProgress && progressStyle == .ring
    }

    private var showsBarProgress: Bool {
        showsProgress && progressStyle == .bar
    }

    private var activePresetColor: Color? {
        guard let presetId = timerManager.activePresetId else { return nil }
        return timerPresets.first { $0.id == presetId }?.color
    }
    
    var body: some View {
        HStack(spacing: 10) {
            iconSection
            infoSection
            if showsRingProgress {
                ringSection
            }
            if showsCountdown {
                countdownSection
            }
        }
        .frame(height: vm.effectiveClosedNotchHeight + (isHovering ? 8 : 0), alignment: .center)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.18)) {
                isHovering = hovering
            }
        }
    }
    
    private var iconSection: some View {
        let iconSize = max(20, iconAreaWidth - 4)
        return Image(systemName: "timer")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(glyphColor)
            .frame(width: iconSize, height: iconSize)
            .frame(width: iconAreaWidth, height: max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12)), alignment: .center)
    }
    
    private var infoSection: some View {
        Rectangle()
            .fill(.black)
            .overlay(
                VStack(alignment: .leading, spacing: 4) {
                    if timerManager.isFinished || timerManager.isOvertime {
                        GeometryReader { geo in
                            MarqueeText(
                                .constant(timerManager.timerName),
                                textColor: .white,
                                minDuration: 0.25,
                                frameWidth: geo.size.width - 12
                            )
                        }
                        .frame(height: 16)
                    } else {
                        Text(timerManager.timerName)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .foregroundStyle(.white)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .animation(.smooth, value: timerManager.isFinished)
            )
            .frame(width: vm.closedNotchSize.width + (isHovering ? 8 : 0))
    }
    
    private var ringSection: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(glyphColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.25), value: clampedProgress)
        }
        .frame(width: 26, height: 26)
    }
    
    private var countdownSection: some View {
        VStack(spacing: 4) {
            Text(timerManager.formattedRemainingTime())
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(timerManager.isOvertime ? .red : .white)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.25), value: timerManager.remainingTime)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            if showsBarProgress {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(glyphColor)
                            .frame(width: max(0, countdownWidth - 20) * max(0, CGFloat(clampedProgress)))
                            .animation(.smooth(duration: 0.25), value: clampedProgress)
                    }
            }
        }
        .padding(.trailing, 8)
        .frame(width: countdownWidth,
               height: max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12)), alignment: .center)
    }
}

#Preview {
    TimerLiveActivity()
        .environmentObject(DynamicIslandViewModel())
        .frame(width: 300, height: 32)
        .background(.black)
        .onAppear {
            TimerManager.shared.startDemoTimer(duration: 300)
        }
}
