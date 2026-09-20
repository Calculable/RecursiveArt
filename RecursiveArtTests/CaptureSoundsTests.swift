import XCTest
import AVFoundation
@testable import RecursiveArt

final class CaptureSoundsTests: XCTestCase {
    func testSlowSoundPlaybackDoesNotBlockTheCaller() async {
        let started = expectation(description: "Audio worker started")
        let finished = expectation(description: "Audio worker finished")
        let gate = DispatchSemaphore(value: 0)
        let sounds = CaptureSounds(playbackOverride: { _ in
            started.fulfill()
            _ = gate.wait(timeout: .now() + 2)
            finished.fulfill()
        })
        let begin = Date()
        sounds.play(.photo)
        XCTAssertLessThan(Date().timeIntervalSince(begin), 0.5)
        await fulfillment(of: [started], timeout: 1)
        gate.signal()
        await fulfillment(of: [finished], timeout: 1)
    }

    @MainActor
    func testEveryCueDecodesAsShortDistinctNonClippingAudio() throws {
        var distinct = Set<Data>()
        for signal in CaptureSounds.Signal.allCases {
            let data = CaptureSounds.wavData(for: signal)
            XCTAssertTrue(distinct.insert(data).inserted)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
            defer { try? FileManager.default.removeItem(at: url) }
            try data.write(to: url)
            let file = try AVAudioFile(forReading: url)
            XCTAssertEqual(file.processingFormat.sampleRate, 44_100)
            XCTAssertEqual(file.processingFormat.channelCount, 1)
            let duration = Double(file.length) / file.processingFormat.sampleRate
            XCTAssertGreaterThan(duration, 0.1)
            XCTAssertLessThan(duration, 0.5)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
            try file.read(into: buffer)
            let samples = try XCTUnwrap(buffer.floatChannelData)[0]
            let values = Array(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))
            XCTAssertGreaterThan(values.map { abs($0) }.max()!, 0.1)
            XCTAssertLessThan(values.map { abs($0) }.max()!, 0.5)
            XCTAssertEqual(values.first!, 0, accuracy: 0.001)
            XCTAssertTrue(values.suffix(500).allSatisfy { abs($0) < 0.001 })
        }
    }
}
