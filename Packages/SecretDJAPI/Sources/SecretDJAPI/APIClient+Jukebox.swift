import Foundation
import SecretDJDomain

/// `requestsong`/`like`/`unlike`/`machinecontrol` — the jukebox write
/// endpoints (LEGACY.md "Backend API and Spotify integration" → endpoint
/// catalog), typed over ``APIClient``. Ported from
/// `secretdjv3/SelectSongAPIAccess.swift`, `secretdjv3/LikeAPIAccess.swift`,
/// and `secretdjv3/MachineControlAPIAccess.swift`. None of these appear in
/// the legacy sig-exclusion list, so every method here requires an
/// ``APICredential``.
extension APIClient {
	/// `requestsong` — ported from `secretdjv3/SelectSongAPIAccess.swift`'s
	/// `selectSong`. Classifies the response's `ReturnCode`/`ImageSize` into
	/// a typed ``SongRequestResult`` (LEGACY.md business rule 5) rather than
	/// throwing on a non-zero code — `-8` (out of credits) and any other
	/// failure code are both ordinary outcomes of this call, not transport
	/// errors.
	///
	/// This gates on the envelope's `Success` exactly like every other
	/// endpoint in this package (contrast the note on `RequestSongFail.json`
	/// in this package's tests: that one legacy fixture marks `Success:
	/// false` for a `-8` response, unlike every sibling
	/// ReturnCode-carrying failure fixture, and is treated as a
	/// fixture-authoring mistake rather than a real contract to special-case).
	public func requestSong(
		userId: String,
		venueId: String,
		songId: String,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<SongRequestResult> {
		let response = try await execute(
			endpoint: "requestsong",
			parameters: ["user": userId, "venue": venueId, "songid": songId],
			signed: true,
			credential: credential,
			decodingPayloadAs: RequestSongWirePayload.self,
		)
		return APIResponse(
			payload: SongRequestResult(
				returnCode: response.payload.response.returnCode,
				message: response.payload.response.text,
				url: response.payload.response.url,
				imageSize: response.payload.response.imageSize,
			),
			rotatedToken: response.rotatedToken,
		)
	}

	/// `like` — ported from `secretdjv3/LikeAPIAccess.swift`'s
	/// `updateLikeStatus(..., like: true, ...)`. `venue` is only sent when
	/// supplied, matching the legacy branch.
	public func like(
		userId: String,
		venueId: String?,
		item: String,
		type: ItemType,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<LikeResult> {
		try await likeOrUnlike(
			endpoint: "like",
			userId: userId,
			venueId: venueId,
			item: item,
			type: type,
			credential: credential,
		)
	}

	/// `unlike` — the same wire contract as ``like(userId:venueId:item:type:credential:)``,
	/// posted to the sibling endpoint (`secretdjv3/LikeAPIAccess.swift`'s
	/// `updateLikeStatus(..., like: false, ...)`).
	public func unlike(
		userId: String,
		venueId: String?,
		item: String,
		type: ItemType,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<LikeResult> {
		try await likeOrUnlike(
			endpoint: "unlike",
			userId: userId,
			venueId: venueId,
			item: item,
			type: type,
			credential: credential,
		)
	}

	private func likeOrUnlike(
		endpoint: String,
		userId: String,
		venueId: String?,
		item: String,
		type: ItemType,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<LikeResult> {
		var parameters = ["user": userId, "item": item, "type": String(type.rawValue)]
		if let venueId {
			parameters["venue"] = venueId
		}
		let response = try await execute(
			endpoint: endpoint,
			parameters: parameters,
			signed: true,
			credential: credential,
			decodingPayloadAs: LikeResultPayload.self,
		)
		return APIResponse(payload: response.payload.response, rotatedToken: response.rotatedToken)
	}

	/// `machinecontrol` — the server-granted moderation write shared by the
	/// phone's change-mood/skip/blacklist affordances (ported from
	/// `secretdjv3/MachineControlAPIAccess.swift`'s `changeMood`/`skipTrack`/
	/// `blackListTrack`, which all funnel into its private `machineControl`).
	/// - Parameters:
	///   - item: the target of `action` — a `Control`'s action item id for
	///     ``MachineControlAction/changeAtmosphere``, a song id for
	///     ``MachineControlAction/skip``/``MachineControlAction/blacklist``.
	///   - value: minutes to hold the mood for
	///     ``MachineControlAction/changeAtmosphere``; `0` otherwise.
	public func machineControl(
		userId: String,
		venueId: String,
		action: MachineControlAction,
		item: String,
		value: Int,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<APIActionResponse> {
		let response = try await execute(
			endpoint: "machinecontrol",
			parameters: [
				"user": userId,
				"venue": venueId,
				"action": String(action.rawValue),
				"item": item,
				"value": String(value),
			],
			signed: true,
			credential: credential,
			decodingPayloadAs: APIActionPayload.self,
		)
		return APIResponse(payload: response.payload.response, rotatedToken: response.rotatedToken)
	}
}

/// `machinecontrol`'s `action` parameter (`secretdjv3/Action.swift`'s
/// `ActionType`, restricted to the codes this endpoint accepts).
public enum MachineControlAction: Int, Sendable {
	case changeAtmosphere = 400
	case skip = 401
	case blacklist = 402
}

/// `requestsong`'s wire shape: `Response.{ReturnCode,Text,Url,ImageSize}`.
struct RequestSongWirePayload: Hashable, Decodable {
	let response: ResponseWire

	private enum CodingKeys: String, CodingKey {
		case response = "Response"
	}

	/// // LIVE-CAPTURE: neither `RequestSong.json` nor `RequestSongFail.json`
	/// carries `ImageSize` — the out-of-credits branch's field is entirely
	/// unconfirmed by a real capture. A missing value defaults to `1`
	/// (assume a profile picture exists), matching
	/// `secretdjv3/SelectSongAPIAccess.swift`'s
	/// `responseDictionary["ImageSize"] as? Int ?? 1` exactly (D7) rather
	/// than the more "obvious" `0` default.
	struct ResponseWire: Hashable, Decodable {
		let returnCode: Int
		let text: String?
		let url: String?
		let imageSize: Int

		private enum CodingKeys: String, CodingKey {
			case returnCode = "ReturnCode"
			case text = "Text"
			case url = "Url"
			case imageSize = "ImageSize"
		}

		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			returnCode = try container.decodeIfPresent(Int.self, forKey: .returnCode) ?? 0
			text = try container.decodeIfPresent(String.self, forKey: .text)
			url = try container.decodeIfPresent(String.self, forKey: .url)
			imageSize = try container.decodeIfPresent(Int.self, forKey: .imageSize) ?? 1
		}
	}
}

/// `like`/`unlike`'s wire shape: a top-level `Response` wrapping
/// ``SecretDJDomain/LikeResult``'s fields directly.
struct LikeResultPayload: Hashable, Decodable {
	let response: LikeResult

	private enum CodingKeys: String, CodingKey {
		case response = "Response"
	}
}
