import SwiftUI

extension Theme {
	/// The product's semantic icon vocabulary — every icon role a consumer
	/// reaches for, each backed by a deliberately chosen SF Symbol name.
	///
	/// Policy: SF Symbols first. A legacy Paintcode/Photoshop asset is re-cut
	/// into this package's asset catalog only when no symbol can serve a
	/// role, and that decision is made at the consuming task (S3.2/S6/S7),
	/// not speculatively — no legacy image assets are imported here.
	public enum Icon: CaseIterable, Hashable, Sendable {
		/// The music/venue/artist search entry point (nav-bar search action,
		/// music search screen).
		case search
		/// The insert-coin nav-bar action and the out-of-credits top-up funnel.
		case topUp
		/// The hail-taxi nav-bar action and Uber deep link.
		case taxi
		/// Venue directions, and the Places Nearby tab's map bar button.
		case map
		/// Checking in at a venue.
		case checkIn
		/// A person, venue, or song not yet liked ("buzzed").
		case like
		/// A person, venue, or song already liked ("buzzed") — the toggled
		/// state of ``like``.
		case likeFilled
		/// A song, artist, or jukebox row's fallback when it has no artwork.
		case song
		/// A promotion card's fallback when it has no artwork.
		case promotion
		/// A mood/atmosphere tile.
		case mood
		/// Starting a song preview.
		case playPreview
		/// Ending an in-progress song preview.
		case stopPreview
		/// The signed-in user's profile, and person cells.
		case profile
		/// The own-profile avatar-change affordance (S6.6).
		case changePhoto
		/// A venue/place, and the Places Nearby tab.
		case venue
		/// The activity feed ("rabbit feed" — LEGACY.md "Tab 2 — Activity
		/// feed") and the Activity tab.
		case activity
		/// A jukebox, and jukebox menu/cells.
		case jukebox
		/// The venue screen's entry point into its now-playing feed.
		case nowPlaying
		/// An award cell.
		case award
		/// The settings entry point.
		case settings
		/// A disclosure/navigation affordance on a row.
		case disclosure
		/// Dismissing a sheet, dialog, or toast.
		case close
		/// A manual refresh control.
		case refresh
		/// A warning or error state.
		case warning
		/// A generic empty-state placeholder.
		case emptyState
		/// The kiosk's idle/attract-mode screensaver entry.
		case kioskAttract
		/// The kiosk's idle-timeout reset back to its home screen.
		case kioskReset
	}
}

extension Theme.Icon {
	/// This role's SF Symbol name.
	public var systemName: String {
		switch self {
		case .search: "magnifyingglass"
		case .topUp: "creditcard.fill"
		case .taxi: "car.fill"
		case .map: "map.fill"
		case .checkIn: "checkmark.circle.fill"
		case .like: "heart"
		case .likeFilled: "heart.fill"
		case .song: "music.note"
		case .promotion: "megaphone.fill"
		case .mood: "flame.fill"
		case .playPreview: "play.fill"
		case .stopPreview: "stop.fill"
		case .profile: "person.crop.circle.fill"
		case .changePhoto: "camera.circle.fill"
		case .venue: "mappin.circle.fill"
		case .activity: "waveform.path.ecg"
		case .jukebox: "music.note.list"
		case .nowPlaying: "antenna.radiowaves.left.and.right"
		case .award: "trophy.fill"
		case .settings: "gearshape.fill"
		case .disclosure: "chevron.right"
		case .close: "xmark"
		case .refresh: "arrow.clockwise"
		case .warning: "exclamationmark.triangle.fill"
		case .emptyState: "tray"
		case .kioskAttract: "sparkles"
		case .kioskReset: "arrow.counterclockwise"
		}
	}

	/// The SwiftUI image for this role. Labelling and decoration follow the
	/// accessibility skill at the call site — this accessor carries no label
	/// of its own.
	public var image: Image {
		Image(systemName: systemName)
	}
}
