import XCTest
import SwiftUI
import CoreImage
@testable import RecursiveArt

final class EffectsTests: XCTestCase {
    func testCollectionAndBidirectionalCycling() {
        XCTAssertEqual(ArtEffect.allCases.count, 80)
        XCTAssertEqual(Set(ArtEffect.allCases.map(\.name)).count, 80)
        for category in EffectCategory.allCases {
            XCTAssertEqual(ArtEffect.allCases.filter { $0.category == category }.count, 10)
        }
        var selected = ArtEffect.orbit
        var visited = Set<ArtEffect>()
        for _ in 0..<80 { visited.insert(selected); selected = selected.next(1) }
        XCTAssertEqual(visited.count, 80)
        XCTAssertEqual(selected, .orbit)
        XCTAssertEqual(ArtEffect.orbit.next(-1), .fatalError)
        for effect in ArtEffect.allCases { XCTAssertEqual(effect.next(1).next(-1), effect) }
    }

    @MainActor
    func testEveryCameraFilterProducesFiniteCroppedOpaqueImages() throws {
        let context = CIContext()
        let input = try XCTUnwrap(CIImage(image: EffectThumbnails.sample))
        for effect in ArtEffect.allCases where effect.processesCamera {
            for time in [0.0, 1.25, 3.2, 10.0] {
                let output = CameraEffects.render(input, effect: effect, time: time)
                XCTAssertEqual(output.extent, input.extent, effect.name)
                let image = try XCTUnwrap(context.createCGImage(output, from: output.extent), effect.name)
                XCTAssertEqual(image.width, Int(input.extent.width))
                XCTAssertEqual(image.height, Int(input.extent.height))
                let width = image.width, height = image.height
                var pixels = [UInt8](repeating: 0, count: width * height * 4)
                let bitmap = try XCTUnwrap(CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                bitmap.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                XCTAssertTrue(stride(from: 3, to: pixels.count, by: 4).allSatisfy { pixels[$0] == 255 }, "Transparent pixels: \(effect.name) at \(time)")
            }
        }
    }

    @MainActor
    func testAllEightyPreviewsAreDistinctAndCreateContactSheet() throws {
        var images: [UIImage] = []
        var fingerprints = Set<Data>()
        for effect in ArtEffect.allCases {
            let image = EffectThumbnails.image(for: effect)
            XCTAssertEqual(image.size, CGSize(width: 240, height: 160), effect.name)
            let data = try XCTUnwrap(image.pngData())
            XCTAssertTrue(fingerprints.insert(data).inserted, "Duplicate preview: \(effect.name)")
            images.append(image)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let sheet = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 3072), format: format).image { output in
            UIColor.black.setFill()
            output.fill(CGRect(x: 0, y: 0, width: 1200, height: 3072))
            for (i, image) in images.enumerated() {
                let x = (i % 5) * 240, y = (i / 5) * 192
                image.draw(in: CGRect(x: x, y: y, width: 240, height: 160))
                (ArtEffect.allCases[i].name as NSString).draw(at: CGPoint(x: x + 10, y: y + 166), withAttributes: [.font: UIFont.systemFont(ofSize: 15), .foregroundColor: UIColor.white])
            }
        }
        let attachment = XCTAttachment(image: sheet)
        attachment.name = "All 80 effects"
        attachment.lifetime = .keepAlways
        add(attachment)
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("effects-contact-sheet.png")
        try sheet.pngData()?.write(to: url)
    }

    @MainActor
    func testCanvasRendersInBothOrientations() throws {
        for size in [CGSize(width: 390, height: 844), CGSize(width: 844, height: 390)] {
            for effect in ArtEffect.allCases {
                let renderer = ImageRenderer(content: ArtScene(frame: EffectThumbnails.sample, effect: effect, time: 3.2).frame(width: size.width, height: size.height))
                renderer.scale = 1
                let image = try XCTUnwrap(renderer.uiImage, effect.name)
                XCTAssertEqual(image.size, size)
            }
        }
    }

    @MainActor
    func testAnimatedModesChangeOverTime() throws {
        let context = CIContext()
        let input = try XCTUnwrap(CIImage(image: EffectThumbnails.sample))
        for effect in ArtEffect.allCases where ![.clear, .negative, .posterize].contains(effect) {
            var snapshots: [Data] = []
            for time in [0.17, 1.73] {
                let filtered = CameraEffects.render(input, effect: effect, time: time)
                let frame = UIImage(cgImage: try XCTUnwrap(context.createCGImage(filtered, from: input.extent)))
                let renderer = ImageRenderer(content: ArtScene(frame: frame, effect: effect, time: time).frame(width: 240, height: 160))
                renderer.scale = 1
                snapshots.append(try XCTUnwrap(renderer.uiImage?.pngData()))
            }
            XCTAssertNotEqual(snapshots[0], snapshots[1], "No animation: \(effect.name)")
        }
    }

    @MainActor
    func testPickerRendersOnCompactScreen() async throws {
        let host = UIHostingController(rootView: EffectPicker(selected: .orbit, onSelect: { _ in }, camera: CameraController()))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previousKeyWindow?.makeKey() }
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(500))
        let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Effect picker"
        attachment.lifetime = .keepAlways
        add(attachment)
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("effect-picker.png")
        try image.pngData()?.write(to: url)
        XCTAssertFalse(host.view.bounds.isEmpty)
        let cgImage = try XCTUnwrap(image.cgImage)
        var pixels = [UInt8](repeating: 0, count: 64 * 64 * 4)
        let bitmap = try XCTUnwrap(CGContext(data: &pixels, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 64 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        bitmap.draw(cgImage, in: CGRect(x: 0, y: 0, width: 64, height: 64))
        let redValues = stride(from: 0, to: pixels.count, by: 4).map { pixels[$0] }
        XCTAssertGreaterThan(Set(redValues).count, 20, "Picker snapshot is blank")
    }

    @MainActor
    func testGestureSurfaceSeparatesPhotoVideoAndPickerTaps() {
        let surface = CanvasGestures.Surface()
        XCTAssertTrue(surface.isMultipleTouchEnabled)
        let taps = (surface.gestureRecognizers ?? []).compactMap { $0 as? UITapGestureRecognizer }
        XCTAssertEqual(Set(taps.map(\.numberOfTouchesRequired)), [1, 2, 3])
        let swipes = (surface.gestureRecognizers ?? []).compactMap { $0 as? UISwipeGestureRecognizer }
        XCTAssertEqual(swipes.count, 2)
        XCTAssertTrue(swipes.allSatisfy { $0.numberOfTouchesRequired == 1 })
    }
}
