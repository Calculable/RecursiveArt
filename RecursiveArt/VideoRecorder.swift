import AVFoundation
import CoreImage
import ImageIO

/// Receives untouched camera frames on the capture queue, before display effects.
/// A file keeps its starting orientation even if the live view subsequently rotates.
final class VideoRecorder {
    private(set) var hasFrames = false
    let url: URL
    private let angle: CGFloat
    private let writer: AVAssetWriter
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var size = CGSize.zero
    private var startTime: CMTime?
    private var lastTime: CMTime?
    private let context = CIContext(options: [.cacheIntermediates: false])

    init(url: URL, angle: CGFloat) throws {
        self.url = url
        self.angle = angle
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    }

    static func oriented(_ image: CIImage, from currentAngle: CGFloat, to targetAngle: CGFloat) -> CIImage {
        let delta = (Int(targetAngle - currentAngle) % 360 + 360) % 360
        let orientation: CGImagePropertyOrientation
        switch delta {
        case 90: orientation = .right
        case 180: orientation = .down
        case 270: orientation = .left
        default: orientation = .up
        }
        return image.oriented(orientation)
    }

    static func dimensions(for extent: CGRect) -> CGSize {
        let scale = min(1, 1920 / max(extent.width, extent.height))
        return CGSize(width: max(2, floor(extent.width * scale / 2) * 2), height: max(2, floor(extent.height * scale / 2) * 2))
    }

    func append(_ source: CIImage, timestamp: CMTime, angle currentAngle: CGFloat) throws {
        guard timestamp.isValid, timestamp.isNumeric else { return }
        let image = Self.oriented(source, from: currentAngle, to: angle)
        if input == nil {
            size = Self.dimensions(for: image.extent)
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height),
                AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 12_000_000, AVVideoExpectedSourceFrameRateKey: 30]
            ])
            input.expectsMediaDataInRealTime = true
            guard writer.canAdd(input) else { throw CaptureFailure.message("This device cannot encode the recording.") }
            writer.add(input)
            self.input = input
            adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width), kCVPixelBufferHeightKey as String: Int(size.height),
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ])
            guard writer.startWriting() else { throw writer.error ?? CaptureFailure.message("Recording could not start.") }
            writer.startSession(atSourceTime: timestamp)
            startTime = timestamp
        }
        guard writer.status == .writing else { throw writer.error ?? CaptureFailure.message("Recording stopped unexpectedly.") }
        guard let input, let adaptor, input.isReadyForMoreMediaData else { return }
        if let lastTime, timestamp <= lastTime { return }
        guard let pool = adaptor.pixelBufferPool else { throw CaptureFailure.message("Video buffer unavailable.") }
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer else {
            throw CaptureFailure.message("Not enough memory to continue recording.")
        }
        let normalized = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
            .transformed(by: CGAffineTransform(scaleX: size.width / image.extent.width, y: size.height / image.extent.height))
        context.render(normalized, to: buffer, bounds: CGRect(origin: .zero, size: size), colorSpace: CGColorSpaceCreateDeviceRGB())
        guard adaptor.append(buffer, withPresentationTime: timestamp) else {
            throw writer.error ?? CaptureFailure.message("A video frame could not be written.")
        }
        lastTime = timestamp
        hasFrames = true
    }

    func finish(_ completion: @escaping @Sendable (Result<URL, Error>) -> Void) {
        guard startTime != nil, let lastTime, writer.status == .writing else {
            writer.cancelWriting()
            completion(.failure(writer.error ?? CaptureFailure.message("No video frames were recorded. Please try a longer recording.")))
            return
        }
        writer.endSession(atSourceTime: lastTime + CMTime(value: 1, timescale: 30))
        input?.markAsFinished()
        let writer = writer, url = url
        writer.finishWriting {
            if writer.status == .completed { completion(.success(url)) }
            else { completion(.failure(writer.error ?? CaptureFailure.message("Video could not be finalized."))) }
        }
    }

    func cancel() { writer.cancelWriting() }
}

enum CaptureFailure: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}
