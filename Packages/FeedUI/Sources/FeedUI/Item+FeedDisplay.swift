import SecretDJDomain

/// Render-ready projections of a Domain ``Item``, computed once when a
/// ``FeedDisplayModel`` is built rather than inside a view body
/// (lazy-sections' "every displayed value is computed once" rule).
extension Item {
	/// This item's stable, server-derived identity for `ForEach` diffing
	/// (lazy-sections' stable-id rule — never derived from list position).
	///
	/// Every payload type carries a server id except ``Artist`` (identified
	/// by its artist name, unique within one browse index) and ``Control``
	/// (identified by the mood/genre id on its
	/// ``ActionKind/jukeboxChangeAtmosphere`` action when it has one, else
	/// its text) — LEGACY.md notes both as domain gaps inherited from the
	/// legacy payload shape, not something this projection can fix.
	var stableID: String {
		switch self {
		case .song(let song): "song-\(song.songId)"
		case .venue(let venue): "venue-\(venue.venueId)"
		case .person(let person): "person-\(person.personId)"
		case .artist(let artist): "artist-\(artist.artist)"
		case .jukebox(let jukebox): "jukebox-\(jukebox.jukeboxId)"
		case .topUp(let topUp): "topUp-\(topUp.sku)"
		case .promotion(let promotion): "promotion-\(promotion.promotionId)"
		case .control(let control): "control-\(control.action?.itemId.map(String.init) ?? control.text)"
		case .unsupported(let template): "unsupported-\(template.rawValue)"
		}
	}

	/// This item's pre-formatted display text, arriving from the server
	/// already localized (LEGACY.md: "the server formats strings, clients
	/// split on \n"; the localization skill's server-text rule) — `nil`
	/// only for ``unsupported(_:)``, which carries no payload to display.
	var displayText: String? {
		switch self {
		case .song(let song): song.text
		case .venue(let venue): venue.text
		case .person(let person): person.text
		// Client-synthesized, not the server `Text` field — Artist.swift's
		// own doc explains legacy never used the item's Text for this row.
		case .artist(let artist): artist.displayText
		case .jukebox(let jukebox): jukebox.text
		case .topUp(let topUp): topUp.text
		case .promotion(let promotion): promotion.text
		case .control(let control): control.text
		case .unsupported: nil
		}
	}
}
