import SwiftUI
import UIKit

/// A single-line label that, only when the text overflows, gently scrolls once to
/// reveal the end, pauses, resets to the start, and repeats. Static otherwise.
struct MarqueeText: View {
    let text: String
    var size: CGFloat
    var weight: Font.Weight = .regular
    var color: Color = .primary
    var pointsPerSecond: Double = 18
    var startPause: Double = 1.8
    var endPause: Double = 1.2

    private var uiWeight: UIFont.Weight {
        switch weight {
        case .bold: return .bold
        case .semibold: return .semibold
        case .medium: return .medium
        case .heavy: return .heavy
        default: return .regular
        }
    }
    private var uiFont: UIFont { .systemFont(ofSize: size, weight: uiWeight) }
    private var textWidth: CGFloat { (text as NSString).size(withAttributes: [.font: uiFont]).width }
    private var font: Font { .system(size: size, weight: weight) }

    var body: some View {
        GeometryReader { geo in
            let overflow = max(0, textWidth - geo.size.width)
            if overflow > 0.5 {
                ScrollingLabel(text: text, font: font, color: color, overflow: overflow,
                               pointsPerSecond: pointsPerSecond, startPause: startPause, endPause: endPause)
                    .id(text)   // restart cleanly when the book changes
                    .frame(width: geo.size.width, alignment: .leading)
                    .clipped()
            } else {
                Text(text).font(font).foregroundStyle(color).lineLimit(1)
                    .frame(width: geo.size.width, alignment: .leading)
            }
        }
        .frame(height: uiFont.lineHeight)
    }
}

private struct ScrollingLabel: View {
    let text: String
    let font: Font
    let color: Color
    let overflow: CGFloat
    let pointsPerSecond: Double
    let startPause: Double
    let endPause: Double

    @State private var offset: CGFloat = 0

    var body: some View {
        Text(text).font(font).foregroundStyle(color).fixedSize()
            .offset(x: offset)
            .task { await cycle() }
    }

    private func cycle() async {
        // One round-trip then stop: reveal the end, pause, glide back to the start.
        let scrollDuration = max(2, Double(overflow) / pointsPerSecond)
        try? await Task.sleep(for: .seconds(startPause))
        guard !Task.isCancelled else { return }
        withAnimation(.linear(duration: scrollDuration)) { offset = -overflow }
        try? await Task.sleep(for: .seconds(scrollDuration + endPause))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.5)) { offset = 0 }
    }
}
