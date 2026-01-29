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

struct ColorPickedFeedbackView: View {
    let color: PickedColor
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Color preview
            RoundedRectangle(cornerRadius: 12)
                .fill(color.color)
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 8)
            
            // Color info
            VStack(spacing: 4) {
                Text("Color Picked!")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(color.hexString)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(6)
            }
        }
        .padding(16)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 12)
        .scaleEffect(isShowing ? 1.0 : 0.8)
        .opacity(isShowing ? 1.0 : 0.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isShowing)
        .onTapGesture {
            // Copy to clipboard on tap
            ColorPickerManager.shared.copyToClipboard(color.hexString)
            
            if Defaults[.enableHaptics] {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            }
        }
    }
}

#Preview {
    ColorPickedFeedbackView(
        color: PickedColor(nsColor: NSColor.blue, point: CGPoint(x: 100, y: 100)),
        isShowing: .constant(true)
    )
    .frame(width: 300, height: 200)
}
