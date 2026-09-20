import SwiftUI

/// Live artwork and effect thumbnails. Sensor photos and video bypass this view.
struct ArtScene: View {
    let frame: UIImage?
    let effect: ArtEffect
    let time: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if let frame {
                    Image(uiImage: frame)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                if effect.category == .interfaces || effect.category == .systems {
                    NerdArtwork(effect: effect, time: time)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                } else {
                    Canvas { context, size in draw(in: &context, size: size) }
                }
            }
        }
        .clipped()
    }

    func color(_ offset: Double, opacity: Double = 1) -> Color {
        Color(hue: (time * 0.025 + offset).truncatingRemainder(dividingBy: 1), saturation: 0.85, brightness: 1)
            .opacity(opacity)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let unit = min(w, h)
        context.blendMode = .screen
        switch effect {
        case .clear:
            break
        case .orbit:
            for i in 0..<5 {
                let phase = time * 0.35 + Double(i) * .pi * 0.4
                let radius = unit * (0.12 + Double(i) * 0.023)
                let center = CGPoint(x: w * 0.5 + cos(phase) * w * 0.27, y: h * 0.5 + sin(phase * 1.3) * h * 0.27)
                let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                context.stroke(ring, with: .color(color(Double(i) * 0.16, opacity: 0.8)), lineWidth: 2.5)
                context.fill(Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)), with: .color(.white.opacity(0.9)))
            }
        case .ribbons:
            for i in 0..<6 {
                var path = Path()
                for step in 0...90 {
                    let x = w * Double(step) / 90
                    let y = h * (0.5 + 0.28 * sin(x / w * .pi * 2 + time * 0.55 + Double(i) * 0.5))
                    if step == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(path, with: .color(color(Double(i) * 0.09, opacity: 0.65)), style: StrokeStyle(lineWidth: unit * 0.015, lineCap: .round))
            }
        case .tunnel:
            for i in 0..<9 {
                let progress = (Double(i) / 9 + time * 0.09).truncatingRemainder(dividingBy: 1)
                var layer = context
                layer.translateBy(x: w / 2, y: h / 2)
                layer.rotate(by: .radians(time * 0.12 + progress * 0.8))
                let side = unit * (0.08 + progress * 1.45)
                let rect = CGRect(x: -side / 2, y: -side / 2, width: side, height: side)
                layer.stroke(Path(roundedRect: rect, cornerRadius: side * 0.04), with: .color(color(progress * 0.6, opacity: sin(progress * .pi))), lineWidth: 2.5)
            }
        case .prism:
            for i in 0..<3 {
                let phase = time * 0.23 + Double(i) * 2.094
                let center = CGPoint(x: w * (0.5 + 0.32 * cos(phase)), y: h * (0.5 + 0.3 * sin(phase * 0.8)))
                let radius = unit * 0.65
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
                    Gradient(colors: [color(Double(i) / 3, opacity: 0.55), .clear]),
                    center: center, startRadius: 0, endRadius: radius))
            }
        case .sparks:
            for i in 0..<45 {
                let seed = Double(i)
                let x = (seed * 0.61803398875 + sin(time * 0.17 + seed) * 0.08 + 1).truncatingRemainder(dividingBy: 1) * w
                let y = (seed * 0.381966 + time * (0.018 + Double(i % 4) * 0.007)).truncatingRemainder(dividingBy: 1) * h
                let radius = 1.5 + 3 * (0.5 + 0.5 * sin(time * 1.3 + seed))
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)), with: .color(color(seed * 0.021, opacity: 0.85)))
            }
        default:
            drawExpanded(in: &context, size: size)
        }
    }
}
