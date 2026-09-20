import XCTest
import UIKit
import CoreImage
import ImageIO
@testable import RecursiveArt

final class CameraOrientationTests: XCTestCase {
    func testRearSensorImageIsUprightForEveryInterfaceOrientation() throws {
        let context = CIContext()
        // Unequal corner markers expose both a 180-degree error and mirroring.
        let base = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: 120, height: 180))
        let red = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 135, width: 35, height: 45))
        let blue = CIImage(color: .blue).cropped(to: CGRect(x: 80, y: 0, width: 40, height: 25))
        let upright = red.composited(over: blue.composited(over: base))
        let poses: [(UIInterfaceOrientation, CGImagePropertyOrientation)] = [
            (.portrait, .left), (.portraitUpsideDown, .right),
            (.landscapeLeft, .down), (.landscapeRight, .up)
        ]
        let expected = pixels(upright, context)
        for (interface, sensorPose) in poses {
            let sensorImage = upright.oriented(sensorPose)
            let angle = try XCTUnwrap(CameraOrientation.rotationAngle(for: interface))
            let corrected = VideoRecorder.oriented(sensorImage, from: 0, to: angle)
            XCTAssertEqual(corrected.extent.size, upright.extent.size)
            XCTAssertEqual(pixels(corrected, context), expected, "Upside-down or mirrored orientation: \(interface.rawValue)")
        }
        XCTAssertNil(CameraOrientation.rotationAngle(for: .unknown))
    }

    private func pixels(_ image: CIImage, _ context: CIContext) -> [UInt8] {
        let width = Int(image.extent.width), height = Int(image.extent.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        context.render(image, toBitmap: &bytes, rowBytes: width * 4, bounds: image.extent, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return bytes
    }
}
