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

struct ColorPickerPopover: View {
    @ObservedObject var colorPickerManager = ColorPickerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "eyedropper.halffull")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Color Picker")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Main actions
            VStack(spacing: 12) {
                // Pick Color Button
                Button(action: {
                    colorPickerManager.startColorPicking()
                    dismiss() // Close popover when starting to pick
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text("Pick Color")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Show Panel Button
                Button(action: {
                    ColorPickerPanelManager.shared.showColorPickerPanel()
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.grid.2x2")
                            .font(.system(size: 14, weight: .medium))
                        Text("Show Color History")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Recent colors preview (if any)
            if !colorPickerManager.colorHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Colors")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                        ForEach(Array(colorPickerManager.colorHistory.prefix(12))) { color in
                            Button(action: {
                                colorPickerManager.copyToClipboard(color.hexString)
                                
                                if Defaults[.enableHaptics] {
                                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                                }
                                
                                dismiss()
                            }) {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.8), lineWidth: 1)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 240)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(12)
    }
}

#Preview {
    ColorPickerPopover()
        .onAppear {
            ColorPickerManager.shared.colorHistory = PickedColor.sampleColors
        }
}
