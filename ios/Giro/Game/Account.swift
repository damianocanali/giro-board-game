import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Observation

/// The player's account: Sign in with Apple through Firebase, with the save kept in Firestore at `saves/{uid}`.
/// Playing as a guest stays possible; the save then lives only on this phone.
@MainActor @Observable
final class Account {
    static let shared = Account()

    /// What to do with the two saves after signing in.
    enum Sync { case keepPhone, useCloud(Data), ask(cloud: Data), failed }

    private(set) var uid: String?
    var error: String?
    var isSignedIn: Bool { uid != nil }

    @ObservationIgnored private var nonce: String?
    @ObservationIgnored private var uploadTask: Task<Void, Never>?
    /// Uploads wait until the phone's save and the cloud save have been reconciled.
    @ObservationIgnored private var ready = false

    /// Which account this phone's save was last synced with, and when.
    private static let linkedKey = "giro.cloud.uid", syncedKey = "giro.cloud.syncedAt"

    static func configure() {
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
    }

    private init() {
        Self.configure()
        uid = Auth.auth().currentUser?.uid
    }

    private var doc: DocumentReference? { uid.map { Firestore.firestore().collection("saves").document($0) } }

    // MARK: Sign in with Apple

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let n = Self.randomNonce()
        nonce = n
        request.requestedScopes = []
        request.nonce = Self.sha256(n)
    }

    /// Finishes Sign in with Apple. True once signed in to Firebase.
    func complete(_ result: Result<ASAuthorization, Error>) async -> Bool {
        error = nil
        guard case .success(let auth) = result,
              let apple = auth.credential as? ASAuthorizationAppleIDCredential,
              let token = apple.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
              let nonce else {
            if case .failure(let e) = result, (e as? ASAuthorizationError)?.code != .canceled { error = "Couldn't sign in. Try again." }
            return false
        }
        do {
            let r = try await Auth.auth().signIn(with: OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: nil))
            uid = r.user.uid
            return true
        } catch {
            self.error = "Couldn't sign in. Try again."
            return false
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        uploadTask?.cancel()
        uid = nil
        ready = false
        UserDefaults.standard.removeObject(forKey: Self.linkedKey)
    }

    // MARK: Cloud save

    /// Compares the cloud save with the phone's. Reads from the server only, so being offline never
    /// looks like an empty account (which would overwrite it).
    func sync(hasLocalSave: Bool) async -> Sync {
        guard let uid, let doc else { return .failed }
        let snap: DocumentSnapshot
        do { snap = try await doc.getDocument(source: .server) } catch {
            self.error = "Couldn't reach your saved game. It will sync next time."
            return .failed
        }
        guard let s = snap.data()?["data"] as? String else { return .keepPhone }
        let cloud = Data(s.utf8)
        let updated = (snap.data()?["updated"] as? Timestamp)?.dateValue().timeIntervalSince1970 ?? 0
        let d = UserDefaults.standard
        if d.string(forKey: Self.linkedKey) == uid {
            // Another phone saved since this one last did.
            return updated > d.double(forKey: Self.syncedKey) + 1 ? .useCloud(cloud) : .keepPhone
        }
        return hasLocalSave ? .ask(cloud: cloud) : .useCloud(cloud)
    }

    func markReady() { ready = true }

    /// Uploads the save a few seconds after the last change, so a burst of saves is one write.
    func upload(_ data: Data) {
        guard ready, let uid, let doc else { return }
        uploadTask?.cancel()
        uploadTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            let now = Date()
            do {
                try await doc.setData(["data": String(decoding: data, as: UTF8.self), "updated": Timestamp(date: now)])
                UserDefaults.standard.set(uid, forKey: Self.linkedKey)
                UserDefaults.standard.set(now.timeIntervalSince1970, forKey: Self.syncedKey)
            } catch {}
        }
    }

    // MARK: Nonce

    private static func randomNonce() -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var g = SystemRandomNumberGenerator()
        return String((0..<32).map { _ in chars.randomElement(using: &g)! })
    }

    private static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
