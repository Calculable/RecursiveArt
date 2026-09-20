import XCTest
import CoreImage
@testable import RecursiveArt

final class SimulatedMotionTests: XCTestCase {
    func testOffAndZeroAmountLeaveImageUntouched() {
        let source = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 160, height: 240))
        let context = CIContext()
        var motion = SimulatedCameraMotion()
        XCTAssertEqual(pixels(motion.render(source, enabled: false, amount: 1, time: 0), context), pixels(source, context))
        XCTAssertEqual(pixels(motion.render(source, enabled: true, amount: 0, time: 1), context), pixels(source, context))
    }

    func testChangesEaseInAndOutWithoutSuddenJump() {
        let source = CIImage(color: .blue).cropped(to: CGRect(x: 0, y: 0, width: 160, height: 240))
        var motion = SimulatedCameraMotion()
        _ = motion.render(source, enabled: true, amount: 1, time: 0)
        XCTAssertEqual(motion.amplitude, 0)
        _ = motion.render(source, enabled: true, amount: 1, time: 1.0 / 30)
        XCTAssertLessThan(motion.amplitude, 0.05)
        for i in 2...300 { _ = motion.render(source, enabled: true, amount: 1, time: Double(i) / 30) }
        XCTAssertGreaterThan(motion.amplitude, 0.99)
        _ = motion.render(source, enabled: false, amount: 1, time: 301.0 / 30)
        XCTAssertGreaterThan(motion.amplitude, 0.95)
        for i in 302...700 { _ = motion.render(source, enabled: false, amount: 1, time: Double(i) / 30) }
        XCTAssertEqual(motion.amplitude, 0)
    }

    func testMotionAnimatesWithOpaqueEdgesInBothOrientations() throws {
        let context = CIContext()
        for size in [CGSize(width: 160, height: 240), CGSize(width: 240, height: 160)] {
            let bounds = CGRect(origin: .zero, size: size)
            let base = CIImage(color: .red).cropped(to: bounds)
            let square = CIImage(color: .blue).cropped(to: CGRect(x: 40, y: 50, width: 60, height: 60))
            let source = square.composited(over: base)
            var motion = SimulatedCameraMotion()
            var previous: [UInt8]?
            for i in 0...400 {
                let output = motion.render(source, enabled: true, amount: 1, time: Double(i) / 10)
                if i % 40 == 0 {
                    XCTAssertEqual(output.extent, bounds)
                    let bytes = pixels(output, context)
                    XCTAssertTrue(stride(from: 3, to: bytes.count, by: 4).allSatisfy { bytes[$0] == 255 })
                    if let previous { XCTAssertNotEqual(bytes, previous) }
                    previous = bytes
                }
            }
        }
    }

    private func pixels(_ image: CIImage, _ context: CIContext) -> [UInt8] {
        let width = Int(image.extent.width), height = Int(image.extent.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        context.render(image, toBitmap: &bytes, rowBytes: width * 4, bounds: image.extent, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return bytes
    }
}
