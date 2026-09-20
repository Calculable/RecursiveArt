import CoreImage

/// Gentle display-only motion. Clamped edges prevent transparent borders during drift.
struct SimulatedCameraMotion {
    private(set) var amplitude = 0.0
    private var lastTime: Double?

    mutating func render(_ image: CIImage, enabled: Bool, amount: Double, time: Double) -> CIImage {
        let target = enabled ? min(1, max(0, amount.isFinite ? amount : 0)) : 0
        let elapsed = lastTime.map { max(0, min(0.1, time - $0)) } ?? 0
        lastTime = time
        amplitude += (target - amplitude) * (1 - exp(-elapsed / 0.8))
        guard amplitude > 0.00001 else { amplitude = 0; return image }

        let bounds = image.extent
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let zoom = 1 + amplitude * (0.045 + 0.025 * sin(time * 0.37))
        let rotation = amplitude * 0.012 * sin(time * 0.29)
        let dx = bounds.width * amplitude * 0.012 * sin(time * 0.23)
        let dy = bounds.height * amplitude * 0.010 * sin(time * 0.31 + 0.8)
        let transform = CGAffineTransform(translationX: center.x + dx, y: center.y + dy)
            .rotated(by: rotation)
            .scaledBy(x: zoom, y: zoom)
            .translatedBy(x: -center.x, y: -center.y)
        return image.clampedToExtent()
            .applyingFilter("CIBumpDistortionLinear", parameters: [
                kCIInputCenterKey: CIVector(x: center.x + sin(time * 0.19) * bounds.width * 0.15, y: center.y),
                kCIInputRadiusKey: min(bounds.width, bounds.height) * 0.65,
                kCIInputAngleKey: sin(time * 0.17) * 0.4,
                kCIInputScaleKey: amplitude * 0.035 * sin(time * 0.41)
            ])
            .transformed(by: transform)
            .cropped(to: bounds)
    }
}
