//
//  IceSliderView.swift
//  Ice
//

import SwiftUI

struct IceSliderView<Value: BinaryFloatingPoint, ValueLabel: View>: View where Value.Stride: BinaryFloatingPoint {
    private let value: Binding<Value>
    private let bounds: ClosedRange<Value>
    private let step: Value.Stride
    private let valueLabel: ValueLabel

    init(
        value: Binding<Value>,
        in bounds: ClosedRange<Value> = 0...1,
        step: Value.Stride = 0.01,
        @ViewBuilder valueLabel: () -> ValueLabel
    ) {
        self.value = value
        self.bounds = bounds
        self.step = step
        self.valueLabel = valueLabel()
    }

    init(
        _ valueLabelKey: LocalizedStringKey,
        value: Binding<Value>,
        in bounds: ClosedRange<Value> = 0...1,
        step: Value.Stride = 0.01
    ) where ValueLabel == Text {
        self.init(
            value: value,
            in: bounds,
            step: step
        ) {
            Text(valueLabelKey)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.1))
            
            Slider(
                value: value,
                in: bounds,
                step: step
            )
            .opacity(0.2) // Make the slider less intrusive
            
            valueLabel
                .allowsHitTesting(false)
                .padding(.horizontal, 8)
        }
        .frame(height: 22)
    }
}
