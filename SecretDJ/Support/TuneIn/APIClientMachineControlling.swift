import SecretDJAPI
import SecretDJDomain
import SharedFeatures

/// The production ``SharedFeatures/MachineControlling``: calls straight
/// through to ``SecretDJAPI/APIClient``'s `machinecontrol` endpoint with the
/// skip/blacklist action codes (``SecretDJAPI/MachineControlAction/skip``/
/// ``SecretDJAPI/MachineControlAction/blacklist``), reading the signed-in
/// user/credential fresh on every call and rotating the session's token when
/// the response carries one — same shape as `APIClientAtmosphereChanging`,
/// this endpoint's sibling write for the mood/atmosphere action.
struct APIClientMachineControlling: MachineControlling {
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
