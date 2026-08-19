import SecretDJAPI

/// The production ``KioskSignInServicing``: calls straight through to
/// ``SecretDJAPI/APIClient``'s `signin`, mapping ``SecretDJAPI/APIError``
/// to ``KioskSignInError`` and enforcing the venue-account business rule
/// (LEGACY.md "Venue login and the skin system") that ``KioskSignInError``
/// documents.
struct APIClientKioskSignInService: KioskSignInServicing {
	private let client: APIClient

	init(client: APIClient) {
		self.client = client
	}

	func signIn(screenName: String, passwordHash: String) async throws(KioskSignInError) -> KioskAuthenticatedSession {
		let response: APIResponse<LoginDetails>
		do {
			response = try await client.signIn(screenName: screenName, passwordHash: passwordHash)
		} catch {
			throw KioskSignInError(error)
		}

		guard let forcedVenueId = response.payload.forcedVenueId else {
			throw KioskSignInError.notAVenueAccount
		}

		return KioskAuthenticatedSession(
			personId: response.payload.personId,
			screenName: response.payload.screenName,
			forcedVenueId: forcedVenueId,
			rotatedToken: response.rotatedToken,
		)
	}
}
