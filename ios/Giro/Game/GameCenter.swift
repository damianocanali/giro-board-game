import GameKit
import Observation
import UIKit

/// Game Center sign-in and leaderboards. Playing without it is fine: nothing is sent until the player is signed in.
@MainActor @Observable
final class GameCenter {
    static let shared = GameCenter()

    /// Leaderboard ids, as set up in App Store Connect.
    enum Board {
        /// Passport stamps collected.
        static let explorer = "rollabout.explorer"
        /// What your land is worth, in coins.
        static let builder = "rollabout.builder"
    }

    private(set) var isSignedIn = false
    /// Last score sent per board, so unchanged scores aren't sent again.
    @ObservationIgnored private var reported: [String: Int] = [:]

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, _ in
            Task { @MainActor in
                if let vc { Self.topController()?.present(vc, animated: true) }
                self?.isSignedIn = GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    /// Sends the scores that changed since the last report.
    func report(stamps: Int, landValue: Int) {
        guard isSignedIn else { return }
        let scores = [Board.explorer: stamps, Board.builder: landValue].filter { reported[$0.key] != $0.value }
        guard !scores.isEmpty else { return }
        Task {
            for (id, v) in scores {
                do {
                    try await GKLeaderboard.submitScore(v, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [id])
                    reported[id] = v
                } catch {}
            }
        }
    }

    func showLeaderboards() {
        GKAccessPoint.shared.trigger(state: .leaderboards) {}
    }

    private static func topController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        var c = scene?.keyWindow?.rootViewController
        while let p = c?.presentedViewController { c = p }
        return c
    }
}
