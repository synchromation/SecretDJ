import Observation

/// Drives the app's signed-in session: the current user, venue, and
/// ``APICredential``, restored from persistence at launch and kept in sync
/// with it as the session changes.
///
/// A session counts as signed in only when *both* a saved snapshot and a
/// saved credential are present — a snapshot without a credential (or a
/// credential without a snapshot) can't sign requests, so
/// ``init(snapshotStore:credentialStore:)`` treats either as no session at
/// all (LEGACY.md "Domain model and persistence": `UserManager
/// .requiresLogin()`'s "no cached user id or empty keychain password"
/// gate).
@Observable
@MainActor
public final class SessionStore {
	public private(set) var user: SessionUser?
	public private(set) var venue: SessionVenue?
	public private(set) var credential: APICredential?

	private let snapshotStore: any SessionSnapshotStoring
	private let credentialStore: any CredentialStoring

	public init(snapshotStore: any SessionSnapshotStoring, credentialStore: any CredentialStoring) {
		self.snapshotStore = snapshotStore
		self.credentialStore = credentialStore

		let snapshot = snapshotStore.savedSnapshot()
		let savedCredential = credentialStore.savedCredential()

		if let snapshot, let savedCredential {
			user = snapshot.user
			venue = snapshot.venue
			credential = savedCredential
		} else {
			user = nil
			venue = nil
			credential = nil
		}
	}

	/// Whether a user is currently signed in.
	public var isSignedIn: Bool {
		user != nil
	}

	/// Signs in `user` (checked into `venue`, if any) and persists the
	/// session to both stores.
	public func signIn(user: SessionUser, venue: SessionVenue?, credential: APICredential) {
		self.user = user
		self.venue = venue
		self.credential = credential

		snapshotStore.save(SessionSnapshot(user: user, venue: venue))
		credentialStore.save(credential)
	}

	/// Rotates the signed-in session's token after an authenticated call whose
	/// response carried a fresh one — almost every response does
	/// (``APIResponse/rotatedToken``'s doc comment). A no-op when not signed
	/// in, since there is no credential to rotate.
	public func rotateToken(_ token: String) {
		guard let credential else { return }

		let updated = APICredential(token: token, passwordHash: credential.passwordHash)
		self.credential = updated
		credentialStore.save(updated)
	}

	/// Updates the signed-in credential's password hash after a successful
	/// password change (S6.11's Settings flow), keeping the current token —
	/// mirrors ``rotateToken(_:)``'s shape but for the other half of
	/// ``APICredential``. A no-op when not signed in.
	public func updatePasswordHash(_ passwordHash: String) {
		guard let credential else { return }

		let updated = APICredential(token: credential.token, passwordHash: passwordHash)
		self.credential = updated
		credentialStore.save(updated)
	}

	/// Updates the signed-in user's screen name after a successful details
	/// change (S6.11's Settings flow), keeping the current venue — mirrors
	/// ``rotateToken(_:)``'s shape but for ``user`` instead of ``credential``.
	/// A no-op when not signed in.
	public func updateScreenName(_ screenName: String) {
		guard let user else { return }

		let updated = SessionUser(personId: user.personId, screenName: screenName)
		self.user = updated
		snapshotStore.save(SessionSnapshot(user: updated, venue: venue))
	}

	/// Clears the session and wipes both persistence stores.
	public func signOut() {
		user = nil
		venue = nil
		credential = nil

		snapshotStore.save(nil)
		credentialStore.save(nil)
	}
}
