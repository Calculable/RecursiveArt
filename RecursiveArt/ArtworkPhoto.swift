import SwiftUI

@MainActor
enum ArtworkPhoto {
    /// Matches the screen's crop, processed camera frame, and animated overlay.
    /// UI controls are outside ArtScene and therefore cannot enter this export.
    static func render(frame: UIImage, effect: ArtEffect, time: Double, size: CGSize, scale: CGFloat) -> UIImage? {
        guard size.width > 0, size.height > 0, scale > 0 else { return nil }
        let renderer = ImageRenderer(content: ArtScene(frame: frame, effect: effect, time: time)
            .frame(width: size.width, height: size.height))
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
