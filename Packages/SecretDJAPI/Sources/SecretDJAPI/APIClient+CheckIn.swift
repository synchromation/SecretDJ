import Foundation
import SecretDJDomain

// D12: watchonyoutube (and its SongSignature helper) is not ported. The
// listen-elsewhere sheet was dropped — the only non-Spotify rows there were
// the Apple Music affiliate link and the YouTube hand-off — so the endpoint
// built in S1.3h is dead without it (PLAN.md's decision log).

/// `checkin` — the venue check-in hand-off (LEGACY.md "Backend API and
/// Spotify integration" → endpoint catalog), typed over ``APIClient``.
/// Ported from `secretdjv3/CheckInAPIAccess.swift`. Not in the legacy
/// sig-exclusion list, so it requires an ``APICredential``.
extension APIClient {
	/// `checkin` — ported from `secretdjv3/CheckInAPIAccess.swift`'s
	/// `checkIn`. `scope` defaults to ``CheckInScope/everyone`` per LEGACY.md
	/// business rule 12 ("Check-ins always sent with `scope=everyone`") —
	/// legacy never sends another value, but the full server-documented enum
	/// is exposed rather than hard-coded, in case a future screen needs it.
	///
	/// The response nests under `Sections[0].Custom.Response` rather than a
	/// top-level `Response` (LEGACY.md's catalog); this doesn't go through
	/// ``APIClient/executeFeed(endpoint:parameters:signed:credential:)``
	/// despite the body technically being `SectionList`-shaped, since only
	/// that one nested object is ever read — the same targeted-extraction
	/// approach S1.3b's `userdetails` uses.
	public func checkIn(
		userId: String,
		venueId: String,
		scope: CheckInScope = .everyone,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<APIActionResponse> {
		let response = try await execute(
			endpoint: "checkin",
			parameters: ["user": userId, "venue": venueId, "scope": String(scope.rawValue)],
			signed: true,
			credential: credential,
			decodingPayloadAs: CheckInWirePayload.self,
		)
		return APIResponse(payload: response.payload.response, rotatedToken: response.rotatedToken)
	}
}

/// `checkin`'s `scope` parameter (`secretdjv3/CheckInAPIAccess.swift`'s
/// `CheckinVisibility`).
public enum CheckInScope: Int, Sendable {
	/// Visible in the rabbit-feed stream only to people the checked-in user
	/// likes.
	case friends = 0
	/// Visible to everyone viewing the rabbit-feed stream — the only value
	/// the legacy client ever sends (business rule 12).
	case everyone = 1
	/// Not shown in the rabbit-feed stream at all.
	case incognito = 2
}

/// `checkin`'s wire shape: `Sections[0].Custom.Response`
/// (`secretdjv3/CheckInAPIAccess.swift`'s `handleCheckInCompleted`).
struct CheckInWirePayload: Hashable, Decodable {
	let response: APIActionResponse

	private enum CodingKeys: String, CodingKey {
		case sections = "Sections"
	}

	private struct SectionWire: Decodable {
		let custom: CustomWire

		private enum CodingKeys: String, CodingKey {
			case custom = "Custom"
		}
	}

	private struct CustomWire: Decodable {
		let response: APIActionResponse

		private enum CodingKeys: String, CodingKey {
			case response = "Response"
		}
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		// Decoded one section at a time, matching `userdetails`'s targeted
		// extraction (S1.3b) rather than the general `SectionList` decoder.
		var sectionsContainer = try container.nestedUnkeyedContainer(forKey: .sections)
		guard !sectionsContainer.isAtEnd, let firstSection = try? sectionsContainer.decode(SectionWire.self) else {
			throw DecodingError.dataCorruptedError(
				forKey: .sections,
				in: container,
				debugDescription: "checkin response has no Custom.Response section",
			)
		}
		response = firstSection.custom.response
	}
}
