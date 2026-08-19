/// Where tapping the ticker's current entry navigates
/// (``ExtraContentModel/tapCurrentEntry()``), resolved by whichever screen
/// hosts the ticker. Mirrors `secretdjv3/FeedInteractor.swift`'s
/// `userTappedExtraContent(item:feedDataProvider:)`.
enum ExtraContentTapRoute: Equatable {
	/// A song entry tapped while the hosting screen has a venue context —
	/// opens *that* venue's Now Playing screen, never a venue the tapped
	/// song's own data might name. Legacy casts its own feed data provider
	/// to `VenueFeedDataProvider` and, once that succeeds, pushes
	/// `NowPlayingViewController` for `venueFeedDataProvider.venue` —
	/// ignoring the tapped item's own venue entirely.
	case nowPlaying(venueId: String)
	/// A person entry, tapped from either screen — legacy's
	/// `viewController.show(tab: .rabbitFeed)`.
	case activity
}

extension ExtraContentEntry {
	/// `nil` when the tap has no destination — a song entry tapped on a
	/// screen with no venue context (Places Nearby, `hostVenueId == nil`),
	/// matching legacy's failed `as? VenueFeedDataProvider` cast there: the
	/// `if let _ = item as? Song, let venueFeedDataProvider = ... as?
	/// VenueFeedDataProvider` condition fails as a whole, and the `else if
	/// let _ = item as? Person` branch never matches a song either, so
	/// nothing happens.
	func tapRoute(hostVenueId: String?) -> ExtraContentTapRoute? {
		switch kind {
		case .song:
			guard let hostVenueId else { return nil }
			return .nowPlaying(venueId: hostVenueId)

		case .person:
			return .activity
		}
	}
}
