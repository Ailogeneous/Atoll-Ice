//
//  TimerIconAnimation.swift
//  DynamicIsland
//
//  Created by Ebullioscopic on 2025-01-13.
//

import SwiftUI
import Defaults

struct TimerIconAnimation: View {
    @ObservedObject var timerManager = TimerManager.shared
    @Default(.timerIconColorMode) private var colorMode
    @Default(.timerSolidColor) private var solidColor
    @Default(.timerPresets) private var timerPresets
    @Default(.accentColor) private var accentColor
    
    var body: some View {
        ZStack {
            Circle()
                .fill(resolvedColor.gradient)
                .frame(width: 24, height: 24)
            
            Image(systemName: "timer")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    private var resolvedColor: Color {
        guard timerManager.isTimerActive else { return accentColor }
        switch colorMode {
        case .adaptive:
            if let presetId = timerManager.activePresetId,
               let preset = timerPresets.first(where: { $0.id == presetId }) {
                return preset.color
            }
            return timerManager.timerColor
        case .solid:
            return solidColor
        }
    }
}

struct TimerIconView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let hostingView = NSHostingView(rootView: TimerIconAnimation())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        return hostingView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let hostingView = nsView as? NSHostingView<TimerIconAnimation> {
            hostingView.rootView = TimerIconAnimation()
        }
    }
}

#Preview {
    TimerIconAnimation()
        .frame(width: 50, height: 50)
        .background(.black)
        .onAppear {
            // Start a demo timer for preview
            TimerManager.shared.startDemoTimer(duration: 300)
        }
}
