import AVFoundation

/// Computes bounded changes in stops, so bright/dark scenes receive the same
/// gradual response. A dead band prevents small metering errors from hunting.
enum ExposureRamp {
    static func step(offset: Double, elapsed: Double, response: Double) -> Double {
        guard offset.isFinite, elapsed.isFinite, elapsed > 0, response.isFinite else { return 0 }
        guard abs(offset) > 0.12 else { return 0 }
        let seconds = min(12, max(1, response))
        let dt = min(0.25, elapsed)
        let limit = dt / seconds
        return min(limit, max(-limit, -offset * (1 - exp(-dt / seconds))))
    }

    static func settings(iso: Double, duration: Double, stops: Double,
                         isoRange: ClosedRange<Double>, durationRange: ClosedRange<Double>) -> (iso: Double, duration: Double) {
        let baseDuration = min(durationRange.upperBound, max(durationRange.lowerBound, duration))
        let energy = iso * duration * pow(2, stops)
        let nextISO = min(isoRange.upperBound, max(isoRange.lowerBound, energy / baseDuration))
        let nextDuration = min(durationRange.upperBound, max(durationRange.lowerBound, energy / nextISO))
        return (nextISO, nextDuration)
    }
}

/// Owned exclusively by the camera queue. Controls actual sensor exposure;
/// it does not just darken or brighten an already auto-exposed preview.
final class SlowExposure {
    var enabled = false
    var response = 5.0
    private var originalMode: AVCaptureDevice.ExposureMode?
    private var lastUpdate: Double?

    func update(device: AVCaptureDevice, time: Double) throws {
        if !enabled {
            if let mode = originalMode {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if device.isExposureModeSupported(mode) { device.exposureMode = mode }
                originalMode = nil
            }
            lastUpdate = nil
            return
        }
        guard device.isExposureModeSupported(.custom) else { return }
        if originalMode == nil {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            originalMode = device.exposureMode
            device.setExposureModeCustom(duration: device.exposureDuration, iso: device.iso, completionHandler: nil)
            lastUpdate = time
            return
        }
        let elapsed = time - (lastUpdate ?? time)
        guard elapsed >= 0.1 else { return }
        lastUpdate = time
        let stops = ExposureRamp.step(offset: Double(device.exposureTargetOffset), elapsed: elapsed, response: response)
        guard abs(stops) > 0.0001 else { return }
        let format = device.activeFormat
        let minDuration = max(0.000001, format.minExposureDuration.seconds)
        // Retain the current shutter range without reducing the live frame rate.
        let maxDuration = max(minDuration, min(format.maxExposureDuration.seconds, device.activeVideoMaxFrameDuration.seconds))
        let next = ExposureRamp.settings(iso: Double(device.iso), duration: device.exposureDuration.seconds, stops: stops,
                                        isoRange: Double(format.minISO)...Double(format.maxISO),
                                        durationRange: minDuration...maxDuration)
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        device.setExposureModeCustom(duration: CMTime(seconds: next.duration, preferredTimescale: 1_000_000_000), iso: Float(next.iso), completionHandler: nil)
    }
}
