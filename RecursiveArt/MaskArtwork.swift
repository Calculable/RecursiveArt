import SwiftUI

extension ArtScene {
    func drawMasks(in context: inout GraphicsContext, size: CGSize) {
        context.blendMode = .normal // These shapes occlude the camera, rather than add light.
        let w = size.width, h = size.height, u = min(w, h), t = time
        let bounds = CGRect(origin: .zero, size: size)
        switch effect {
        case .colorCurtains:
            let width = w / 7
            for i in 0..<7 {
                let f = Double(i), coverage = 0.65 + 0.25 * sin(t * 0.65 + f * 0.8)
                context.fill(Path(CGRect(x: f * width, y: 0, width: width * coverage, height: h)), with: .color(color(f / 7)))
            }
        case .inkBlobs:
            for i in 0..<9 {
                let f = Double(i)
                let center = CGPoint(x: w * (0.5 + sin(t * 0.25 + f * 2.1) * 0.5), y: h * (0.5 + cos(t * 0.2 + f * 1.7) * 0.5))
                var blob = Path()
                for step in 0...90 {
                    let a = Double(step) / 90 * .pi * 2
                    let radius = u * (0.22 + 0.06 * sin(a * 3 + t + f) + 0.025 * cos(a * 5 - t))
                    let p = CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius)
                    if step == 0 { blob.move(to: p) } else { blob.addLine(to: p) }
                }
                blob.closeSubpath()
                context.fill(blob, with: .color(color(f / 9)))
            }
        case .mosaic:
            let side = u / 6
            for row in 0...Int(h / side) {
                for col in 0...Int(w / side) {
                    let wave = sin(Double(row) * 0.9 + Double(col) * 1.3 + t * 0.7)
                    if wave > -0.45 {
                        let rect = CGRect(x: Double(col) * side, y: Double(row) * side, width: side + 1, height: side + 1)
                        context.fill(Path(rect), with: .color(color(Double(row + col + 1) * 0.07)))
                    }
                }
            }
        case .iris:
            var mask = Path(bounds)
            let r = u * (0.18 + 0.09 * (1 + sin(t * 0.5)))
            let center = CGPoint(x: w * (0.5 + sin(t * 0.21) * 0.2), y: h * (0.5 + cos(t * 0.27) * 0.18))
            mask.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            context.fill(mask, with: .color(color(0.15)), style: FillStyle(eoFill: true))
        case .wipes:
            let x = w * (0.5 + sin(t * 0.45) * 0.65)
            let y = h * (0.5 + cos(t * 0.35) * 0.65)
            context.fill(Path(CGRect(x: x - w * 0.4, y: 0, width: w * 0.55, height: h)), with: .color(color(0)))
            context.fill(Path(CGRect(x: 0, y: y - h * 0.25, width: w, height: h * 0.45)), with: .color(color(0.5)))
        case .solidWaves:
            for i in 0..<4 {
                let f = Double(i)
                var wave = Path()
                wave.move(to: CGPoint(x: 0, y: h))
                for step in 0...80 {
                    let x = Double(step) / 80
                    let y = h * (0.3 + f * 0.14 + sin(x * 7 + t * 0.6 + f) * 0.12)
                    wave.addLine(to: CGPoint(x: x * w, y: y))
                }
                wave.addLine(to: CGPoint(x: w, y: h))
                wave.closeSubpath()
                context.fill(wave, with: .color(color(f * 0.18)))
            }
        case .paperCut:
            for i in 0..<12 {
                let f = Double(i)
                var layer = context
                layer.translateBy(x: w * (0.5 + sin(f * 2.4 + t * 0.13) * 0.52), y: h * (0.5 + cos(f * 1.8 + t * 0.17) * 0.5))
                layer.rotate(by: .radians(t * 0.22 + f))
                var paper = Path()
                paper.move(to: CGPoint(x: -u * 0.3, y: -u * 0.12))
                paper.addLine(to: CGPoint(x: u * 0.18, y: -u * 0.2))
                paper.addLine(to: CGPoint(x: u * 0.3, y: u * 0.14))
                paper.addLine(to: CGPoint(x: -u * 0.24, y: u * 0.25))
                paper.closeSubpath()
                layer.fill(paper, with: .color(color(f / 12)))
            }
        case .checkerBlocks:
            let side = u / 4
            for row in -1...Int(h / side) + 1 {
                for col in -1...5 where (row + col) % 2 == 0 {
                    var layer = context
                    layer.translateBy(x: (Double(col) + 0.5) * side, y: (Double(row) + 0.5) * side)
                    layer.rotate(by: .radians(sin(t * 0.6) * .pi / 3))
                    layer.fill(Path(CGRect(x: -side * 0.62, y: -side * 0.62, width: side * 1.24, height: side * 1.24)), with: .color(color(Double(row + col + 10) * 0.06)))
                }
            }
        case .petalShutter:
            for i in 0..<10 {
                let f = Double(i), a = f * .pi / 5 + t * 0.12
                let distance = u * (0.35 + sin(t * 0.55) * 0.15)
                var layer = context
                layer.translateBy(x: w / 2 + cos(a) * distance, y: h / 2 + sin(a) * distance)
                layer.rotate(by: .radians(a))
                layer.fill(Path(ellipseIn: CGRect(x: -u * 0.2, y: -u * 0.16, width: u * 0.8, height: u * 0.32)), with: .color(color(f / 10)))
            }
        case .liquidIslands:
            var mask = Path(bounds)
            for i in 0..<5 {
                let f = Double(i)
                let x = w * (0.5 + sin(t * 0.18 + f * 2) * 0.36), y = h * (0.5 + cos(t * 0.23 + f * 1.6) * 0.38)
                let r = u * (0.09 + 0.035 * (1 + sin(t * 0.7 + f)))
                mask.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            context.fill(mask, with: .color(color(0.6)), style: FillStyle(eoFill: true))
        default: break
        }
    }
}
