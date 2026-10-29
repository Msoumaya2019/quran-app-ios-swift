import XCTest
import AVFoundation
import MediaPlayer
@testable import CoranNative

@MainActor final class RoqyaPlaybackTests: XCTestCase {
    private func fixture() throws -> URL {
        try XCTUnwrap(Bundle.main.resourceURL?.appendingPathComponent("ReaderTestFixtures/audio.wav"))
    }
    private func ready(_ service: RecitationPlaybackService) async throws {
        for _ in 0..<60 { if service.duration > 0 { return }; try await Task.sleep(for: .milliseconds(100)) }
        XCTFail("Local test audio should have a duration")
    }
    func testSleepTimerUsesElapsedTimeAndClearsWhenReconfigured() {
        var timer = PlaybackSleepTimer()
        timer.set(.five, now: 100)
        XCTAssertEqual(timer.remaining(now: 399), 1); XCTAssertFalse(timer.expired(now: 399))
        XCTAssertTrue(timer.expired(now: 400))
        timer.set(.thirty, now: 200); XCTAssertEqual(timer.deadline, 2000)
        timer.set(.end, now: 300); XCTAssertNil(timer.deadline); XCTAssertFalse(timer.expired(now: 99999))
        timer.set(.off, now: 400); XCTAssertNil(timer.remaining(now: 500))
    }
    func testRemotePausePlayPositionSpeedAndMetadata() async throws {
        let service = RecitationPlaybackService(); defer { service.stop() }
        try service.playStream(url: fixture(), id: "first", title: "Technical title", artist: "Technical artist")
        try await ready(service)
        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, "Technical title")
        service.handleRemote(.pause); XCTAssertTrue(service.paused)
        service.handleRemote(.seek(20)); XCTAssertEqual(service.elapsed, 20, accuracy: 0.1)
        service.handleRemote(.forward); XCTAssertEqual(service.elapsed, 35, accuracy: 0.1)
        service.handleRemote(.backward); XCTAssertEqual(service.elapsed, 20, accuracy: 0.1)
        service.setSpeed(1.25); service.handleRemote(.play); XCTAssertFalse(service.paused)
        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 1.25)
        service.handleRemote(.stop); XCTAssertNil(service.activeID)
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }
    func testExpiredTimerPausesAndPreservesAudioThenDoesNotAffectReplacement() async throws {
        let service = RecitationPlaybackService(); defer { service.stop() }
        try service.playStream(url: fixture(), id: "first")
        service.setSleepTimer(.five)
        let deadline = try XCTUnwrap(service.sleepTimer.deadline)
        service.checkSleepTimer(now: deadline + 1)
        XCTAssertTrue(service.paused); XCTAssertEqual(service.activeID, "first"); XCTAssertEqual(service.sleepTimer.option, .off)
        service.handleRemote(.play); XCTAssertFalse(service.paused)
        service.setSleepTimer(.ten)
        try service.playStream(url: fixture(), id: "second")
        service.checkSleepTimer(now: deadline + 1)
        XCTAssertFalse(service.paused); XCTAssertEqual(service.activeID, "second"); XCTAssertEqual(service.sleepTimer.option, .off)
    }
    func testEndOfAudioClearsEndTimerAndRemoteCommands() async throws {
        let service = RecitationPlaybackService(); defer { service.stop() }
        try service.playStream(url: fixture(), id: "end")
        try await ready(service); service.setSleepTimer(.end)
        service.seekStream(service.duration - 0.2)
        for _ in 0..<40 { if service.activeID == nil { break }; try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertNil(service.activeID); XCTAssertEqual(service.sleepTimer.option, .off)
        XCTAssertFalse(MPRemoteCommandCenter.shared().playCommand.isEnabled)
    }
    func testFocusChangeClearsTimerAndLockScreenMetadata() throws {
        let service = RecitationPlaybackService(), next = RecitationPlaybackService()
        defer { service.stop(); next.stop() }
        try service.playStream(url: fixture(), id: "roqya")
        service.setSleepTimer(.five); next.reserveFocus {}
        XCTAssertNil(service.activeID); XCTAssertEqual(service.sleepTimer.option, .off)
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }
    func testInterruptionPausesWithoutAutomaticallyRestarting() async throws {
        let service = RecitationPlaybackService(); defer { service.stop() }
        try service.playStream(url: fixture(), id: "interrupted")
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: NSNumber(value: AVAudioSession.InterruptionType.began.rawValue)])
        for _ in 0..<10 { if service.paused { break }; await Task.yield() }
        XCTAssertTrue(service.paused); XCTAssertEqual(service.activeID, "interrupted")
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: NSNumber(value: AVAudioSession.InterruptionType.ended.rawValue)])
        await Task.yield(); XCTAssertTrue(service.paused)
    }
}
