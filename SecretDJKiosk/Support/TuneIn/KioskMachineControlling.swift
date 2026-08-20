import SecretDJAPI
import SecretDJDomain
import SharedFeatures

/// The kiosk's own production ``SharedFeatures/MachineControlling`` — calls
/// straight through to ``SecretDJAPI/APIClient``'s `machinecontrol` endpoint
/// with the skip/blacklist action codes, same shape as the consumer's own
/// `APIClientMachineControlling` (`SecretDJ/Support/TuneIn/APIClientMachineControlling.swift`;
/// see ``KioskAtmosphereChanging``'s doc comment on the kiosk-local-copy
/// convention).
///
/// D13 resolved **no kiosk-side moderation** — no skip/blacklist tools are
/// product surfaces on this app, matching legacy exactly: LEGACY.md's own
/// "Employee control of the music" section is explicit that skip/blacklist
/// are gated on a venue's `machineControl` privilege flag, granted to a
/// phone account, never a kiosk one ("an employee moderates from the
/// consumer phone app... not from the kiosk"). ``SharedFeatures/TuneInScreenModel``
/// only ever shows the moderation buttons this adapter serves when the
/// server's own `actions` array on the tapped song grants them
/// (`showsSkipButton`/`showsNeverPlayButton`), so a kiosk venue account never
/// sees them and this endpoint stays unreachable in practice — enforced by
/// the server-driven action model every other button in this app already
/// relies on, not by a client-side kill switch here.
struct KioskMachineControlling: MachineControlling {
	private let client: APIClient
	private let sessionStore: SessionStore

	init(client: APIClient, sessionStore: SessionStore) {
		self.client = client
		self.sessionStore = sessionStore
	}

	func moderate(
		_ action: TuneInModerationAction,
		songId: String,
		venueId: String,
	) async throws(MachineControlError) -> MachineControlResult {
		let session = await MainActor.run { (sessionStore.user?.personId, sessionStore.credential) }
		guard let userId = session.0, let credential = session.1 else {
			throw .notSignedIn
		}

		do {
			let response = try await client.machineControl(
				userId: userId,
				venueId: venueId,
				action: wireAction(for: action),
				item: songId,
				value: 0,
				credential: credential,
			)
			if let rotatedToken = response.rotatedToken {
				await MainActor.run { sessionStore.rotateToken(rotatedToken) }
			}
			guard response.payload.returnCode == 0 else {
				throw MachineControlError.server(message: response.payload.text)
			}
			return MachineControlResult(message: response.payload.text)
		} catch let error as MachineControlError {
			throw error
		} catch {
			throw .connection
		}
	}

	private func wireAction(for action: TuneInModerationAction) -> SecretDJAPI.MachineControlAction {
		switch action {
		case .skip: .skip
		case .neverPlay: .blacklist
		}
	}
}
