import DesignSystem
import FeedUI
import SharedFeatures
import SwiftUI

/// ``TabsView``'s static String Catalog copy for the destinations it builds
/// — split from `TabsView.swift` itself (an extension, not a second type)
/// purely to keep that file under the file/type-body length lints as more
/// destinations land; every property here is used exclusively by
/// `TabsView`'s own `destination(for:router:)` builder methods.
extension TabsView {
	/// Reused verbatim from ``VenueScreen``/``NowPlayingScreen``'s own
	/// jukebox-changed toast — the same String Catalog key, not a second one
	/// (LEGACY.md's `kJukeboxUpdatedText`).
	static var jukeboxChangedMessage: String {
		String(
			localized: "Jukebox Updated",
			comment: "Toast shown when a paginated feed's content changed underneath the user (LEGACY.md's kJukeboxUpdatedText).",
		)
	}

	/// The accessible name for a rich toast's VIP-row custom action (S8.6,
	/// `secretdjv3/RichToastView.swift`'s `viewVipButtonTapped`) — the one
	/// composition point every rich toast's tap routes through, regardless
	/// of which screen enqueued it (check-in or a song request).
	static var richToastVipActionLabel: Text {
		Text(
			"View Profile",
			comment: "VoiceOver custom action on a rich (award-style) toast's VIP row, opening that person's profile.",
		)
	}

	static var musicSelectionCopy: FeedScreenCopy {
		FeedScreenCopy(
			emptySystemImage: Theme.Icon.jukebox.systemName,
			emptyTitle: Text(
				"Nothing Here Yet",
				comment: "Title shown on a jukebox's song list when it has no content yet.",
			),
			emptyMessage: Text(
				"This jukebox hasn't got anything to show yet — check back soon.",
				comment: "Body shown on a jukebox's song list when it has no content yet.",
			),
			errorTitle: Text(
				"Something Went Wrong",
				comment: "Title shown on a jukebox's song list when it fails to load.",
			),
			errorMessage: Text(
				"Sorry, we couldn't load this jukebox.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
				comment: "Body shown on a jukebox's song list when it fails to load.",
			),
			offlineTitle: Text(
				"You're Offline",
				comment: "Title shown on a jukebox's song list when the device has no internet connection.",
			),
			offlineMessage: Text(
				"Check your connection and try again.",
				comment: "Body shown on a jukebox's song list when the device has no internet connection.",
			),
			retryTitle: Text(
				"Try Again",
				comment: "Button that retries loading a jukebox's song list after a failure.",
			),
		)
	}

	static var musicSearchCopy: MusicSearchScreenCopy {
		MusicSearchScreenCopy(
			navigationTitle: Text("Search", comment: "Navigation title of the artist/song search screen."),
			artistModeLabel: Text("Artists", comment: "Search screen tab that searches by artist name."),
			trackModeLabel: Text("Songs", comment: "Search screen tab that searches by song title."),
			searchFieldPlaceholder: Text(
				"Search",
				comment: "Placeholder text in the search screen's text field, before the user types anything.",
			),
			emptyTitle: Text("No Results", comment: "Title shown on the search screen when a search finds nothing."),
			emptyMessage: Text(
				"Try a different search.",
				comment: "Body shown on the search screen when a search finds nothing.",
			),
			errorTitle: Text("Something Went Wrong", comment: "Title shown on the search screen when a search fails."),
			errorMessage: Text(
				"Sorry, we couldn't search right now.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
				comment: "Body shown on the search screen when a search fails.",
			),
			retryTitle: Text("Try Again", comment: "Button that retries a failed search."),
		)
	}

	static var songsForArtistCopy: FeedScreenCopy {
		FeedScreenCopy(
			emptySystemImage: Theme.Icon.song.systemName,
			emptyTitle: Text(
				"No Songs",
				comment: "Title shown on an artist's song list when they have no songs here yet.",
			),
			emptyMessage: Text(
				"This artist hasn't got anything to show yet — check back soon.",
				comment: "Body shown on an artist's song list when they have no songs here yet.",
			),
			errorTitle: Text(
				"Something Went Wrong",
				comment: "Title shown on an artist's song list when it fails to load.",
			),
			errorMessage: Text(
				"Sorry, we couldn't load these songs.\n\nPlease check that you have a good connection to your cellular data or WiFi network.",
				comment: "Body shown on an artist's song list when it fails to load.",
			),
			offlineTitle: Text(
				"You're Offline",
				comment: "Title shown on an artist's song list when the device has no internet connection.",
			),
			offlineMessage: Text(
				"Check your connection and try again.",
				comment: "Body shown on an artist's song list when the device has no internet connection.",
			),
			retryTitle: Text(
				"Try Again",
				comment: "Button that retries loading an artist's song list after a failure.",
			),
		)
	}
}
