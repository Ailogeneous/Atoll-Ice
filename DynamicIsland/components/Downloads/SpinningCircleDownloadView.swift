import SwiftUI

struct SpinningCircleDownloadView: View {
    @State private var isRotating = false
    
    var body: some View {
        ZStack {
            // Gray track
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 3.5)
            
            // Blue spinning segment
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(Angle(degrees: isRotating ? 360 : 0))
                .onAppear {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        isRotating = true
                    }
                }
        }
        .frame(width: 16, height: 16)
    }
}
