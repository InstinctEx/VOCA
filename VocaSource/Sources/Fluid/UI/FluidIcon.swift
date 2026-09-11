import SwiftUI

// Original public view interfaces are retained so every existing screen uses
// the VOCA mark without changes to navigation or behavior.
struct FluidIcon: View {
    let size: CGFloat
    let lineWidth: CGFloat
    let color: Color
    init(size: CGFloat = 24, lineWidth: CGFloat = 2.5, color: Color = .white) {
        self.size = size; self.lineWidth = lineWidth; self.color = color
    }
    var body: some View {
        HStack(spacing: size * 0.10) {
            ForEach(0..<5) { index in
                Capsule().fill(color)
                    .frame(width: max(1, min(lineWidth, size * 0.12)), height: size * [0.45, 0.75, 1.0, 0.75, 0.45][index])
            }
        }.frame(width: size, height: size).accessibilityLabel("VOCA")
    }
}
struct FluidIconFilled: View {
    let size: CGFloat
    let color: Color
    let backgroundColor: Color
    let cornerRadius: CGFloat
    init(size: CGFloat = 32, color: Color = .white, backgroundColor: Color = .blue, cornerRadius: CGFloat = 8) {
        self.size = size; self.color = color; self.backgroundColor = backgroundColor; self.cornerRadius = cornerRadius
    }
    var body: some View {
        FluidIcon(size: size * 0.56, lineWidth: size * 0.065, color: color)
            .frame(width: size, height: size)
            .background(backgroundColor.gradient, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}
struct FluidIconAdvanced: View {
    let size: CGFloat
    let color: Color
    init(size: CGFloat = 24, color: Color = .white) { self.size = size; self.color = color }
    var body: some View { FluidIcon(size: size, lineWidth: size * 0.10, color: color) }
}
