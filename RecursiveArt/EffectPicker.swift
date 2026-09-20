import SwiftUI
import CoreImage

struct EffectPicker: View {
    let selected: ArtEffect
    var onSelect: (ArtEffect) -> Void
    var camera: CameraController? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var category: EffectCategory?

    private var matches: [ArtEffect] {
        ArtEffect.allCases.filter {
            (category == nil || $0.category == category) &&
            (search.isEmpty || ($0.name + " " + $0.detail + " " + $0.category.rawValue).localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MAKE A LITTLE CHAOS")
                            .font(.caption.weight(.bold)).tracking(2).foregroundStyle(.mint)
                        Text("\(ArtEffect.allCases.count) ways to bend the light.")
                            .font(.title2.weight(.semibold))
                        Text("Choose a look, then point the camera into its own world.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let camera { CaptureControls(camera: camera) }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryButton(nil)
                            ForEach(EffectCategory.allCases) { categoryButton($0) }
                        }
                    }
                    HStack {
                        Text(category?.rawValue ?? "All effects")
                        Spacer()
                        Text("\(matches.count)").monospacedDigit()
                    }
                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    if matches.isEmpty {
                        ContentUnavailableView.search(text: search)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], spacing: 12) {
                        ForEach(matches) { effect in
                            Button {
                                onSelect(effect)
                                dismiss()
                            } label: {
                                card(effect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(effect.name)
                            .accessibilityValue(effect == selected ? "Selected" : "")
                            .accessibilityHint(effect.detail)
                        }
                    }
                    Text("Tap for photo · Two-finger tap for video\nSwipe for effects · Three-finger tap or hold for controls")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.vertical, 12)
                }
                .padding(20)
            }
            .background(Color(red: 0.035, green: 0.045, blue: 0.065))
            .navigationTitle("Effects")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Find a mood, motion, or effect")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(.mint)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func categoryButton(_ item: EffectCategory?) -> some View {
        Button { category = item } label: {
            Text(item?.rawValue ?? "All")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 15).padding(.vertical, 9)
                .foregroundStyle(category == item ? Color.black : Color.white.opacity(0.8))
                .background(category == item ? Color.mint : Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(category == item ? .isSelected : [])
    }

    private func card(_ effect: ArtEffect) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(uiImage: EffectThumbnails.image(for: effect))
                .resizable().aspectRatio(1.5, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    if effect == selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.black, .mint).font(.title3).padding(10)
                    }
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(effect.name).font(.subheadline.weight(.semibold))
                Text(effect.detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 185, alignment: .topLeading)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(effect == selected ? Color.mint : Color.white.opacity(0.08), lineWidth: effect == selected ? 2 : 1))
    }
}

/// Small, cached stills use the real effect renderers over a synthetic scene.
/// No camera data or photo-library access is needed to browse the collection.
@MainActor
enum EffectThumbnails {
    private static var cache: [ArtEffect: UIImage] = [:]
    private static let context = CIContext(options: [.cacheIntermediates: false])
    static let sample: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 160))
        return renderer.image { output in
            let cg = output.cgContext
            UIColor(red: 0.03, green: 0.06, blue: 0.1, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: 240, height: 160))
            for i in 0..<12 {
                UIColor(hue: CGFloat(i) / 12, saturation: 0.7, brightness: 0.65, alpha: 1).setFill()
                cg.fill(CGRect(x: CGFloat(i) * 20, y: 90, width: 20, height: 70))
            }
            UIColor.systemTeal.setFill()
            cg.fillEllipse(in: CGRect(x: 140, y: 20, width: 65, height: 65))
            UIColor.systemPink.setStroke()
            cg.setLineWidth(3)
            for i in 0..<5 {
                cg.stroke(CGRect(x: 20 + i * 8, y: 15 + i * 8, width: 80 - i * 12, height: 65 - i * 10))
            }
        }
    }()

    static func image(for effect: ArtEffect) -> UIImage {
        if let cached = cache[effect] { return cached }
        var frame = sample
        if let input = CIImage(image: sample), effect.processesCamera,
           let output = context.createCGImage(CameraEffects.render(input, effect: effect, time: 3.2), from: input.extent) {
            frame = UIImage(cgImage: output)
        }
        let renderer = ImageRenderer(content: ArtScene(frame: frame, effect: effect, time: 3.2).frame(width: 240, height: 160))
        renderer.scale = 1
        let image = renderer.uiImage ?? frame
        cache[effect] = image
        return image
    }
}


private struct CaptureControls: View {
    @ObservedObject var camera: CameraController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Include overlay in photos", isOn: $camera.includeOverlayInPhotos)
                .font(.subheadline.weight(.semibold)).tint(.mint)
            Text(camera.includeOverlayInPhotos
                 ? "Save the visible camera image, effects, and artwork with the screen's crop and pixel dimensions. Uses preview detail instead of the full-resolution sensor photo. Videos remain camera-only."
                 : "Save full-resolution camera photos without app effects or artwork.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Toggle("Slow exposure changes", isOn: $camera.slowExposureEnabled)
                .font(.subheadline.weight(.semibold)).tint(.mint)
                .disabled(camera.supportsSlowExposure == false)
            if camera.slowExposureEnabled {
                HStack {
                    Text("Response").font(.caption)
                    Slider(value: $camera.exposureResponse, in: 1...12, step: 1).tint(.mint)
                        .accessibilityLabel("Exposure response time")
                    Text("\(Int(camera.exposureResponse)) s").font(.caption.monospacedDigit())
                }
            }
            Text(camera.supportsSlowExposure == false
                 ? "This camera does not support manual exposure control."
                 : "Gently adjusts sensor exposure to reduce dark–bright feedback pumping. Higher response times react more slowly. Applies to the live view, photos, and video.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("Feedback color").font(.subheadline.weight(.semibold))
            Picker("Feedback color", selection: $camera.feedbackMode) {
                ForEach(FeedbackMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Text("Stabilize slowly reduces color buildup. Color flow adds a gentle hue cycle. These affect the live display and photos with overlays.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Toggle("Simulate camera movement", isOn: $camera.simulatedMotionEnabled)
                .font(.subheadline.weight(.semibold)).tint(.mint)
            if camera.simulatedMotionEnabled {
                HStack {
                    Text("Amount").font(.caption)
                    Slider(value: $camera.simulatedMotionAmount, in: 0...1).tint(.mint)
                        .accessibilityLabel("Simulated movement amount")
                    Text(camera.simulatedMotionAmount, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospacedDigit()).frame(width: 38, alignment: .trailing)
                }
            }
            Text("Gentle drift, lens distortion, and breathing zoom in every effect. Changes fade in smoothly. Moves the live camera image and photos with overlays; camera-only captures stay untouched.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Button { camera.toggleRecording() } label: {
                HStack {
                    Image(systemName: camera.recordingState == .recording ? "stop.circle.fill" : "record.circle")
                    Text(camera.recordingState.buttonTitle)
                    Spacer()
                    if let start = camera.recordingStartedAt {
                        Text(start, style: .timer).monospacedDigit().fixedSize()
                    }
                }
                .font(.headline).foregroundStyle(.red)
            }
            .disabled(camera.recordingState == .starting || camera.recordingState == .finishing || camera.retryingSaves || (camera.recordingState == .idle && camera.frame == nil))
            Text("A rising chime confirms recording starts; a falling chime confirms it stops. Cues respect Silent Mode and device volume. Silent video always saves the camera view without app effects. Two-finger tap on the canvas to start or stop without opening the controls. Leaving the app stops and saves the recording.")
                .font(.caption).foregroundStyle(.secondary)
            if camera.pendingCaptureCount > 0 {
                Button(camera.retryingSaves ? "Saving…" : "Retry saving \(camera.pendingCaptureCount) captures") {
                    camera.retryPendingCaptures()
                }
                .disabled(camera.retryingSaves || camera.isSavingPhoto || camera.isSavingVideo || camera.recordingState != .idle)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
    }
}
