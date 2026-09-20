import CoreImage

/// Display-only controls: sensor photos and video never pass through this stage.
enum FeedbackMode: String, CaseIterable, Identifiable, Sendable {
    case off = "Off", stabilize = "Stabilize", colorFlow = "Color flow"
    var id: String { rawValue }
}

struct FeedbackBalance {
    private(set) var gains = SIMD3<Double>(repeating: 1)
    private var lastSampleTime: Double?

    mutating func reset() {
        gains = SIMD3(repeating: 1)
        lastSampleTime = nil
    }

    mutating func update(mean: SIMD3<Double>, elapsed: Double) {
        guard mean.x.isFinite, mean.y.isFinite, mean.z.isFinite, elapsed > 0 else { return }
        let average = (mean.x + mean.y + mean.z) / 3
        guard average > 0.025 else { return } // Do not chase noise in darkness.
        let alpha = 1 - exp(-min(elapsed, 1) / 8)
        for channel in 0..<3 {
            let target = min(1.12, max(0.68, average / max(mean[channel], 0.02)))
            gains[channel] += (target - gains[channel]) * alpha
        }
    }

    mutating func apply(to image: CIImage, mode: FeedbackMode, time: Double, context: CIContext) -> CIImage {
        guard mode != .off else { reset(); return image }
        if lastSampleTime == nil || time - lastSampleTime! >= 0.25 {
            let area = image.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: image.extent)])
            var rgba = [Float](repeating: 0, count: 4)
            context.render(area, toBitmap: &rgba, rowBytes: 16, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: CGColorSpaceCreateDeviceRGB())
            update(mean: SIMD3(Double(rgba[0]), Double(rgba[1]), Double(rgba[2])), elapsed: lastSampleTime.map { time - $0 } ?? 0.25)
            lastSampleTime = time
        }
        var result = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: gains.x, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: gains.y, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: gains.z, w: 0)
        ]).applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.97])
        if mode == .colorFlow {
            result = result.applyingFilter("CIHueAdjust", parameters: [kCIInputAngleKey: time * .pi / 90])
        }
        return result.cropped(to: image.extent)
    }
}
