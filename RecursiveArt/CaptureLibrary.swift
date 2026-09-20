import Foundation
import Photos
import UIKit

/// Keep originals until Photos confirms success. Failed saves survive relaunch.
enum CaptureLibrary {
    static func directory() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("Pending Captures", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func newURL(extension suffix: String) throws -> URL {
        try directory().appendingPathComponent(UUID().uuidString).appendingPathExtension(suffix)
    }

    static func pendingFiles() -> [URL] {
        guard let directory = try? directory() else { return [] }
        return ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { ["jpg", "mov"].contains($0.pathExtension) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func persistArtwork(_ image: UIImage) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            guard let data = image.jpegData(compressionQuality: 0.95) else {
                throw CaptureFailure.message("The artwork photo could not be encoded.")
            }
            let url = try newURL(extension: "jpg")
            try data.write(to: url, options: .atomic)
            return url
        }.value
    }

    static func persistPhoto(_ data: Data) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let url = try newURL(extension: "jpg")
            try data.write(to: url, options: .atomic)
            return url
        }.value
    }

    static func saveToPhotos(_ url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw CaptureFailure.message("Allow Photos access in Settings. Your capture is kept in the app; open the controls and retry saving it.")
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: url.pathExtension == "mov" ? .video : .photo, fileURL: url, options: nil)
        }
        // Photos has copied the original. Never delete a file on a failed save.
        try? FileManager.default.removeItem(at: url)
    }
}
