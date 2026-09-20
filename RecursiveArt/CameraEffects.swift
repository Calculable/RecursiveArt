import CoreImage

/// Runs on the capture queue. Every output is cropped back to the original frame.
/// The processed frame is shared by the preview and photo capture.
enum CameraEffects {
    static func render(_ input: CIImage, effect: ArtEffect, time: Double) -> CIImage {
        let bounds = input.extent
        let center = CIVector(x: bounds.midX, y: bounds.midY)
        let unit = min(bounds.width, bounds.height)
        let source = input.clampedToExtent()
        let result: CIImage
        switch effect {
        case .kaleidoscope:
            result = source.applyingFilter("CIKaleidoscope", parameters: ["inputCount": 6, "inputCenter": center, "inputAngle": time * 0.12])
        case .mirrorTiles:
            result = source.applyingFilter("CIFourfoldReflectedTile", parameters: ["inputCenter": center, "inputAngle": sin(time * 0.15) * 0.3, "inputWidth": unit * 0.42, "inputAcuteAngle": Double.pi / 2])
        case .ripple:
            let movingCenter = CIVector(x: bounds.midX + sin(time * 0.4) * unit * 0.22, y: bounds.midY + cos(time * 0.3) * unit * 0.22)
            result = source.applyingFilter("CIBumpDistortionLinear", parameters: ["inputCenter": movingCenter, "inputRadius": unit * 0.22, "inputAngle": time * 0.25, "inputScale": sin(time * 1.2) * 0.7])
        case .twirl:
            result = source.applyingFilter("CITwirlDistortion", parameters: ["inputCenter": center, "inputRadius": unit * 0.7, "inputAngle": sin(time * 0.45) * 3.5])
        case .bulge:
            result = source.applyingFilter("CIBumpDistortion", parameters: ["inputCenter": center, "inputRadius": unit * 0.65, "inputScale": sin(time * 0.7) * 0.65])
        case .pixelate:
            result = source.applyingFilter("CIPixellate", parameters: ["inputCenter": center, "inputScale": 4 + (sin(time * 0.55) + 1) * unit * 0.025])
        case .rgbSplit:
            let shift = unit * (0.012 + 0.018 * sin(time * 0.8))
            let red = channel(source, r: 1, g: 0, b: 0).transformed(by: CGAffineTransform(translationX: shift, y: 0))
            let green = channel(source, r: 0, g: 1, b: 0)
            let blue = channel(source, r: 0, g: 0, b: 1).transformed(by: CGAffineTransform(translationX: -shift, y: cos(time) * shift))
            result = red.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: green])
                .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: blue])
        case .negative:
            result = input.applyingFilter("CIColorInvert")
        case .solarize:
            result = input.applyingFilter("CIColorPolynomial", parameters: [
                "inputRedCoefficients": CIVector(x: 0, y: 4, z: -4, w: 0),
                "inputGreenCoefficients": CIVector(x: 0, y: 3.4, z: -3.4, w: 0),
                "inputBlueCoefficients": CIVector(x: 0.15, y: 3, z: -3, w: 0)
            ]).applyingFilter("CIHueAdjust", parameters: ["inputAngle": time * 0.25])
        case .posterize:
            result = input.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.8, "inputContrast": 1.15])
                .applyingFilter("CIColorPosterize", parameters: ["inputLevels": 4])
        default:
            result = input
        }
        return result.cropped(to: bounds)
    }

    private static func channel(_ image: CIImage, r: CGFloat, g: CGFloat, b: CGFloat) -> CIImage {
        image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: r, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: g, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: b, w: 0)
        ])
    }
}
