import XCTest
import SwiftUI
@testable import RecursiveArt

final class ExposureAndArtworkTests: XCTestCase {
    func testExposureMovesInCorrectDirectionAndSlowerResponseReducesStep() {
        XCTAssertLessThan(ExposureRamp.step(offset: 2, elapsed: 0.1, response: 5), 0)
        XCTAssertGreaterThan(ExposureRamp.step(offset: -2, elapsed: 0.1, response: 5), 0)
        XCTAssertLessThan(abs(ExposureRamp.step(offset: 2, elapsed: 0.1, response: 12)),
                          abs(ExposureRamp.step(offset: 2, elapsed: 0.1, response: 1)))
        XCTAssertEqual(ExposureRamp.step(offset: 0.1, elapsed: 0.1, response: 5), 0)
        XCTAssertEqual(ExposureRamp.step(offset: .nan, elapsed: 0.1, response: 5), 0)
        XCTAssertLessThanOrEqual(abs(ExposureRamp.step(offset: 100, elapsed: 60, response: 5)), 0.05)
    }

    func testExposureSettlesWithoutOvershoot() {
        for initial in [-4.0, 4.0] {
            var offset = initial
            for _ in 0..<600 {
                let next = offset + ExposureRamp.step(offset: offset, elapsed: 0.1, response: 5)
                XCTAssertLessThanOrEqual(abs(next), abs(offset))
                XCTAssertEqual(next.sign, initial.sign)
                offset = next
            }
            XCTAssertLessThanOrEqual(abs(offset), 0.12)
        }
    }

    func testExposureSettingsRespectSensorAndFrameDurationLimits() {
        let brighter = ExposureRamp.settings(iso: 100, duration: 0.01, stops: 1,
                                             isoRange: 50...800, durationRange: 0.001...0.033)
        XCTAssertEqual(brighter.iso * brighter.duration, 2, accuracy: 0.0001)
        let shutter = ExposureRamp.settings(iso: 800, duration: 0.01, stops: 1,
                                            isoRange: 50...800, durationRange: 0.001...0.033)
        XCTAssertEqual(shutter.iso, 800)
        XCTAssertEqual(shutter.duration, 0.02, accuracy: 0.0001)
        for stops in [-100.0, 100.0] {
            let limited = ExposureRamp.settings(iso: 100, duration: 0.01, stops: stops,
                                                isoRange: 50...800, durationRange: 0.001...0.033)
            XCTAssertTrue((50...800).contains(limited.iso))
            XCTAssertTrue((0.001...0.033).contains(limited.duration))
        }
    }

    @MainActor
    func testArtworkExportIncludesOverlayAtDisplayDimensionsWithoutChangingSource() async throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 120)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 160, height: 120))
        }
        let original = source.pngData()
        for size in [CGSize(width: 120, height: 240), CGSize(width: 240, height: 120)] {
            let clear = try XCTUnwrap(ArtworkPhoto.render(frame: source, effect: .clear, time: 3.2, size: size, scale: 2))
            let effect = try XCTUnwrap(ArtEffect.allCases.first { $0.category == .masks })
            let artwork = try XCTUnwrap(ArtworkPhoto.render(frame: source, effect: effect, time: 3.2, size: size, scale: 2))
            XCTAssertEqual(artwork.cgImage?.width, Int(size.width * 2))
            XCTAssertEqual(artwork.cgImage?.height, Int(size.height * 2))
            XCTAssertNotEqual(artwork.pngData(), clear.pngData())
            let url = try await CaptureLibrary.persistArtwork(artwork)
            defer { try? FileManager.default.removeItem(at: url) }
            let saved = try XCTUnwrap(UIImage(contentsOfFile: url.path))
            XCTAssertEqual(saved.cgImage?.width, artwork.cgImage?.width)
            XCTAssertEqual(saved.cgImage?.height, artwork.cgImage?.height)
        }
        XCTAssertEqual(source.pngData(), original)
        XCTAssertNil(ArtworkPhoto.render(frame: source, effect: .clear, time: 0, size: .zero, scale: 2))
    }
}
