import AVFoundation

/// Loops the background tune gaplessly. Uses the ambient audio session, so it mixes with the
/// player's own music and goes quiet with the silent switch.
@MainActor
final class MusicPlayer {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private var buffer: AVAudioPCMBuffer?
    private var observers: [NSObjectProtocol] = []

    var isOn = false {
        didSet { isOn ? play() : stop() }
    }

    init() {
        guard let url = Bundle.main.url(forResource: "giro-theme", withExtension: "m4a"),
              let file = try? AVAudioFile(forReading: url),
              let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buf)) != nil else { return }
        buffer = buf
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: buf.format)
        node.volume = 0.45
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            let ended = (n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.ended.rawValue
            if ended { MainActor.assumeIsolated { self?.restartIfNeeded() } }
        })
        observers.append(nc.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.restartIfNeeded() }
        })
    }

    private func play() {
        guard let buffer else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)
        if !engine.isRunning { try? engine.start() }
        if !node.isPlaying {
            node.scheduleBuffer(buffer, at: nil, options: .loops)
            node.play()
        }
    }

    private func stop() {
        node.stop()
        engine.pause()
    }

    private func restartIfNeeded() {
        guard isOn else { return }
        node.stop()
        play()
    }
}
