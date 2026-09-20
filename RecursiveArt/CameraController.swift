import AVFoundation
import Combine
import CoreImage
import UIKit

/// All capture-session and image conversion work stays on this serial queue.
final class CameraPipeline: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "art.camera", qos: .userInitiated)
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var photoCompletion: (@Sendable (Result<Data, Error>) -> Void)?
    private var cameraDevice: AVCaptureDevice?
    private var focusModeToRestore: AVCaptureDevice.FocusMode?
    private var photoResult: Result<Data, Error>?
    private var recorder: VideoRecorder?
    private var captureAngle: CGFloat = 90
    private var feedbackMode = FeedbackMode.stabilize
    private var balance = FeedbackBalance()
    private let slowExposure = SlowExposure()
    var onExposureSupport: (@Sendable (Bool) -> Void)?
    var onExposureError: (@Sendable (String) -> Void)?
    private var simulatedMotion = SimulatedCameraMotion()
    private var motionEnabled = false
    private var motionAmount = 0.45
    var onRecordingFinished: (@Sendable (Result<URL, Error>) -> Void)?
    var onRecordingStarted: (@Sendable () -> Void)?
    var onRecordingStopping: (@Sendable () -> Void)?
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var configured = false
    private var effect = ArtEffect.orbit
    private let epoch = CACurrentMediaTime()
    private var deliveryPending = false
    private let deliveryLock = NSLock()
    private var observers: [NSObjectProtocol] = []
    var onFrame: (@Sendable (CGImage) -> Void)?
    var onError: (@Sendable (String) -> Void)?
    var onRecovery: (@Sendable () -> Void)?

    override init() {
        super.init()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { [weak self] _ in
            self?.stopRecording()
            self?.onError?("The camera was interrupted. It will resume when available.")
        })
        observers.append(center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil) { [weak self] _ in
            self?.onRecovery?()
        })
        observers.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { [weak self] _ in
            self?.stopRecording()
            self?.onError?("The camera stopped unexpectedly. Tap Try again to restart it.")
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func start(angle: CGFloat) {
        queue.async { [self] in
            do {
                if !configured { try configure() }
                setAngle(angle)
                if !session.isRunning { session.startRunning() }
            } catch {
                onError?(error.localizedDescription)
            }
        }
    }

    func stop() {
        queue.async { [self] in
            finishRecording()
            if session.isRunning { session.stopRunning() }
        }
    }

    func rotate(to angle: CGFloat) {
        queue.async { [self] in setAngle(angle) }
    }

    func selectEffect(_ effect: ArtEffect) {
        queue.async { [self] in self.effect = effect }
    }

    func setFeedbackMode(_ mode: FeedbackMode) {
        queue.async { [self] in feedbackMode = mode; balance.reset() }
    }

    func setSimulatedMotion(enabled: Bool, amount: Double) {
        queue.async { [self] in
            motionEnabled = enabled
            motionAmount = amount
        }
    }

    func setSlowExposure(enabled: Bool, response: Double) {
        queue.async { [self] in
            slowExposure.enabled = enabled
            slowExposure.response = response
        }
    }

    private func setAngle(_ angle: CGFloat) {
        captureAngle = angle
        for connection in [output.connection(with: .video), photoOutput.connection(with: .video)].compactMap({ $0 }) {
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
            if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
        }
    }

    func capturePhoto(_ completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        queue.async { [self] in
            guard session.isRunning, photoCompletion == nil else {
                completion(.failure(CaptureFailure.message("The camera is not ready to take a photo.")))
                return
            }
            photoCompletion = completion
            photoResult = nil
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
            settings.photoQualityPrioritization = .speed
            settings.flashMode = .off
            // Take the current lens position, even if autofocus is hunting.
            // Failure to acquire the configuration lock must not cancel the shot.
            if let cameraDevice, cameraDevice.isFocusModeSupported(.locked) {
                do {
                    try cameraDevice.lockForConfiguration()
                    focusModeToRestore = cameraDevice.focusMode
                    cameraDevice.focusMode = .locked
                    cameraDevice.unlockForConfiguration()
                } catch { focusModeToRestore = nil }
            }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        queue.async { [self] in restoreFocus() }
    }

    private func restoreFocus() {
        guard let cameraDevice, let mode = focusModeToRestore else { return }
        do {
            try cameraDevice.lockForConfiguration()
            if cameraDevice.isFocusModeSupported(mode) { cameraDevice.focusMode = mode }
            cameraDevice.unlockForConfiguration()
            focusModeToRestore = nil
        } catch {
            // Keep the saved mode so the final delegate callback can retry.
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = photo.fileDataRepresentation()
        queue.async { [self] in
            if let error { photoResult = .failure(error) }
            else if let data { photoResult = .success(data) }
            else { photoResult = .failure(CaptureFailure.message("The camera returned no photo data.")) }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        queue.async { [self] in
            restoreFocus()
            let result = error.map { Result<Data, Error>.failure($0) } ?? photoResult ?? .failure(CaptureFailure.message("Photo capture did not finish."))
            let completion = photoCompletion
            photoCompletion = nil
            photoResult = nil
            completion?(result)
        }
    }

    func startRecording(_ completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        queue.async { [self] in
            guard session.isRunning, recorder == nil else {
                completion(.failure(CaptureFailure.message("The camera is not ready to record.")))
                return
            }
            var destination: URL?
            do {
                let url = try CaptureLibrary.newURL(extension: "mov")
                destination = url
                recorder = try VideoRecorder(url: url, angle: captureAngle)
                completion(.success(()))
            } catch {
                if let destination { try? FileManager.default.removeItem(at: destination) }
                completion(.failure(error))
            }
        }
    }

    func stopRecording() { queue.async { [self] in finishRecording() } }

    private func finishRecording() {
        guard let recorder else { return }
        self.recorder = nil
        onRecordingStopping?()
        let callback = onRecordingFinished
        recorder.finish { result in
            if case .failure = result { try? FileManager.default.removeItem(at: recorder.url) }
            callback?(result)
        }
    }

    private func configure() throws {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.unavailable
        }
        let input = try AVCaptureDeviceInput(device: camera)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard session.canAddInput(input) else { throw CameraError.unavailable }
        session.addInput(input)
        guard session.canAddOutput(output) else {
            session.removeInput(input)
            throw CameraError.unavailable
        }
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        session.addOutput(output)
        if camera.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }) {
            if (try? camera.lockForConfiguration()) != nil {
                camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                camera.unlockForConfiguration()
            }
        }
        guard session.canAddOutput(photoOutput) else {
            session.removeOutput(output)
            session.removeInput(input)
            throw CameraError.unavailable
        }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .speed
        if let dimensions = camera.activeFormat.supportedMaxPhotoDimensions.max(by: {
            Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height)
        }) {
            photoOutput.maxPhotoDimensions = dimensions
        }
        cameraDevice = camera
        onExposureSupport?(camera.isExposureModeSupported(.custom))
        configured = true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        if let cameraDevice {
            do { try slowExposure.update(device: cameraDevice, time: CACurrentMediaTime()) }
            catch {
                slowExposure.enabled = false
                onExposureError?("Slow exposure could not be applied: " + error.localizedDescription)
            }
        }
        let sensorImage = CIImage(cvPixelBuffer: buffer)
        if let recorder {
            do {
                let hadFrames = recorder.hasFrames
                try recorder.append(sensorImage, timestamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer), angle: captureAngle)
                if !hadFrames && recorder.hasFrames { onRecordingStarted?() }
            }
            catch {
                recorder.cancel()
                try? FileManager.default.removeItem(at: recorder.url)
                self.recorder = nil
                onRecordingFinished?(.failure(error))
            }
        }
        deliveryLock.lock()
        let pending = deliveryPending
        deliveryLock.unlock()
        guard !pending else { return }
        // Scale only the display branch. Photos and recorded frames bypass it.
        let scale = min(1, 1280 / max(sensorImage.extent.width, sensorImage.extent.height))
        let input = sensorImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let time = CACurrentMediaTime() - epoch
        let moving = simulatedMotion.render(input, enabled: motionEnabled, amount: motionAmount, time: time)
        let processed = CameraEffects.render(moving, effect: effect, time: time)
        let corrected = balance.apply(to: processed, mode: feedbackMode, time: time, context: context)
        guard let image = context.createCGImage(corrected, from: input.extent) else { return }
        deliveryLock.lock()
        deliveryPending = true
        deliveryLock.unlock()
        onFrame?(image)
    }

    func acknowledgeFrame() {
        deliveryLock.lock()
        deliveryPending = false
        deliveryLock.unlock()
    }

    private enum CameraError: LocalizedError {
        case unavailable
        var errorDescription: String? { "The rear camera is unavailable. Try this app on an iPhone or iPad with a rear camera." }
    }
}

@MainActor
final class CameraController: ObservableObject {
    @Published var frame: UIImage?
    @Published var problem: String?
    @Published var captureError: String?
    @Published private(set) var isSavingPhoto = false
    private var photoCaptureInFlight = false
    private var pendingPhotoSaves = 0
    @Published private(set) var isSavingVideo = false
    private var pendingVideoSaves = 0
    @Published private(set) var recordingState = RecordingState.idle
    @Published private(set) var recordingStartedAt: Date?
    @Published private(set) var pendingCaptureCount = CaptureLibrary.pendingFiles().count
    @Published private(set) var retryingSaves = false
    @Published var includeOverlayInPhotos = UserDefaults.standard.bool(forKey: "photo.includeOverlay") {
        didSet { UserDefaults.standard.set(includeOverlayInPhotos, forKey: "photo.includeOverlay") }
    }
    @Published private(set) var supportsSlowExposure: Bool?
    @Published var slowExposureEnabled = UserDefaults.standard.bool(forKey: "exposure.slow") {
        didSet {
            UserDefaults.standard.set(slowExposureEnabled, forKey: "exposure.slow")
            pipeline.setSlowExposure(enabled: slowExposureEnabled, response: exposureResponse)
        }
    }
    @Published var exposureResponse = min(12, max(1, (UserDefaults.standard.object(forKey: "exposure.response") as? Double) ?? 5)) {
        didSet {
            UserDefaults.standard.set(exposureResponse, forKey: "exposure.response")
            pipeline.setSlowExposure(enabled: slowExposureEnabled, response: exposureResponse)
        }
    }
    @Published var feedbackMode = FeedbackMode.stabilize {
        didSet { pipeline.setFeedbackMode(feedbackMode) }
    }
    @Published var simulatedMotionEnabled = UserDefaults.standard.bool(forKey: "simulatedMotion.enabled") {
        didSet {
            UserDefaults.standard.set(simulatedMotionEnabled, forKey: "simulatedMotion.enabled")
            pipeline.setSimulatedMotion(enabled: simulatedMotionEnabled, amount: simulatedMotionAmount)
        }
    }
    @Published var simulatedMotionAmount = min(1, max(0, (UserDefaults.standard.object(forKey: "simulatedMotion.amount") as? Double) ?? 0.45)) {
        didSet {
            UserDefaults.standard.set(simulatedMotionAmount, forKey: "simulatedMotion.amount")
            pipeline.setSimulatedMotion(enabled: simulatedMotionEnabled, amount: simulatedMotionAmount)
        }
    }
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let pipeline = CameraPipeline()
    private let sounds = CaptureSounds()
    private var active = false
    private var angle: CGFloat = 90

    init() {
        pipeline.setSlowExposure(enabled: slowExposureEnabled, response: exposureResponse)
        pipeline.onExposureSupport = { [weak self] supported in
            Task { @MainActor [weak self] in
                self?.supportsSlowExposure = supported
                if !supported { self?.slowExposureEnabled = false }
            }
        }
        pipeline.onExposureError = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.slowExposureEnabled = false
                self?.captureError = message
            }
        }
        pipeline.setSimulatedMotion(enabled: simulatedMotionEnabled, amount: simulatedMotionAmount)
        pipeline.onRecordingStarted = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.recordingState == .starting else { return }
                self.recordingState = .recording
                self.recordingStartedAt = Date()
                self.sounds.play(.recordingStarted)
            }
        }
        pipeline.onRecordingStopping = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.recordingState = .finishing
                self.sounds.play(.recordingStopped)
            }
        }
        pipeline.onRecordingFinished = { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // The finalized file can save independently of the next clip.
                self.recordingState = .idle
                self.recordingStartedAt = nil
                switch result {
                case .success(let url):
                    self.pendingVideoSaves += 1
                    self.isSavingVideo = true
                    await self.saveOriginal(url)
                    self.pendingVideoSaves -= 1
                    self.isSavingVideo = self.pendingVideoSaves > 0
                case .failure(let error):
                    self.captureError = error.localizedDescription
                    self.sounds.play(.error)
                }
                self.refreshPending()
                self.endBackgroundTaskIfFinished()
            }
        }
        pipeline.onFrame = { [weak self] image in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.active { self.frame = UIImage(cgImage: image) }
                self.pipeline.acknowledgeFrame()
            }
        }
        pipeline.onError = { [weak self] message in
            Task { @MainActor [weak self] in
                guard let self, self.active else { return }
                self.problem = message
            }
        }
        pipeline.onRecovery = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.active else { return }
                await self.start()
            }
        }
    }

    func start() async {
        active = true
        let granted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: granted = true
        case .notDetermined: granted = await AVCaptureDevice.requestAccess(for: .video)
        default: granted = false
        }
        guard active else { return }
        guard granted else {
            problem = "Allow Camera access in Settings to start making recursive art."
            return
        }
        problem = nil
        pipeline.start(angle: angle)
    }

    func stop() {
        if isSavingPhoto || isSavingVideo || recordingState != .idle { keepAliveForSave() }
        active = false
        pipeline.stop()
    }

    func takePhoto() {
        guard active, frame != nil, problem == nil, !photoCaptureInFlight, !retryingSaves else { return }
        photoCaptureInFlight = true
        pendingPhotoSaves += 1
        isSavingPhoto = true
        pipeline.capturePhoto { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.photoCaptureInFlight = false
                do {
                    let data = try result.get()
                    let url = try await CaptureLibrary.persistPhoto(data)
                    await self.saveOriginal(url)
                } catch {
                    self.captureError = error.localizedDescription
                    sounds.play(.error)
                }
                self.pendingPhotoSaves -= 1
                self.isSavingPhoto = self.pendingPhotoSaves > 0
                self.refreshPending()
                self.endBackgroundTaskIfFinished()
            }
        }
        // Submission always precedes the optional, asynchronous sound cue.
        sounds.play(.photo)
    }

    func takeArtworkPhoto(_ image: UIImage) {
        guard active, !retryingSaves else { return }
        pendingPhotoSaves += 1
        isSavingPhoto = true
        Task {
            do {
                let url = try await CaptureLibrary.persistArtwork(image)
                await saveOriginal(url)
            } catch {
                captureError = error.localizedDescription
                sounds.play(.error)
            }
            pendingPhotoSaves -= 1
            isSavingPhoto = pendingPhotoSaves > 0
            refreshPending()
            endBackgroundTaskIfFinished()
        }
        sounds.play(.photo)
    }

    func toggleRecording() {
        if recordingState == .recording || recordingState == .starting {
            keepAliveForSave()
            recordingState = .finishing
            pipeline.stopRecording()
            return
        }
        guard recordingState == .idle, !retryingSaves, active, frame != nil, problem == nil else { return }
        recordingState = .starting
        pipeline.startRecording { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success:
                    break // Confirm with sound only when the first frame is written.
                case .failure(let error):
                    self.recordingState = .idle
                    self.captureError = error.localizedDescription
                    self.sounds.play(.error)
                    self.endBackgroundTaskIfFinished()
                }
            }
        }
    }

    func retryPendingCaptures() {
        guard !retryingSaves, !isSavingPhoto, !isSavingVideo, recordingState == .idle else { return }
        retryingSaves = true
        Task {
            for url in CaptureLibrary.pendingFiles() {
                do { try await CaptureLibrary.saveToPhotos(url) }
                catch { captureError = error.localizedDescription; break }
            }
            retryingSaves = false
            refreshPending()
            endBackgroundTaskIfFinished()
        }
    }

    private func saveOriginal(_ url: URL) async {
        do {
            try await CaptureLibrary.saveToPhotos(url)
        } catch {
            captureError = error.localizedDescription + " Your original remains in the app for retry."
            sounds.play(.error)
        }
    }

    private func refreshPending() { pendingCaptureCount = CaptureLibrary.pendingFiles().count }

    private func keepAliveForSave() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Finish camera capture") { [weak self] in
            guard let self else { return }
            if !self.active { self.pipeline.stopRecording() }
            if self.backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(self.backgroundTask)
                self.backgroundTask = .invalid
            }
        }
    }

    private func endBackgroundTaskIfFinished() {
        guard !isSavingPhoto, !isSavingVideo, (active || recordingState == .idle), !retryingSaves, backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    func selectEffect(_ effect: ArtEffect) {
        pipeline.selectEffect(effect)
    }

    func updateOrientation(_ orientation: UIInterfaceOrientation) {
        guard let rotation = CameraOrientation.rotationAngle(for: orientation) else { return }
        angle = rotation
        pipeline.rotate(to: angle)
    }
}


enum RecordingState {
    case idle, starting, recording, finishing
    var buttonTitle: String {
        switch self {
        case .idle: "Record video"
        case .starting: "Starting…"
        case .recording: "Stop & save video"
        case .finishing: "Finishing video…"
        }
    }
}


/// Interface landscape directions are opposite to UIDeviceOrientation directions.
/// The rear sensor's unrotated image corresponds to interface landscape-right.
enum CameraOrientation {
    static func rotationAngle(for orientation: UIInterfaceOrientation) -> CGFloat? {
        switch orientation {
        case .portrait: 90
        case .portraitUpsideDown: 270
        case .landscapeLeft: 180
        case .landscapeRight: 0
        default: nil
        }
    }
}
