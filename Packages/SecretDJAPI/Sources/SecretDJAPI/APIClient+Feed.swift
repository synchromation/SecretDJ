import Foundation
import SecretDJDomain

/// `placesnearby`/`venuedetails`/`eventhistory`/`persondetails`/
/// `playhistory`/`extracontent`/`promote` — the consumer feed endpoints
/// (LEGACY.md "Backend API and Spotify integration" → endpoint catalog),
/// typed over ``APIClient``. Ported from `secretdjv3/FeedAPIAccess.swift`.
/// None of these appear in the legacy sig-exclusion list, so every method
/// here requires an ``APICredential``.
extension APIClient {
	/// `placesnearby` — nearby venues plus the caller's own hidden profile
	/// section (`secretdjv3/FeedAPIAccess.swift`'s `placesNearby`). Legacy
	/// additionally checks device location permission before calling; that
	/// UIKit-adjacent guard stays with the caller (ios-architecture: no
	/// platform concerns inside packages).
	public func placesNearby(
		userId: String,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<SectionList> {
		try await executeFeed(
			endpoint: "placesnearby",
			parameters: ["user": userId],
			signed: true,
			credential: credential,
		)
	}

	/// `venuedetails` — a single venue's feed
	/// (`secretdjv3/FeedAPIAccess.swift`'s `venue`).
	public func venue(
		userId: String,
		venueId: String,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<SectionList> {
		try await executeFeed(
			endpoint: "venuedetails",
			parameters: ["user": userId, "venue": venueId],
			signed: true,
			credential: credential,
		)
	}

	/// `eventhistory` — the caller's activity feed
	/// (`secretdjv3/FeedAPIAccess.swift`'s `activity`).
	public func activity(userId: String, credential: APICredential) async throws(APIError) -> APIResponse<SectionList> {
		try await executeFeed(
			endpoint: "eventhistory",
			parameters: ["user": userId],
			signed: true,
			credential: credential,
		)
	}

	/// `persondetails` — another user's profile feed
	/// (`secretdjv3/FeedAPIAccess.swift`'s `profile`).
	public func profile(
		userId: String,
		profileUserId: String,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<SectionList> {
		try await executeFeed(
			endpoint: "persondetails",
			parameters: ["user": userId, "person": profileUserId],
			signed: true,
			credential: credential,
		)
	}

	/// `playhistory` — the venue's now-playing/jukebox-history feed
	/// (`secretdjv3/FeedAPIAccess.swift`'s `nowPlaying`).
	public func nowPlaying(
		userId: String,
		venueId: String,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<SectionList> {
		try await executeFeed(
			endpoint: "playhistory",
			parameters: ["user": userId, "venue": venueId],
			signed: true,
			credential: credential,
		)
	}

	/// `extracontent` — supplementary sections for a specific screen
	/// (`secretdjv3/FeedAPIAccess.swift`'s `extraContent`); `venue` is only
	/// sent when supplied, matching the legacy branch.
	public func extraContent(
		userId: String,
		venueId: String?,
		screen: ExtraContentScreen,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<SectionList> {
		var parameters = ["user": userId, "screenid": String(screen.rawValue)]
		if let venueId {
			parameters["venue"] = venueId
		}
		return try await executeFeed(
			endpoint: "extracontent",
			parameters: parameters,
			signed: true,
			credential: credential,
		)
	}

	/// `promote` — fires the `promotionEngaged` tracking ping for a
	/// URL-less promotion (`secretdjv3/FeedAPIAccess.swift`'s
	/// `promotionEngaged`); the response carries nothing the legacy client
	/// reads ("don't care what the result was").
	public func promotionEngaged(
		userId: String,
		venueId: String,
		promotionId: Int,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<EmptyAPIPayload> {
		try await execute(
			endpoint: "promote",
			parameters: ["user": userId, "venue": venueId, "id": String(promotionId)],
			signed: true,
			credential: credential,
			decodingPayloadAs: EmptyAPIPayload.self,
		)
	}
}

/// `extracontent`'s `screenid` parameter — which screen's supplementary
/// content to fetch (`secretdjv3/FeedAPIAccess.swift`'s
/// `ExtraContentScreen`).
public enum ExtraContentScreen: Int, Sendable {
	case placesNearby = 1
	case venueDetails = 2
}
