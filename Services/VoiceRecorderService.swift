import AVFoundation
import Combine

@MainActor protocol VoiceCaptureDevice {
    var currentTime: Double { get }
    func record() -> Bool
    func stop()
}
@MainActor private final class NativeVoiceCapture: VoiceCaptureDevice {
    private let recorder: AVAudioRecorder
    init(url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64_000, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
        recorder.prepareToRecord()
    }
    var currentTime: Double { recorder.currentTime }
    func record() -> Bool { recorder.record() }
    func stop() { recorder.stop() }
}

@MainActor final class VoiceRecorderService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    typealias Factory = @MainActor (URL) throws -> any VoiceCaptureDevice
    @Published private(set) var recording = false
    @Published private(set) var requesting = false
    @Published private(set) var elapsed = 0.0
    @Published private(set) var draft: URL?
    @Published private(set) var error: String?
    @Published private(set) var previewing = false
    private let permission: @MainActor () async -> Bool
    private let factory: Factory
    private let directory: URL
    private var capture: (any VoiceCaptureDevice)?
    private var captureURL: URL?
    private var timer: Timer?
    private var preview: AVAudioPlayer?
    private var generation = 0
    private var interruption: NSObjectProtocol?
    init(directory: URL? = nil, permission: @escaping @MainActor () async -> Bool = { await AVAudioApplication.requestRecordPermission() }, factory: Factory? = nil) {
        self.directory = directory ?? FileManager.default.temporaryDirectory.appendingPathComponent("NativeRecitationDrafts")
        self.permission = permission
        self.factory = factory ?? { try NativeVoiceCapture(url: $0) }
        super.init()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-recording") {
            self.testCapture = true
        }
        #endif
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt, raw == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak self] in self?.stop() }
        }
    }
    #if DEBUG
    private var testCapture = false
    #endif
    func start() async {
        guard !recording, !requesting, draft == nil else { return }
        generation += 1; let token = generation
        requesting = true; error = nil
        let allowed: Bool
        #if DEBUG
        if testCapture { allowed = true } else { allowed = await permission() }
        #else
        allowed = await permission()
        #endif
        guard token == generation else { return }
        requesting = false
        guard allowed else { error = "Autorise le microphone dans les réglages de l’iPhone pour enregistrer ta récitation."; return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent("\(UUID().uuidString).m4a")
            captureURL = file
            let device: any VoiceCaptureDevice
            #if DEBUG
            device = testCapture ? try TestVoiceCapture(url: file) : try factory(file)
            #else
            device = try factory(file)
            #endif
            capture = device
            guard device.record() else { throw URLError(.cannotCreateFile) }
            recording = true; elapsed = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.recording else { return }
                    self.elapsed = self.capture?.currentTime ?? 0
                    if self.elapsed >= 1_800 { self.stop() }
                }
            }
        } catch {
            capture?.stop(); capture = nil
            if let captureURL { try? FileManager.default.removeItem(at: captureURL) }
            captureURL = nil; self.error = "Le microphone n’a pas pu démarrer. Réessaie après avoir fermé les autres applications audio."
        }
    }
    func stop() {
        guard recording, let capture else { return }
        elapsed = capture.currentTime
        capture.stop(); self.capture = nil; recording = false
        timer?.invalidate(); timer = nil
        draft = captureURL; captureURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func togglePreview() {
        if previewing { preview?.stop(); previewing = false; return }
        guard let draft else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: draft)
            player.delegate = self
            preview = player; previewing = player.play()
        } catch { self.error = "Cet enregistrement n’a pas pu être relu." }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in guard let self, self.preview === player else { return }; self.previewing = false }
    }
    func discard() {
        generation += 1; requesting = false
        stop(); preview?.stop(); preview = nil; previewing = false
        if let draft { try? FileManager.default.removeItem(at: draft) }
        draft = nil; elapsed = 0; error = nil
    }
    deinit {
        timer?.invalidate()
        if let interruption { NotificationCenter.default.removeObserver(interruption) }
    }
}
#if DEBUG
@MainActor private final class TestVoiceCapture: VoiceCaptureDevice {
    private let url: URL
    private var started = Date.now
    init(url: URL) throws { self.url = url }
    var currentTime: Double { max(1, Date.now.timeIntervalSince(started)) }
    func record() -> Bool {
        guard let root = Bundle.main.resourceURL else { return false }
        do { try FileManager.default.copyItem(at: root.appendingPathComponent("ReaderTestFixtures/audio.wav"), to: url); started = .now; return true } catch { return false }
    }
    func stop() {}
}
#endif
