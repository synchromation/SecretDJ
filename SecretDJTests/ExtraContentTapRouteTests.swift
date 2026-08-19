import DesignSystem
import SecretDJDomain
import Testing

@testable import SecretDJ

/// ``ExtraContentEntry/tapRoute(hostVenueId:)`` — the pure routing rule
/// behind ``ExtraContentModel/tapCurrentEntry()``. Mirrors
/// `secretdjv3/FeedInteractor.swift`'s `userTappedExtraContent(item:feedDataProvider:)`:
/// a song only routes when the *hosting* screen has a venue context (the
/// venue screen), a person always routes to Activity.
enum ExtraContentTapRouteTests {
	struct `A song entry` {
		@Test func `routes to that venue's Now Playing screen when the host has a venue`() {
			let entry = ExtraContentEntry(
				id: "song-1",
				kind: .song,
				imageURL: nil,
				placeholderIcon: .song,
				artworkShape: .rounded,
				caption: nil,
				title: "Title",
				subtitle: nil,
			)

			#expect(entry.tapRoute(hostVenueId: "v1") == .nowPlaying(venueId: "v1"))
		}

		@Test func `has no route when the host has no venue context`() {
			let entry = ExtraContentEntry(
				id: "song-1",
				kind: .song,
				imageURL: nil,
				placeholderIcon: .song,
				artworkShape: .rounded,
				caption: nil,
				title: "Title",
				subtitle: nil,
			)

			#expect(entry.tapRoute(hostVenueId: nil) == nil)
		}
	}

	struct `A person entry` {
		@Test func `always routes to Activity, with or without a host venue`() {
			let entry = ExtraContentEntry(
				id: "person-1",
				kind: .person,
				imageURL: nil,
				placeholderIcon: .profile,
				artworkShape: .circle,
				caption: nil,
				title: "Title",
				subtitle: nil,
			)

			#expect(entry.tapRoute(hostVenueId: "v1") == .activity)
			#expect(entry.tapRoute(hostVenueId: nil) == .activity)
		}
	}
}
