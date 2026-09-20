import XCTest
import AVFoundation
import CoreImage
import SwiftUI
@testable import RecursiveArt

final class CaptureAndBalanceTests: XCTestCase {
    func testBalanceSlowlyAttenuatesBlueWithoutRunawayGains() {
        var balance = FeedbackBalance()
        balance.update(mean: SIMD3(0.2, 0.25, 0.8), elapsed: 0.25)
        XCTAssertGreaterThan(balance.gains.z, 0.98, "First sample must not cause a color jump")
        for _ in 0..<160 { balance.update(mean: SIMD3(0.2, 0.25, 0.8), elapsed: 0.25) }
        XCTAssertLessThan(balance.gains.z, 0.70)
        XCTAssertGreaterThan(balance.gains.x, 1)
        XCTAssertTrue((0..<3).allSatisfy { (0.68...1.12).contains(balance.gains[$0]) })
        let settled = balance.gains
        balance.update(mean: SIMD3(repeating: 0), elapsed: 1)
        balance.update(mean: SIMD3(repeating: .nan), elapsed: 1)
        XCTAssertEqual(balance.gains, settled)
        for _ in 0..<240 { balance.update(mean: SIMD3(repeating: 0.3), elapsed: 0.25) }
        for channel in 0..<3 { XCTAssertEqual(balance.gains[channel], 1, accuracy: 0.001) }
    }

    func testBalanceOffLeavesSensorColorUnchangedAndFlowAnimates() throws {
        let context = CIContext()
        let input = CIImage(color: CIColor(red: 0.15, green: 0.3, blue: 0.8)).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 48))
        var balance = FeedbackBalance()
        let untouched = balance.apply(to: input, mode: .off, time: 0, context: context)
        XCTAssertEqual(try pixels(untouched, context: context), try pixels(input, context: context))
        let start = balance.apply(to: input, mode: .colorFlow, time: 0, context: context)
        let end = balance.apply(to: input, mode: .colorFlow, time: 45, context: context)
        XCTAssertNotEqual(try pixels(start, context: context), try pixels(end, context: context))
        XCTAssertEqual(end.extent, input.extent)
    }

    @MainActor
    func testDenseMasksReallyHideCameraPixels() throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 160)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 240, height: 160))
        }
        let context = CIContext()
        for effect in ArtEffect.allCases where effect.category == .masks {
            let renderer = ImageRenderer(content: ArtScene(frame: source, effect: effect, time: 3.2).frame(width: 240, height: 160))
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.uiImage)
            let data = try pixels(XCTUnwrap(CIImage(image: image)), context: context)
            let hidden = stride(from: 0, to: data.count, by: 4).filter { min(data[$0], data[$0 + 1], data[$0 + 2]) < 180 }.count
            XCTAssertGreaterThan(Double(hidden) / (240 * 160), 0.3, effect.name)
        }
    }

    func testVideoDimensionsAndOrientation() {
        XCTAssertEqual(VideoRecorder.dimensions(for: CGRect(x: 0, y: 0, width: 4032, height: 3024)), CGSize(width: 1920, height: 1440))
        XCTAssertEqual(VideoRecorder.dimensions(for: CGRect(x: 0, y: 0, width: 721, height: 1281)), CGSize(width: 720, height: 1280))
        let source = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 640, height: 480))
        XCTAssertEqual(VideoRecorder.oriented(source, from: 0, to: 90).extent.size, CGSize(width: 480, height: 640))
        XCTAssertEqual(VideoRecorder.oriented(source, from: 180, to: 90).extent.size, CGSize(width: 480, height: 640))
    }

    func testCameraOnlyVideoEncodesAndDecodesOriginalColors() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = try VideoRecorder(url: url, angle: 90)
        XCTAssertFalse(recorder.hasFrames)
        // This solid sensor frame must remain red, regardless of display effects.
        let image = CIImage(color: CIColor(red: 0.9, green: 0.08, blue: 0.04)).cropped(to: CGRect(x: 0, y: 0, width: 320, height: 240))
        for frame in 0..<24 {
            try recorder.append(image, timestamp: CMTime(value: Int64(frame), timescale: 30), angle: 90)
            try await Task.sleep(for: .milliseconds(8))
        }
        XCTAssertTrue(recorder.hasFrames, "Recording-start feedback must wait for a written frame")
        let saved = try await withCheckedThrowingContinuation { continuation in
            recorder.finish { continuation.resume(with: $0) }
        }
        XCTAssertEqual(saved, url)
        let asset = AVURLAsset(url: saved)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        XCTAssertEqual(tracks.count, 1)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertTrue(audio.isEmpty)
        let track = try XCTUnwrap(tracks.first)
        let dimensions = try await track.load(.naturalSize)
        XCTAssertEqual(dimensions, CGSize(width: 320, height: 240))
        let duration = try await asset.load(.duration)
        XCTAssertGreaterThan(duration.seconds, 0.5)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        reader.add(output)
        XCTAssertTrue(reader.startReading())
        let sample = try XCTUnwrap(output.copyNextSampleBuffer())
        let buffer = try XCTUnwrap(CMSampleBufferGetImageBuffer(sample))
        let decoded = try pixels(CIImage(cvPixelBuffer: buffer), context: CIContext())
        let middle = (120 * 320 + 160) * 4
        XCTAssertGreaterThan(decoded[middle], 200)
        XCTAssertLessThan(decoded[middle + 1], 40)
        XCTAssertLessThan(decoded[middle + 2], 35)
        reader.cancelReading()
    }

    func testEmptyVideoReturnsFailure() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = try VideoRecorder(url: url, angle: 90)
        let result = await withCheckedContinuation { continuation in
            recorder.finish { continuation.resume(returning: $0) }
        }
        if case .success = result { XCTFail("An empty recording should not be saved") }
    }

    private func pixels(_ image: CIImage, context: CIContext) throws -> [UInt8] {
        let width = Int(image.extent.width), height = Int(image.extent.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        context.render(image, toBitmap: &bytes, rowBytes: width * 4, bounds: image.extent, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return bytes
    }
}
