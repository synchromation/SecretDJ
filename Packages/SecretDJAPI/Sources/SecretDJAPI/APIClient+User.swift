import Foundation
import SecretDJDomain

/// `userdetails`/`setuserdetails`/`newavatar`/`requestdeleteaccount` — the
/// endpoints that manage the signed-in user's own profile (LEGACY.md
/// "Backend API and Spotify integration" → endpoint catalog), typed over
/// ``APIClient``. None of these appear in the legacy sig-exclusion list, so
/// every method here requires a ``APICredential``.
extension APIClient {
	/// `userdetails` — ported from
	/// `secretdjv3/UserDetailsAPIAccess.swift`'s `fetchUserDetails`.
	public func userDetails(userId: String, credential: APICredential) async throws(APIError) -> APIResponse<Person> {
		let response = try await execute(
			endpoint: "userdetails",
			parameters: ["user": userId],
			signed: true,
			credential: credential,
			decodingPayloadAs: UserDetailsPayload.self,
		)
		return APIResponse(payload: response.payload.person, rotatedToken: response.rotatedToken)
	}

	/// `setuserdetails` — one endpoint the legacy client calls with several
	/// different parameter subsets
	/// (`secretdjv3/UserDetailsAPIAccess.swift`'s
	/// `changeUserDetails`/`changeGender`/`changePassword`/`changeUserName`,
	/// all four hitting this one endpoint per LEGACY.md's catalog: "`user` +
	/// any of `firstname`,`lastname`,`screenname`,`email`,`gender`,`password`").
	/// Every parameter here is optional and only the ones supplied are sent,
	/// so one call models every permutation the legacy client sends.
	/// `passwordHash` is a SHA-1 hex digest, never plaintext.
	public func setUserDetails(
		userId: String,
		firstName: String? = nil,
		lastName: String? = nil,
		screenName: String? = nil,
		email: String? = nil,
		gender: Gender? = nil,
		passwordHash: String? = nil,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<SetUserDetailsPayload> {
		var parameters = ["user": userId]
		if let firstName { parameters["firstname"] = firstName }
		if let lastName { parameters["lastname"] = lastName }
		if let screenName { parameters["screenname"] = screenName }
		if let email { parameters["email"] = email }
		if let gender { parameters["gender"] = gender.wireValue }
		if let passwordHash { parameters["password"] = passwordHash }

		return try await execute(
			endpoint: "setuserdetails",
			parameters: parameters,
			signed: true,
			credential: credential,
			decodingPayloadAs: SetUserDetailsPayload.self,
		)
	}

	/// `newavatar` — a multipart JPEG upload, ported from
	/// `secretdjv3/PostRequestProvider.swift`'s `imageRequestBody`
	/// construction (via `secretdjv3/AvatarAPIAccess.swift` and
	/// `secretdjv3/UploadProfilePicture.swift`). `imageData` is
	/// already-encoded JPEG bytes: encoding (0.9 quality, max 1024² per the
	/// legacy client) is a `UIImage` concern that stays with the caller
	/// (ios-architecture: no UIKit inside packages). The response's
	/// ``AvatarUploadPayload/text`` is the reward-copy toast S6.3's
	/// pic-for-credits flow surfaces verbatim.
	public func uploadAvatar(
		userId: String,
		imageData: Data,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<AvatarUploadPayload> {
		try await execute(
			multipartEndpoint: "newavatar",
			parameters: ["user": userId],
			fileFieldName: "avatarfile",
			filename: "avatar.jpg",
			mimeType: "image/jpeg",
			fileData: imageData,
			credential: credential,
			decodingPayloadAs: AvatarUploadPayload.self,
		)
	}

	/// `requestdeleteaccount` — ported from
	/// `secretdjv3/RequestDeleteAccountAPIAccess.swift`.
	public func requestDeleteAccount(
		userId: String,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<RequestDeleteAccountPayload> {
		try await execute(
			endpoint: "requestdeleteaccount",
			parameters: ["user": userId],
			signed: true,
			credential: credential,
			decodingPayloadAs: RequestDeleteAccountPayload.self,
		)
	}
}

/// `userdetails`'s response body: a `Sections` array whose first entry's
/// first item is the current user as a ``SecretDJDomain/Person``
/// (`secretdjv3/UserDetailsAPIAccess.swift`'s `parsePerson`, via
/// `SectionList.firstHiddenSection(for: .hiddenUserDetails)`). This
/// intentionally does not decode the general `Sections`/`Templates`
/// envelope — S1.3c builds that; this endpoint's response only ever
/// carries the one `Person`.
///
/// A production `userdetails` capture (S1's R2 live-capture pass,
/// `Live/UserDetails.json`) confirms this: `Sections[0].Items[0]` really is
/// the current user as a `Person`, the same layout `persondetails` uses.
/// That capture also confirms ``SecretDJDomain/Person/email``'s doc
/// comment — the live response's email address sits at
/// `Sections[0].Custom.Email`, a sibling of `Items`, not inside the
/// `Person` item's own `Data`; wiring that up is still open (S1.3's note
/// on `Person.email`), tracked separately from this decoder.
struct UserDetailsPayload: Hashable, Decodable {
	let person: Person

	private enum CodingKeys: String, CodingKey {
		case sections = "Sections"
	}

	private struct SectionWire: Decodable {
		let items: [Person]

		private enum CodingKeys: String, CodingKey {
			case items = "Items"
		}
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		// Decoded one section at a time (not `[SectionWire]` in one shot):
		// sibling sections in a real feed carry other item kinds (songs,
		// venues, ...) that don't decode as `Person`, and this endpoint's
		// response only ever needs the first section's first item.
		var sectionsContainer = try container.nestedUnkeyedContainer(forKey: .sections)
		guard !sectionsContainer.isAtEnd, let firstSection = try? sectionsContainer.decode(SectionWire.self),
		      let person = firstSection.items.first else
		{
			throw DecodingError.dataCorruptedError(
				forKey: .sections,
				in: container,
				debugDescription: "userdetails response has no Person item",
			)
		}
		self.person = person
	}
}

/// `setuserdetails`'s response body beyond the envelope: `ReturnCode` /
/// `Message` (LEGACY.md's catalog: "`ReturnCode` == 0"; ported from
/// `secretdjv3/UserDetailsAPIAccess.swift`'s `saveUserDetails`, which treats
/// `ReturnCode == 0` as success and any other value plus `Message` as the
/// user-facing failure text).
public struct SetUserDetailsPayload: Sendable, Hashable, Decodable {
	public let returnCode: Int
	public let message: String?

	private enum CodingKeys: String, CodingKey {
		case returnCode = "ReturnCode"
		case message = "Message"
	}
}

/// `newavatar`'s response body: the reward/confirmation toast text
/// (`secretdjv3/AvatarAPIAccess.swift` only ever reads `Response.Text`).
///
/// // LIVE-CAPTURE: the exact reward copy (and whether `Response` also
/// carries `Url`/`ReturnCode` like the other action endpoints) isn't
/// confirmed — LEGACY.md's catalog documents only "`Response.Text` toast",
/// and the legacy test fixture nominally for this endpoint
/// (`AvatarChange.json`) doesn't actually carry a `Response` object at all
/// (see the decoding-throws test for it), so it isn't trustworthy evidence
/// either.
public struct AvatarUploadPayload: Sendable, Hashable, Decodable {
	public let text: String?

	private enum CodingKeys: String, CodingKey {
		case response = "Response"
	}

	private struct ResponseWire: Decodable {
		let text: String?

		private enum CodingKeys: String, CodingKey {
			case text = "Text"
		}
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let response = try container.decode(ResponseWire.self, forKey: .response)
		text = response.text
	}
}

/// `requestdeleteaccount`'s response body: `Message` at the top level, next
/// to the envelope's own `Success`/`Message`
/// (`secretdjv3/RequestDeleteAccountAPIAccess.swift` reads `Success`/`Message`
/// directly, not a nested `Response` — LEGACY.md's catalog: "`Success` +
/// `Message`").
///
/// // LIVE-CAPTURE: no legacy fixture exists for this endpoint at all; the
/// exact confirmation copy is unconfirmed.
public struct RequestDeleteAccountPayload: Sendable, Hashable, Decodable {
	public let message: String?

	private enum CodingKeys: String, CodingKey {
		case message = "Message"
	}
}
