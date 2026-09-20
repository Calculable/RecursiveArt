import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraController()
    @Environment(\.displayScale) private var displayScale
    @Environment(\.scenePhase) private var scenePhase
    @State private var effect = ArtEffect.orbit
    @State private var showingPicker = false
    @State private var epoch = Date()

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active)) { timeline in
                ArtScene(frame: camera.frame, effect: effect, time: timeline.date.timeIntervalSince(epoch))
            }
            .contentShape(Rectangle())
            .overlay {
                CanvasGestures(
                    onCapture: { capture(size: geometry.size) },
                    onStep: { changeEffect($0) },
                    onPicker: { showingPicker = true },
                    onRecord: { camera.toggleRecording() }
                )
                .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Camera art, \(effect.name)")
            .accessibilityHint("Double tap to save a picture. Adjust up or down to change effects. Use the Choose effect action to browse all effects.")
            .accessibilityAction(named: "Start or stop video") { camera.toggleRecording() }
            .accessibilityAction(named: "Choose effect") { showingPicker = true }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { capture(size: geometry.size) }
            .accessibilityAdjustableAction { direction in
                changeEffect(direction == .increment ? 1 : -1)
            }
            .overlay {
                if let problem = camera.problem {
                    VStack(spacing: 18) {
                        Image(systemName: "camera.fill").font(.largeTitle)
                        Text(problem).multilineTextAlignment(.center)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        Button("Try again") { Task { await camera.start() } }
                    }
                    .padding(32)
                    .foregroundStyle(.white)
                    .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 24))
                    .padding(24)
                }
            }
            .background(OrientationReader { camera.updateOrientation($0) })
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingPicker) {
            EffectPicker(selected: effect, onSelect: { selectEffect($0) }, camera: camera)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .task {
            UIApplication.shared.isIdleTimerDisabled = true
            await camera.start()
        }
        .onChange(of: scenePhase) { _, phase in
            UIApplication.shared.isIdleTimerDisabled = phase == .active
            if phase == .active { Task { await camera.start() } }
            else { camera.stop() }
        }
        .onDisappear {
            camera.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .alert("Capture needs attention", isPresented: Binding(get: { camera.captureError != nil }, set: { if !$0 { camera.captureError = nil } })) {
            Button("OK", role: .cancel) { camera.captureError = nil }
        } message: {
            Text(camera.captureError ?? "Please try again.")
        }
    }

    private func changeEffect(_ offset: Int) {
        selectEffect(effect.next(offset))
    }

    private func selectEffect(_ selected: ArtEffect) {
        effect = selected
        camera.selectEffect(selected)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func capture(size: CGSize) {
        guard !showingPicker else { return }
        if camera.includeOverlayInPhotos {
            guard let frame = camera.frame, camera.problem == nil else { return }
            guard let image = ArtworkPhoto.render(frame: frame, effect: effect, time: Date().timeIntervalSince(epoch), size: size, scale: displayScale) else {
                camera.captureError = "The artwork photo could not be rendered."
                return
            }
            camera.takeArtworkPhoto(image)
        } else {
            camera.takePhoto()
        }
    }

}

/// Uses the window's interface orientation, including when launching in landscape.
private struct OrientationReader: UIViewControllerRepresentable {
    var onChange: (UIInterfaceOrientation) -> Void

    func makeUIViewController(context: Context) -> Observer {
        let observer = Observer()
        observer.onChange = onChange
        return observer
    }

    func updateUIViewController(_ controller: Observer, context: Context) {
        controller.onChange = onChange
    }

    final class Observer: UIViewController {
        var onChange: ((UIInterfaceOrientation) -> Void)?
        private var lastOrientation: UIInterfaceOrientation?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            reportOrientation()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            reportOrientation()
        }

        override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in self?.reportOrientation() }
        }

        private func reportOrientation() {
            if let orientation = view.window?.windowScene?.interfaceOrientation,
               orientation != .unknown, orientation != lastOrientation {
                lastOrientation = orientation
                onChange?(orientation)
            }
        }
    }
}

#Preview {
    ArtScene(frame: nil, effect: .orbit, time: 5)
        .ignoresSafeArea()
}
