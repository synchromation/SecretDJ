import Foundation
import SecretDJDomain

/// `signin`/`createuser`/`applesignin`/`facebooksignin`/`resetpassword` — the
/// endpoints the legacy auth scheme's sig-exclusion list exempts from
/// signing (LEGACY.md "Backend API and Spotify integration" → "Auth scheme:
/// rotating token + HMAC signature"), typed over ``APIClient``.
extension APIClient {
	/// `signin` — ported from `secretdjv3/LoginAPIAccess.swift`'s
	/// `login(screenName:password:)`. `passwordHash` is the SHA-1 hex digest
	/// (``PasswordHashing/sha1Hex(_:)``), never the plaintext password.
	public func signIn(
		screenName: String,
		passwordHash: String,
	) async throws(APIError) -> APIResponse<LoginDetails> {
		let response = try await execute(
			endpoint: "signin",
			parameters: ["screenname": screenName, "password": passwordHash],
			signed: false,
			credential: nil,
			decodingPayloadAs: SignInWirePayload.self,
		)
		return APIResponse(
			payload: LoginDetails(
				personId: response.payload.personId,
				screenName: screenName,
				created: false,
				forcedVenueId: response.payload.forcedVenueId,
				issuedCredential: nil,
			),
			rotatedToken: response.rotatedToken,
		)
	}

	/// `createuser` — ported from `secretdjv3/LoginAPIAccess.swift`'s
	/// `signUp(firstName:lastName:gender:email:screenName:password:)`.
	/// `passwordHash` is the SHA-1 hex digest, never plaintext.
	public func createUser(
		firstName: String,
		lastName: String,
		gender: Gender,
		email: String,
		screenName: String,
		passwordHash: String,
	) async throws(APIError) -> APIResponse<LoginDetails> {
		let response = try await execute(
			endpoint: "createuser",
			parameters: [
				"firstname": firstName,
				"lastname": lastName,
				"gender": gender.wireValue,
				"email": email,
				"screenname": screenName,
				"password": passwordHash,
			],
			signed: false,
			credential: nil,
			decodingPayloadAs: CreateUserWirePayload.self,
		)
		return APIResponse(
			payload: LoginDetails(
				personId: response.payload.personId,
				screenName: screenName,
				created: true,
				forcedVenueId: nil,
				issuedCredential: nil,
			),
			rotatedToken: response.rotatedToken,
		)
	}

	/// `applesignin` — ported from `secretdjv3/LoginAPIAccess.swift`'s
	/// `login(appleUserId:firstName:lastName:email:completion:)`. `auth` is
	/// the pre-computed day-of-year digest
	/// (``AppleSignInAuthDigest/compute(appleUserId:date:calendar:)``);
	/// `firstName`/`lastName`/`email` are only ever supplied together, on
	/// Apple's first authorization for this account (LEGACY.md: "Apple only
	/// supplies them once") — matching the legacy `if let firstName,
	/// let lastName, let email` all-or-nothing guard.
	public func appleSignIn(
		appleUserId: String,
		auth: String,
		firstName: String? = nil,
		lastName: String? = nil,
		email: String? = nil,
	) async throws(APIError) -> APIResponse<LoginDetails> {
		var parameters = ["appuid": appleUserId, "auth": auth]
		if let firstName, let lastName, let email {
			parameters["firstname"] = firstName
			parameters["lastname"] = lastName
			parameters["email"] = email
		}

		let response = try await execute(
			endpoint: "applesignin",
			parameters: parameters,
			signed: false,
			credential: nil,
			decodingPayloadAs: SocialSignInWirePayload.self,
		)
		return APIResponse(
			payload: LoginDetails(
				personId: response.payload.personId,
				screenName: response.payload.screenName,
				created: response.payload.created,
				forcedVenueId: nil,
				issuedCredential: response.payload.issuedCredential,
			),
			rotatedToken: response.rotatedToken,
		)
	}

	/// `facebooksignin` — ported from `secretdjv3/LoginAPIAccess.swift`'s
	/// `login(facebookId:accessToken:firstName:lastName:email:completion:)`.
	/// `auth` is the pre-computed day-of-year digest
	/// (``FacebookSignInAuthDigest/compute(facebookUserId:date:calendar:)``).
	/// Unlike ``appleSignIn(appleUserId:auth:firstName:lastName:email:)``,
	/// Facebook's Graph `me` request runs on every sign-in attempt, not just
	/// the first, so `gender`/`firstName`/`lastName`/`email` are each sent
	/// independently whenever the caller has them, with no all-or-nothing
	/// gating (LEGACY.md's endpoint catalog: "`fbid`, `state` (FB access
	/// token), `gender`,`firstname`,`lastname`,`email`, `auth`").
	public func facebookSignIn(
		facebookUserId: String,
		accessToken: String,
		auth: String,
		gender: Gender? = nil,
		firstName: String? = nil,
		lastName: String? = nil,
		email: String? = nil,
	) async throws(APIError) -> APIResponse<LoginDetails> {
		var parameters = ["fbid": facebookUserId, "state": accessToken, "auth": auth]
		if let gender { parameters["gender"] = gender.wireValue }
		if let firstName { parameters["firstname"] = firstName }
		if let lastName { parameters["lastname"] = lastName }
		if let email { parameters["email"] = email }

		let response = try await execute(
			endpoint: "facebooksignin",
			parameters: parameters,
			signed: false,
			credential: nil,
			decodingPayloadAs: SocialSignInWirePayload.self,
		)
		return APIResponse(
			payload: LoginDetails(
				personId: response.payload.personId,
				screenName: response.payload.screenName,
				created: response.payload.created,
				forcedVenueId: nil,
				issuedCredential: response.payload.issuedCredential,
			),
			rotatedToken: response.rotatedToken,
		)
	}

	/// `resetpassword` by screen name — ported from
	/// `secretdjv3/PasswordAPIAccess.swift`'s
	/// `resetPassword(screenName:completion:)`.
	public func resetPassword(screenName: String) async throws(APIError) -> APIResponse<ResetPasswordPayload> {
		try await execute(
			endpoint: "resetpassword",
			parameters: ["screenname": screenName],
			signed: false,
			credential: nil,
			decodingPayloadAs: ResetPasswordPayload.self,
		)
	}

	/// `resetpassword` by email — ported from
	/// `secretdjv3/PasswordAPIAccess.swift`'s `resetPassword(email:completion:)`.
	public func resetPassword(email: String) async throws(APIError) -> APIResponse<ResetPasswordPayload> {
		try await execute(
			endpoint: "resetpassword",
			parameters: ["email": email],
			signed: false,
			credential: nil,
			decodingPayloadAs: ResetPasswordPayload.self,
		)
	}
}

/// `resetpassword`'s entire response body beyond the envelope: `ReturnCode`
/// / `Message` (LEGACY.md's endpoint catalog: "`ReturnCode` == 0 +
/// `Message`"). `ReturnCode == 0` is success; every other documented code —
/// e.g. -100, "Sorry, you must enter either the username or email
/// associated with your account" — carries the server's message as the
/// user-facing error (`secretdjv3/PasswordAPIAccess.swift`'s
/// `handleResponse`).
public struct ResetPasswordPayload: Sendable, Hashable, Decodable {
	public let returnCode: Int
	public let message: String?

	private enum CodingKeys: String, CodingKey {
		case returnCode = "ReturnCode"
		case message = "Message"
	}
}

/// `signin`'s wire shape: `User`, optional `Venues.Force`
/// (`secretdjv3/LoginAPIAccess.swift`'s `serverLoginDetails`).
struct SignInWirePayload: Hashable, Decodable {
	let personId: String
	let forcedVenueId: String?

	private enum CodingKeys: String, CodingKey {
		case personId = "User"
		case venues = "Venues"
	}

	private enum VenuesKeys: String, CodingKey {
		case force = "Force"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		personId = try container.decode(String.self, forKey: .personId)

		if let venues = try? container.nestedContainer(keyedBy: VenuesKeys.self, forKey: .venues) {
			let force = try venues.decodeIfPresent(String.self, forKey: .force)
			forcedVenueId = (force?.isEmpty ?? true) ? nil : force
		} else {
			forcedVenueId = nil
		}
	}
}

/// `createuser`'s wire shape: just `User`
/// (`secretdjv3/LoginAPIAccess.swift`'s `serverSignUpDetails`).
struct CreateUserWirePayload: Hashable, Decodable {
	let personId: String

	private enum CodingKeys: String, CodingKey {
		case personId = "User"
	}
}

/// The shared wire shape `applesignin` and `facebooksignin` both respond
/// with: `User`, `ScreenName`, `Param` (the server-issued credential),
/// `Created` (`secretdjv3/LoginAPIAccess.swift`'s `appleLoginDetails` /
/// `facebookLoginDetails`). LEGACY.md's endpoint catalog documents
/// `applesignin`'s response as "same as facebook" — pinned here against
/// `FacebookSignIn.json`.
struct SocialSignInWirePayload: Hashable, Decodable {
	let personId: String
	let screenName: String
	let issuedCredential: String
	let created: Bool

	private enum CodingKeys: String, CodingKey {
		case personId = "User"
		case screenName = "ScreenName"
		case issuedCredential = "Param"
		case created = "Created"
	}
}
