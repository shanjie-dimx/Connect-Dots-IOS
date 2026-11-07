import AVFoundation
import SwiftUI

/// Plays the short effects in Sounds/. Uses the ambient session so the silent switch and the
/// player's own music are respected.
final class SoundPlayer: ObservableObject {
    enum Effect: String, CaseIterable {
        case pick, connect, blocked, tap, undo, win, whoosh
    }

    static let shared = SoundPlayer()
    private static let mutedKey = "connect-dots-muted"

    @Published var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: Self.mutedKey) }
    }

    private var players: [Effect: AVAudioPlayer] = [:]

    private init() {
        isMuted = UserDefaults.standard.bool(forKey: Self.mutedKey)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for effect in Effect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav", subdirectory: "Sounds")
                ?? Bundle.main.url(forResource: effect.rawValue, withExtension: "wav"),
                let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[effect] = player
        }
    }

    func play(_ effect: Effect, volume: Float = 1) {
        guard !isMuted, let player = players[effect] else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }
}

/// Speaker button that mutes and unmutes all effects.
struct SoundToggle: View {
    @ObservedObject private var sound = SoundPlayer.shared

    var body: some View {
        Button {
            sound.isMuted.toggle()
            sound.play(.tap)
        } label: {
            Image(systemName: sound.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
        }
        .buttonStyle(IconButtonStyle())
        .accessibilityLabel(sound.isMuted ? "Turn sound on" : "Turn sound off")
        .accessibilityIdentifier("sound")
    }
}
