import Foundation
import SecretDJDomain

/// `watchonyoutube`/`checkin` — the listen-elsewhere and venue check-in
/// hand-offs (LEGACY.md "Backend API and Spotify integration" → endpoint
/// catalog), typed over ``APIClient``. Ported from
/// `secretdjv3/YouTubeApiAccess.swift` and `secretdjv3/CheckInAPIAccess.swift`.
/// Neither appears in the legacy sig-exclusion list, so both require an
/// ``APICredential``.
extension APIClient {
	/// `watchonyoutube` — ported from `secretdjv3/YouTubeApiAccess.swift`'s
	/// `watchOnYouTube`. `item` is the signed song id
	/// (``SongSignature/signedSongId(songId:date:calendar:)``); `venue` is
	/// only sent when supplied. `date`/`calendar` default to the current
	/// instant/calendar but are overridable for deterministic testing.
	///
	/// // LIVE-CAPTURE: no legacy fixture exists for `watchonyoutube` at all;
	/// this call's decode is ported directly from
	/// `secretdjv3/YouTubeApiAccess.swift`'s `parseResult`, not pinned
	/// against a real capture.
	public func watchOnYouTube(
		userId: String,
		venueId: String?,
		songId: String,
		date: Date = Date(),
		calendar: Calendar = .current,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<WatchOnYouTubeResult> {
		var parameters = [
			"user": userId,
			"item": SongSignature.signedSongId(songId: songId, date: date, calendar: calendar),
		]
		if let venueId {
			parameters["venue"] = venueId
		}
		let response = try await execute(
			endpoint: "watchonyoutube",
			parameters: parameters,
			signed: true,
			credential: credential,
			decodingPayloadAs: WatchOnYouTubeWirePayload.self,
		)
		return APIResponse(payload: response.payload.result, rotatedToken: response.rotatedToken)
	}

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

/// The outcome of a `watchonyoutube` call
/// (`secretdjv3/YouTubeApiAccess.swift`'s `WatchOnYouTubeResult`): either
/// the server resolved a direct video id, or it didn't and hands back the
/// title/artist text to build a YouTube search query from instead.
public enum WatchOnYouTubeResult: Sendable, Hashable {
	case video(youTubeId: String)
	case searchQuery(String)
}

/// `watchonyoutube`'s wire shape, decoded exactly like
/// `secretdjv3/YouTubeApiAccess.swift`'s `parseResult`: a present
/// `YouTubeId` wins outright; otherwise the search query is built by
/// space-joining `Title`, `ExtraInfo.Raw.Title`, `Artist`,
/// `ExtraInfo.Raw.Artist`, skipping any that are empty/absent.
struct WatchOnYouTubeWirePayload: Hashable, Decodable {
	let result: WatchOnYouTubeResult

	private enum CodingKeys: String, CodingKey {
		case response = "Response"
	}

	private struct ResponseWire: Decodable {
		let youTubeId: String?
		let title: String?
		let artist: String?
		let extraInfo: ExtraInfoWire?

		private enum CodingKeys: String, CodingKey {
			case youTubeId = "YouTubeId"
			case title = "Title"
			case artist = "Artist"
			case extraInfo = "ExtraInfo"
		}
	}

	private struct ExtraInfoWire: Decodable {
		let raw: RawWire?

		private enum CodingKeys: String, CodingKey {
			case raw = "Raw"
		}
	}

	private struct RawWire: Decodable {
		let title: String?
		let artist: String?

		private enum CodingKeys: String, CodingKey {
			case title = "Title"
			case artist = "Artist"
		}
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let response = try container.decode(ResponseWire.self, forKey: .response)

		if let youTubeId = response.youTubeId {
			result = .video(youTubeId: youTubeId)
			return
		}

		var query = response.title ?? ""
		if let rawTitle = response.extraInfo?.raw?.title, !rawTitle.isEmpty {
			query += " \(rawTitle)"
		}
		query += " \(response.artist ?? "")"
		if let rawArtist = response.extraInfo?.raw?.artist, !rawArtist.isEmpty {
			query += " \(rawArtist)"
		}
		result = .searchQuery(query)
	}
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
