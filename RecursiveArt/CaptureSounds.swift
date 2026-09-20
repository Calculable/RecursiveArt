import AVFoundation

/// Short local cues; no microphone input and no audio is added to recorded video.
final class CaptureSounds: @unchecked Sendable {
    enum Signal: CaseIterable, Sendable {
        case photo, recordingStarted, recordingStopped, error

        var notes: [(frequency: Double, start: Double, duration: Double)] {
            switch self {
            case .photo: [(1500, 0, 0.045), (1050, 0.05, 0.055)]
            case .recordingStarted: [(660, 0, 0.11), (990, 0.14, 0.16)]
            case .recordingStopped: [(990, 0, 0.11), (660, 0.14, 0.16)]
            case .error: [(220, 0, 0.12), (220, 0.19, 0.18)]
            }
        }
    }

    private let queue = DispatchQueue(label: "art.capture-sounds", qos: .userInitiated)
    private let playbackOverride: (@Sendable (Signal) -> Void)?
    private var players: [Signal: AVAudioPlayer] = [:]

    init(playbackOverride: (@Sendable (Signal) -> Void)? = nil) {
        self.playbackOverride = playbackOverride
        guard playbackOverride == nil else { return }
        queue.async { [self] in
            for signal in Signal.allCases {
                if let player = try? AVAudioPlayer(data: Self.wavData(for: signal)) {
                    player.volume = 0.8
                    player.prepareToPlay()
                    players[signal] = player
                }
            }
        }
    }

    /// Fire-and-forget: session setup, decoding, and playback never run on the UI
    /// actor or camera queue, even on the first cue or after an interruption.
    func play(_ signal: Signal) {
        queue.async { [self] in
            if let playbackOverride { playbackOverride(signal) }
            else { playOnAudioQueue(signal) }
        }
    }

    private func playOnAudioQueue(_ signal: Signal) {
        do {
            let session = AVAudioSession.sharedInstance()
            // Respect Silent Mode and mix with music instead of interrupting it.
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let player: AVAudioPlayer
            if let cached = players[signal] { player = cached }
            else {
                player = try AVAudioPlayer(data: Self.wavData(for: signal))
                player.volume = 0.8
                players[signal] = player
            }
            player.currentTime = 0
            player.prepareToPlay()
            if !player.play() { print("Capture sound could not start.") }
        } catch {
            // Audio interruptions must not prevent photo capture or recording.
            print("Capture sound unavailable: \(error.localizedDescription)")
        }
    }

    /// PCM WAV with smooth envelopes, kept in memory so cues need no external assets.
    static func wavData(for signal: Signal) -> Data {
        let sampleRate = 44_100
        let duration = signal.notes.map { $0.start + $0.duration }.max()! + 0.025
        let sampleCount = Int(ceil(duration * Double(sampleRate)))
        var pcm = Data(capacity: sampleCount * 2)
        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            var value = 0.0
            for note in signal.notes {
                let age = time - note.start
                guard age >= 0, age < note.duration else { continue }
                let attack = min(1, age / 0.006)
                let release = min(1, (note.duration - age) / 0.025)
                let envelope = attack * release * exp(-age * 3)
                value += sin(2 * .pi * note.frequency * age) * envelope * 0.3
            }
            append(Int16(max(-1, min(1, value)) * Double(Int16.max)), to: &pcm)
        }
        var data = Data("RIFF".utf8)
        append(UInt32(36 + pcm.count), to: &data)
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data) // Linear PCM.
        append(UInt16(1), to: &data) // Mono.
        append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate * 2), to: &data)
        append(UInt16(2), to: &data)
        append(UInt16(16), to: &data)
        data.append(contentsOf: "data".utf8)
        append(UInt32(pcm.count), to: &data)
        data.append(pcm)
        return data
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}
