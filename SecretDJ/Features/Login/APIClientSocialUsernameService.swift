import SecretDJAPI

/// The production ``SocialUsernameServicing``: calls straight through to
/// ``SecretDJAPI/APIClient/setUserDetails(userId:firstName:lastName:screenName:email:gender:passwordHash:credential:)``,
/// mapping ``APIError`` to this feature's own ``AuthenticationError``.
struct APIClientSocialUsernameService: SocialUsernameServicing {
	private let client: APIClient

	init(client: APIClient) {
		self.client = client
	}

	func setScreenName(
		userId: String,
		screenName: String,
		credential: APICredential,
	) async throws(AuthenticationError) -> ScreenNameUpdateOutcome {
		do {
			let response = try await client.setUserDetails(
				userId: userId,
				screenName: screenName,
				credential: credential,
			)
			return ScreenNameUpdateOutcome(
				succeeded: response.payload.returnCode == 0,
				message: response.payload.message,
				rotatedToken: response.rotatedToken,
			)
		} catch {
			throw AuthenticationError(error)
		}
	}
}
