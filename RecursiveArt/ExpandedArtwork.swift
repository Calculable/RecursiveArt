import SwiftUI

extension ArtScene {
    func drawExpanded(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height, u = min(w, h), t = time
        let center = CGPoint(x: w / 2, y: h / 2)
        if effect.category == .masks {
            drawMasks(in: &context, size: size)
            return
        }
        switch effect {
        case .spiral:
            for arm in 0..<3 {
                let points = (0...240).map { i in
                    let p = Double(i) / 240
                    return polar(center, u * p * 0.7, p * .pi * 9 + t * 0.35 + Double(arm) * 2.094)
                }
                context.stroke(line(points), with: .color(color(Double(arm) / 3)), lineWidth: 2)
            }
        case .mandala:
            for i in 0..<16 {
                var layer = context
                layer.translateBy(x: center.x, y: center.y)
                layer.rotate(by: .radians(Double(i) * .pi / 8 + t * 0.12))
                let petal = CGRect(x: 0, y: -u * 0.09, width: u * (0.38 + sin(t * 0.5) * 0.06), height: u * 0.18)
                layer.stroke(Path(ellipseIn: petal), with: .color(color(Double(i) / 16, opacity: 0.7)), lineWidth: 1.8)
            }
        case .lattice:
            for axis in 0..<2 {
                for row in 0...14 {
                    let points = (0...50).map { step in
                        let a = Double(step) / 50, b = Double(row) / 14
                        let wave = sin(a * 8 + t + b * 5) * 0.035
                        return axis == 0 ? CGPoint(x: a * w, y: (b + wave) * h) : CGPoint(x: (b + wave) * w, y: a * h)
                    }
                    context.stroke(line(points), with: .color(color(Double(row) / 18, opacity: 0.55)), lineWidth: 1)
                }
            }
        case .moire:
            for field in 0..<2 {
                var layer = context
                layer.translateBy(x: center.x, y: center.y)
                layer.rotate(by: .radians(Double(field) * (0.12 + sin(t * 0.2) * 0.2)))
                let span = max(w, h) * 1.5
                for i in -65...65 {
                    let x = Double(i) * u / 45 + sin(t * 0.3 + Double(field)) * 12
                    layer.stroke(line([CGPoint(x: x, y: -span), CGPoint(x: x, y: span)]), with: .color(color(Double(field) * 0.45, opacity: 0.5)), lineWidth: 1)
                }
            }
        case .radar:
            for ring in 1...5 {
                context.stroke(circle(center, Double(ring) * u * 0.09), with: .color(.green.opacity(0.35)), lineWidth: 1)
            }
            for i in 0..<28 {
                let angle = t * 0.8 - Double(i) * 0.015
                context.stroke(line([center, polar(center, u * 0.46, angle)]), with: .color(.green.opacity(0.65 * (1 - Double(i) / 28))), lineWidth: 2)
            }
        case .diamonds:
            for i in 0..<16 {
                let f = Double(i)
                let p = CGPoint(x: fraction(f * 0.618 + t * 0.025) * w, y: fraction(f * 0.381 - t * 0.04) * h)
                let points = (0..<4).map { polar(p, u * (0.04 + Double(i % 3) * 0.025), t * 0.4 + f + Double($0) * .pi / 2) }
                context.stroke(line(points, closed: true), with: .color(color(f * 0.06)), lineWidth: 2)
            }
        case .starburst:
            let origin = CGPoint(x: w * (0.5 + sin(t * 0.3) * 0.18), y: h * (0.5 + cos(t * 0.23) * 0.18))
            for i in 0..<48 {
                let a = Double(i) * .pi / 24 + t * 0.08
                context.stroke(line([polar(origin, u * 0.08, a), polar(origin, max(w, h), a)]), with: .color(color(Double(i) / 48, opacity: 0.45)), lineWidth: i % 4 == 0 ? 3 : 1)
            }
        case .hexagons:
            let r = u / 11
            for row in -1...Int(h / (r * 1.73)) + 1 {
                for col in -1...8 {
                    let p = CGPoint(x: Double(col) * r * 1.5, y: (Double(row) + (col % 2 == 0 ? 0 : 0.5)) * r * 1.732)
                    let radius = r * (0.82 + 0.14 * sin(t + Double(row + col) * 0.5))
                    context.stroke(line((0..<6).map { polar(p, radius, Double($0) * .pi / 3) }, closed: true), with: .color(color(Double(row + col + 10) * 0.035, opacity: 0.65)), lineWidth: 1.5)
                }
            }
        case .aurora:
            for i in 0..<32 {
                let f = Double(i) / 32
                let points = (0...70).map { step in
                    let x = Double(step) / 70
                    return CGPoint(x: x * w, y: h * (0.35 + 0.16 * sin(x * 6 + t * 0.4) + 0.06 * sin(x * 15 - t * 0.3) + f * 0.22))
                }
                context.stroke(line(points), with: .color(Color(hue: 0.35 + f * 0.3, saturation: 0.8, brightness: 1).opacity(sin(f * .pi) * 0.28)), lineWidth: 5)
            }
        case .neonRain:
            for col in 0..<22 {
                for segment in 0..<8 {
                    let x = (Double(col) + 0.5) / 22 * w
                    let y = fraction(Double(col) * 0.618 + t * (0.09 + Double(col % 4) * 0.025) - Double(segment) * 0.018) * h
                    context.stroke(line([CGPoint(x: x, y: y), CGPoint(x: x, y: y + h * 0.012)]), with: .color(color(Double(col) / 22, opacity: 1 - Double(segment) / 9)), lineWidth: 3)
                }
            }
        case .laserSweep:
            for i in 0..<4 {
                let f = Double(i), x = w * (0.5 + sin(t * 0.55 + f) * 0.48), y = h * (0.5 + cos(t * 0.43 + f * 2) * 0.48)
                let beam = line([CGPoint(x: x, y: 0), CGPoint(x: w - x, y: h)])
                context.stroke(beam, with: .color(color(f / 4, opacity: 0.12)), lineWidth: 15)
                context.stroke(beam, with: .color(color(f / 4)), lineWidth: 1.5)
                context.stroke(line([CGPoint(x: 0, y: y), CGPoint(x: w, y: h - y)]), with: .color(color(f / 4, opacity: 0.8)), lineWidth: 1)
            }
        case .lightning:
            let phase = fraction(t * 0.65)
            if phase < 0.22 {
                let tick = floor(t * 0.65)
                for bolt in 0..<3 {
                    let points = (0...16).map { i in
                        CGPoint(x: w * (0.2 + Double(bolt) * 0.3 + (noise(Double(i) + tick * 17 + Double(bolt)) - 0.5) * 0.2), y: Double(i) / 16 * h)
                    }
                    context.stroke(line(points), with: .color(.cyan.opacity(0.16)), lineWidth: 14)
                    context.stroke(line(points), with: .color(.white.opacity(0.85)), lineWidth: 2)
                    for branch in [5, 10] {
                        let p = points[branch]
                        context.stroke(line([p, CGPoint(x: p.x + w * 0.12, y: p.y + h * 0.05), CGPoint(x: p.x + w * 0.18, y: p.y + h * 0.16)]), with: .color(.cyan.opacity(0.65)), lineWidth: 1)
                    }
                }
            }
        case .bokeh:
            for i in 0..<16 {
                let f = Double(i)
                let p = CGPoint(x: fraction(f * 0.618 + sin(t * 0.13 + f) * 0.15) * w, y: fraction(f * 0.39 - t * 0.012) * h)
                let r = u * (0.04 + noise(f) * 0.1)
                context.fill(circle(p, r), with: .radialGradient(Gradient(colors: [color(f / 16, opacity: 0.22), color(f / 16, opacity: 0.1), .clear]), center: p, startRadius: 0, endRadius: r))
                context.stroke(circle(p, r * 0.82), with: .color(color(f / 16, opacity: 0.18)), lineWidth: 1)
            }
        case .comet:
            for comet in 0..<4 {
                for tail in (0..<35).reversed() {
                    let a = t * 0.5 + Double(comet) * .pi / 2 - Double(tail) * 0.025
                    let p = CGPoint(x: w * (0.5 + cos(a) * 0.38), y: h * (0.5 + sin(a * 1.4) * 0.36))
                    context.fill(circle(p, u * 0.012 * (1 - Double(tail) / 40)), with: .color(color(Double(comet) / 4, opacity: 1 - Double(tail) / 35)))
                }
            }
        case .fireflies:
            for i in 0..<55 {
                let f = Double(i)
                let p = CGPoint(x: fraction(noise(f) + sin(t * 0.18 + f) * 0.08) * w, y: fraction(noise(f + 90) + cos(t * 0.15 + f) * 0.09) * h)
                let alpha = pow(max(0, sin(t * 1.4 + f * 2.3)), 3)
                context.fill(circle(p, 8), with: .radialGradient(Gradient(colors: [.yellow.opacity(alpha), .clear]), center: p, startRadius: 0, endRadius: 8))
            }
        case .confetti:
            for i in 0..<65 {
                let f = Double(i)
                var layer = context
                layer.translateBy(x: fraction(noise(f) + sin(t + f) * 0.035) * w, y: fraction(noise(f + 13) + t * (0.035 + noise(f + 7) * 0.06)) * h)
                layer.rotate(by: .radians(t * 1.4 + f))
                layer.fill(Path(CGRect(x: -3, y: -6, width: 6 + sin(t + f) * 3, height: 12)), with: .color(color(f / 65, opacity: 0.85)))
            }
        case .snowfall, .embers:
            for i in 0..<80 {
                let f = Double(i), speed = 0.02 + noise(f + 7) * 0.05
                let y = fraction(noise(f + 50) + t * speed * (effect == .embers ? -1 : 1))
                let x = fraction(noise(f) + sin(t * 0.4 + f) * 0.045)
                let tint: Color = effect == .embers ? Color(hue: 0.025 + noise(f) * 0.1, saturation: 0.9, brightness: 1).opacity(y * 0.8) : .white.opacity(0.4 + noise(f) * 0.6)
                context.fill(circle(CGPoint(x: x * w, y: y * h), 1 + noise(f + 3) * 3), with: .color(tint))
            }
        case .bubbles:
            for i in 0..<24 {
                let f = Double(i), r = u * (0.02 + noise(f + 9) * 0.06)
                let p = CGPoint(x: fraction(noise(f) + sin(t * 0.4 + f) * 0.035) * w, y: fraction(noise(f + 5) - t * 0.045) * (h + r * 2) - r)
                context.stroke(circle(p, r), with: .color(color(f / 24, opacity: 0.6)), lineWidth: 1.5)
                context.fill(circle(CGPoint(x: p.x - r * 0.3, y: p.y - r * 0.4), r * 0.12), with: .color(.white.opacity(0.8)))
            }
        case .meteors:
            for i in 0..<18 {
                let f = Double(i), p = fraction(t * 0.22 + f * 0.618)
                let head = CGPoint(x: (fraction(f * 0.38) + p * 0.55) * w, y: p * h * 1.3 - h * 0.15)
                for tail in 0..<12 {
                    let offset = Double(tail)
                    context.fill(circle(CGPoint(x: head.x - offset * 4, y: head.y - offset * 7), 2.5 - offset * 0.12), with: .color(.cyan.opacity(1 - offset / 12)))
                }
            }
        case .starfield:
            for i in 0..<90 {
                let f = Double(i), p = fraction(f * 0.618 + t * 0.18), angle = noise(f) * .pi * 2
                let r = p * p * max(w, h) * 0.8
                context.stroke(line([polar(center, r, angle), polar(center, r + p * p * u * 0.06, angle)]), with: .color(.white.opacity(p)), lineWidth: 0.5 + p * 2)
            }
        case .fire:
            for i in 0..<28 {
                let f = Double(i), x = (f + 0.5) / 28 * w
                let height = h * (0.15 + noise(f) * 0.28 + sin(t * 1.8 + f) * 0.08)
                var flame = Path()
                flame.move(to: CGPoint(x: x - w / 28, y: h))
                flame.addQuadCurve(to: CGPoint(x: x + sin(t * 2 + f) * 25, y: h - height), control: CGPoint(x: x - 35, y: h - height * 0.5))
                flame.addQuadCurve(to: CGPoint(x: x + w / 28, y: h), control: CGPoint(x: x + 35, y: h - height * 0.3))
                context.fill(flame, with: .linearGradient(Gradient(colors: [.orange.opacity(0.6), .red.opacity(0)]), startPoint: CGPoint(x: x, y: h), endPoint: CGPoint(x: x, y: h - height)))
            }
        case .fountain:
            for i in 0..<100 {
                let f = Double(i), age = fraction(t * 0.35 + f * 0.618)
                let vx = (noise(f) - 0.5) * w * 1.2
                let p = CGPoint(x: w / 2 + vx * age, y: h * 0.92 - h * 2.2 * age + h * 2.2 * age * age)
                context.fill(circle(p, 2.5), with: .color(color(f / 100, opacity: 1 - age * 0.7)))
            }
        case .constellation:
            let points = (0..<27).map { i in
                CGPoint(x: (0.5 + sin(Double(i) * 5.7 + t * 0.12) * 0.47) * w, y: (0.5 + cos(Double(i) * 2.3 + t * 0.15) * 0.47) * h)
            }
            for i in points.indices {
                context.fill(circle(points[i], 2.5), with: .color(.white))
                for j in (i + 1)..<points.count {
                    let distance = hypot(points[i].x - points[j].x, points[i].y - points[j].y)
                    if distance < u * 0.32 {
                        context.stroke(line([points[i], points[j]]), with: .color(.cyan.opacity((1 - distance / (u * 0.32)) * 0.65)), lineWidth: 1)
                    }
                }
            }
        case .vortex:
            for i in 0..<160 {
                let f = Double(i), p = fraction(f * 0.618 - t * 0.08)
                let point = polar(center, p * u * 0.75, f * 2.4 + t * 0.5 + (1 - p) * 7)
                context.fill(circle(point, 1 + p * 3), with: .color(color(p, opacity: p * 0.8)))
            }
        case .pulse:
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(color(0, opacity: 0.08 + (sin(t * 0.75) + 1) * 0.16)))
        case .blink:
            let phase = Int(floor(t * 1.25)) % 4
            let points = [CGPoint(x: 0, y: 0), CGPoint(x: w, y: 0), CGPoint(x: w, y: h), CGPoint(x: 0, y: h)]
            for i in 0..<4 where i == phase || i == (phase + 2) % 4 {
                context.fill(circle(points[i], u * 0.22), with: .color(color(Double(i) / 4, opacity: 0.65)))
            }
        case .checker:
            let side = u / 8, phase = Int(floor(t * 0.8))
            for row in 0...Int(h / side) {
                for col in 0...Int(w / side) where (row + col + phase) % 2 == 0 {
                    context.fill(Path(CGRect(x: Double(col) * side, y: Double(row) * side, width: side, height: side)), with: .color(color(Double(row + col) * 0.04, opacity: 0.3)))
                }
            }
        case .shutter:
            context.blendMode = .normal
            let height = h / 14, opening = (0.5 + 0.5 * sin(t * 0.8)) * 0.9
            for row in 0..<14 {
                context.fill(Path(CGRect(x: 0, y: Double(row) * height, width: w, height: height * (1 - opening))), with: .color(.black.opacity(0.85)))
            }
        case .scanlines:
            context.blendMode = .normal
            for y in stride(from: 0.0, to: h, by: 5) {
                context.fill(Path(CGRect(x: 0, y: y, width: w, height: 1.5)), with: .color(.black.opacity(0.4)))
            }
            context.blendMode = .screen
            let y = fraction(t * 0.12) * h
            context.fill(Path(CGRect(x: 0, y: y - 20, width: w, height: 40)), with: .linearGradient(Gradient(colors: [.clear, .green.opacity(0.2), .clear]), startPoint: CGPoint(x: 0, y: y - 20), endPoint: CGPoint(x: 0, y: y + 20)))
        case .equalizer:
            for i in 0..<28 {
                let f = Double(i), height = h * (0.05 + abs(sin(t * 1.4 + f * 0.6) * cos(t * 0.7 + f * 0.3)) * 0.4)
                context.fill(Path(CGRect(x: f / 28 * w, y: h - height, width: w / 28 - 2, height: height)), with: .linearGradient(Gradient(colors: [color(f / 28, opacity: 0.8), .clear]), startPoint: CGPoint(x: 0, y: h), endPoint: CGPoint(x: 0, y: h - height)))
            }
        case .interference:
            for row in 0..<28 {
                for col in 0..<20 {
                    let x = Double(col) / 19, y = Double(row) / 27
                    let wave = sin(x * 19 + t) * cos(y * 22 - t * 0.7)
                    context.fill(circle(CGPoint(x: x * w, y: y * h), 1 + abs(wave) * 5), with: .color(color((wave + 1) * 0.35, opacity: abs(wave) * 0.7)))
                }
            }
        case .heartbeat:
            let points = (0...180).map { i in
                let x = Double(i) / 180, p = fraction(x - t * 0.23)
                let spike = exp(-pow((p - 0.5) * 55, 2)) - 0.45 * exp(-pow((p - 0.54) * 65, 2))
                return CGPoint(x: x * w, y: h * 0.5 - spike * h * 0.23)
            }
            context.stroke(line(points), with: .color(.pink.opacity(0.2)), lineWidth: 10)
            context.stroke(line(points), with: .color(.pink), lineWidth: 2)
            for i in 0..<3 {
                let p = fraction(t * 0.45 + Double(i) / 3)
                context.stroke(circle(center, u * p * 0.6), with: .color(.pink.opacity((1 - p) * 0.5)), lineWidth: 1)
            }
        case .eclipse:
            let r = u * 0.24
            context.fill(circle(center, r * 1.7), with: .radialGradient(Gradient(colors: [color(0, opacity: 0.8), .clear]), center: center, startRadius: r * 0.7, endRadius: r * 1.7))
            context.blendMode = .normal
            let moon = CGPoint(x: center.x + sin(t * 0.3) * r * 0.6, y: center.y)
            context.fill(circle(moon, r), with: .color(.black.opacity(0.9)))
            context.stroke(circle(moon, r), with: .color(color(0.2)), lineWidth: 1)
        default:
            break // Camera distortions are already baked into the incoming frame.
        }
    }

    private func fraction(_ value: Double) -> Double { value - floor(value) }
    private func noise(_ seed: Double) -> Double { fraction(sin(seed * 127.1 + 31.7) * 43758.5453) }
    private func polar(_ center: CGPoint, _ radius: Double, _ angle: Double) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
    private func circle(_ center: CGPoint, _ radius: Double) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
    private func line(_ points: [CGPoint], closed: Bool = false) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
            if closed { path.closeSubpath() }
        }
    }
}
