import SwiftUI

// MARK: - Background

/// Warm full-bleed background for a screen, palette-driven.
struct SpineBackground: View {
    @Environment(\.palette) private var p
    var body: some View {
        p.bg.ignoresSafeArea()
    }
}

// MARK: - Cover art

/// Striped placeholder cover keyed by a hue, matching the design's `cover()` primitive.
/// Real artwork drops in here later (Phase 2 wires Jellyfin image URLs).
struct CoverArt: View {
    let hue: Double
    var cornerRadius: CGFloat = 15
    var label: String? = "cover"
    var imageURL: URL? = nil

    private var top: Color { Color(hslHue: hue, saturation: 0.44, lightness: 0.46) }
    private var bottom: Color { Color(hslHue: hue, saturation: 0.38, lightness: 0.22) }

    var body: some View {
        ZStack {
            if let imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    gradient
                }
                .id(imageURL)   // force a fresh load when the URL changes on view reuse (e.g. list reorder)
            } else {
                gradient
                StripeTexture()
                    .blendMode(.overlay)
                    .opacity(0.5)
            }
            if let label, imageURL == nil {
                VStack {
                    Spacer()
                    HStack {
                        Text(label.uppercased())
                            .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(.white.opacity(0.72))
                        Spacer()
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 9)
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
    }

    private var gradient: some View {
        LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Subtle diagonal stripe texture used inside placeholder covers.
private struct StripeTexture: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 16
            let diagonal = size.width + size.height
            context.rotate(by: .degrees(45))
            var x: CGFloat = -size.height
            while x < diagonal {
                let rect = CGRect(x: x, y: -size.height, width: 8, height: diagonal * 2)
                context.fill(Path(rect), with: .color(.white.opacity(0.08)))
                x += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Glass

/// A translucent "Liquid Glass" surface — blur + hairline border + top highlight.
struct GlassPanel<Content: View>: View {
    @Environment(\.palette) private var p
    var cornerRadius: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(p.glassFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(p.glassBorder, lineWidth: 0.5)
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

// MARK: - Buttons

struct PillButton: View {
    @Environment(\.palette) private var p
    let title: String
    var systemImage: String? = nil
    var filled: Bool = false
    var height: CGFloat = 52
    var cornerRadius: CGFloat = 16
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 16, weight: .semibold))
                }
                Text(title).font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
        }
        .buttonStyle(PillButtonStyle(palette: p, filled: filled, cornerRadius: cornerRadius))
    }
}

private struct PillButtonStyle: ButtonStyle {
    let palette: Palette
    let filled: Bool
    let cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(filled ? palette.onAccent : palette.text)
            .background {
                if filled {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(palette.accent)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(palette.glassFill)
                        .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(palette.glassBorder, lineWidth: 0.5))
                }
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Progress

/// Thin amber-on-track progress bar.
struct ProgressBar: View {
    @Environment(\.palette) private var p
    var value: Double          // 0...1
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(p.track)
                Capsule().fill(p.accent)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    @Environment(\.palette) private var p
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(p.text)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 13))
                    .foregroundStyle(p.text3)
            }
        }
    }
}
