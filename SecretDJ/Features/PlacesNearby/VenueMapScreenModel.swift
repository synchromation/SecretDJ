import FeedUI
import MapKit
import SecretDJDomain

/// One venue pin on ``VenueMapScreen`` — LEGACY.md "Gaps and cross-checks"'
/// `VenueAnnotation`, minus the `MKAnnotation` conformance (kept out of the
/// value model so it stays a plain, testable value; the view computes
/// ``coordinate`` for MapKit at render time).
struct VenueMapAnnotation: Hashable, Identifiable {
	var id: String {
		venueId
	}

	let venueId: String
	let title: String
	let latitude: Double
	let longitude: Double
	/// Whether this venue's `properties` bitmask includes
	/// `VenueProperties.hasJukebox` — the legacy `vpHasJukebox` special pin.
	let hasJukebox: Bool

	var coordinate: CLLocationCoordinate2D {
		CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
	}
}

/// Derives ``VenueMapScreen``'s pins from the Places Nearby feed's already-
/// loaded venue items — a pure value, not an ``FeedUI/FeedLoading`` client of
/// its own, unlike legacy's `VenueMapViewController` (which re-fetches
/// `placesnearby` independently). Reusing the tab's own feed avoids a
/// redundant network round-trip for content the user is already looking at.
struct VenueMapScreenModel {
	let annotations: [VenueMapAnnotation]

	init(sections: [FeedDisplayModel.VisibleSection]) {
		annotations = sections
			.flatMap(\.items)
			.compactMap { item -> VenueMapAnnotation? in
				guard case .venue(let venue) = item.item else { return nil }

				return VenueMapAnnotation(
					venueId: venue.venueId,
					title: venue.name,
					latitude: venue.lat,
					longitude: venue.lng,
					hasJukebox: venue.properties.contains(.hasJukebox),
				)
			}
	}

	/// A camera region tight around every annotation ("zoom to fit" —
	/// LEGACY.md "Gaps and cross-checks"). `nil` when there are no venues to
	/// fit; a single venue gets a small fixed span rather than a zero-size
	/// region.
	var fitRegion: MKCoordinateRegion? {
		guard !annotations.isEmpty else { return nil }

		let latitudes = annotations.map(\.latitude)
		let longitudes = annotations.map(\.longitude)
		let minLatitude = latitudes.min() ?? 0
		let maxLatitude = latitudes.max() ?? 0
		let minLongitude = longitudes.min() ?? 0
		let maxLongitude = longitudes.max() ?? 0

		let center = CLLocationCoordinate2D(
			latitude: (minLatitude + maxLatitude) / 2,
			longitude: (minLongitude + maxLongitude) / 2,
		)
		// A little padding around the tightest-fit box so edge pins aren't
		// flush against the screen; floored so a single venue (a zero-size
		// box) still gets a sensible close-up span.
		let span = MKCoordinateSpan(
			latitudeDelta: max((maxLatitude - minLatitude) * 1.3, 0.02),
			longitudeDelta: max((maxLongitude - minLongitude) * 1.3, 0.02),
		)

		return MKCoordinateRegion(center: center, span: span)
	}
}
