//
//  TimerPreset.swift
//  DynamicIsland
//
//  Created by GitHub Copilot on 2025-11-01.
//

import SwiftUI
import AppKit
import Defaults

struct TimerPreset: Identifiable, Codable, Hashable, Defaults.Serializable {
    struct ColorData: Codable, Hashable, Defaults.Serializable {
        var red: Double
        var green: Double
        var blue: Double
        var alpha: Double

        init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        init(color: Color) {
            let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
            self.red = nsColor.redComponent
            self.green = nsColor.greenComponent
            self.blue = nsColor.blueComponent
            self.alpha = nsColor.alphaComponent
        }

        var color: Color {
            Color(red: red, green: green, blue: blue, opacity: alpha)
        }
    }

    struct DurationComponents {
        var hours: Int
        var minutes: Int
        var seconds: Int
    }

    var id: UUID
    var name: String
    var duration: TimeInterval
    var colorData: ColorData

    init(id: UUID = UUID(), name: String, duration: TimeInterval, colorData: ColorData) {
        self.id = id
        self.name = name
        self.duration = duration
        self.colorData = colorData
    }

    init(id: UUID = UUID(), name: String, duration: TimeInterval, color: Color) {
        self.init(id: id, name: name, duration: duration, colorData: ColorData(color: color))
    }

    var color: Color {
        colorData.color
    }

    mutating func updateColor(_ newColor: Color) {
        colorData = ColorData(color: newColor)
    }

    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: duration) ?? "0:00"
    }

    static func components(for duration: TimeInterval) -> DurationComponents {
        let totalSeconds = max(0, Int(duration))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return DurationComponents(hours: hours, minutes: minutes, seconds: seconds)
    }

    static func duration(from components: DurationComponents) -> TimeInterval {
        TimeInterval(components.hours * 3600 + components.minutes * 60 + components.seconds)
    }

    static let defaultPresets: [TimerPreset] = [
        TimerPreset(name: "Focus", duration: 25 * 60, color: Color.orange),
        TimerPreset(name: "Break", duration: 5 * 60, color: Color.green),
        TimerPreset(name: "Deep Work", duration: 45 * 60, color: Color.purple)
    ]
}
