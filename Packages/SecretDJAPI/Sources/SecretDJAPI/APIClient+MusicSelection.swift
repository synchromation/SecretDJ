import Foundation
import SecretDJDomain

/// `musicselection`/`musicdigest`/`styleinfo` — paged music-browse feeds
/// (LEGACY.md "Backend API and Spotify integration" → endpoint catalog),
/// typed over ``APIClient``. Ported from `secretdjv3/MusicAPIAccess.swift`
/// and `secretdjv3/MachineControlAPIAccess.swift`'s `styleInformation`.
/// None of these appear in the legacy sig-exclusion list, so every method
/// here requires an ``APICredential``.
///
/// Legacy reads one specific section's `Custom.Hash` for pagination
/// (`MusicAPIAccess.parseResult`'s *last*-section read,
/// `MachineControlAPIAccess.parseResult`'s *first-`.song`*-section read)
/// rather than a top-level `Hash` — a live `musicdigest` capture (R2)
/// confirms `musicselection` matches that (no top-level `Hash`), though
/// `musicdigest` itself did carry one on the wire, equal to its first
/// section's own `Custom.Hash`; harmless either way, since this package
/// doesn't reproduce legacy's per-endpoint section-picking: every section's
/// own hash already decodes onto ``SecretDJDomain/Section/hash`` (S1.3c's
/// ``SectionListDecoder``), so a caller reads whichever section's hash it
/// needs directly off the returned ``SecretDJDomain/SectionList``, and
/// ``SecretDJDomain/SectionList/hash`` itself just decodes whatever
/// top-level value (or lack of one) the endpoint happens to send.
extension APIClient {
	/// `musicselection` — a venue's paged music-browse catalogue
	/// (`secretdjv3/MusicAPIAccess.swift`'s `musicSelection`).
	public func musicSelection(
		userId: String,
		venueId: String,
		offset: Int,
		batchSize: Int,
		item: Int,
		type: Int64,
		hash: FeedHash?,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<SectionList> {
		try await musicFeed(
			endpoint: "musicselection",
			userId: userId,
			venueId: venueId,
			offset: offset,
			batchSize: batchSize,
			item: item,
			type: type,
			hash: hash,
			credential: credential,
		)
	}

	/// `musicdigest` — same paging contract as `musicselection`, a
	/// different browse grouping (`secretdjv3/MusicAPIAccess.swift`'s
	/// `musicDigest`).
	public func musicDigest(
		userId: String,
		venueId: String,
		offset: Int,
		batchSize: Int,
		item: Int,
		type: Int64,
		hash: FeedHash?,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<SectionList> {
		try await musicFeed(
			endpoint: "musicdigest",
			userId: userId,
			venueId: venueId,
			offset: offset,
			batchSize: batchSize,
			item: item,
			type: type,
			hash: hash,
			credential: credential,
		)
	}

	private func musicFeed(
		endpoint: String,
		userId: String,
		venueId: String,
		offset: Int,
		batchSize: Int,
		item: Int,
		type: Int64,
		hash: FeedHash?,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<SectionList> {
		var parameters = [
			"user": userId,
			"venue": venueId,
			"offset": String(offset),
			"numentries": String(batchSize),
			"item": String(item),
			"type": String(type),
		]
		if let hash {
			parameters["hash"] = hash.rawValue
		}
		return try await executeFeed(endpoint: endpoint, parameters: parameters, signed: true, credential: credential)
	}

	/// `styleinfo` — the jukebox/genre (mood) catalogue
	/// (`secretdjv3/MachineControlAPIAccess.swift`'s `styleInformation`);
	/// unlike `musicselection`/`musicdigest`, this endpoint has no `type`
	/// parameter.
	public func styleInfo(
		userId: String,
		venueId: String,
		offset: Int,
		batchSize: Int,
		item: Int,
		hash: FeedHash?,
		credential: APICredential,
	) async throws(APIError) -> APIResponse<SectionList> {
		var parameters = [
			"user": userId,
			"venue": venueId,
			"offset": String(offset),
			"numentries": String(batchSize),
			"item": String(item),
		]
		if let hash {
			parameters["hash"] = hash.rawValue
		}
		return try await executeFeed(
			endpoint: "styleinfo",
			parameters: parameters,
			signed: true,
			credential: credential,
		)
	}
}
