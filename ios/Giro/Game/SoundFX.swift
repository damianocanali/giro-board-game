import AVFoundation

/// Short sound effects. Each sound has a couple of preloaded players so quick repeats can overlap.
@MainActor
final class SoundFX {
    enum Sound: String, CaseIterable {
        case coin, build, upgrade, achievement, stamp, dice, whoosh
    }

    var isOn = true
    private var players: [Sound: [AVAudioPlayer]] = [:]
    private var next: [Sound: Int] = [:]

    init() {
        for s in Sound.allCases {
            guard let url = Bundle.main.url(forResource: "sfx-\(s.rawValue)", withExtension: "wav") else { continue }
            players[s] = (0..<3).compactMap { _ in
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.prepareToPlay()
                return p
            }
        }
    }

    func play(_ s: Sound, volume: Float = 0.8) {
        guard isOn, let list = players[s], !list.isEmpty else { return }
        let i = (next[s] ?? 0) % list.count
        next[s] = i + 1
        let p = list[i]
        p.volume = volume
        p.currentTime = 0
        p.play()
    }
}
