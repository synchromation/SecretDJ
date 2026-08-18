import SecretDJDomain

/// The layout a backend-driven feed section renders as (lazy-sections'
/// `SectionKind`), derived from the legacy template set LEGACY.md catalogs
/// under "The feed engine" and "Domain model and persistence".
public enum FeedSectionKind: Sendable, Hashable {
	/// A vertically stacked row per item — the default rendering for a
	/// plain (unprefixed) template.
	case list
	/// A horizontally scrolling row of cards — the legacy `horizontal*`
	/// templates and the nested "container" template (9999) legacy used to
	/// wrap matrix/horizontal sub-collections for the UIKit feed.
	case carousel
	/// A multi-column tile layout — the legacy `matrix*` templates.
	case grid
	/// A data channel that never renders as list/carousel/grid content —
	/// the legacy `hidden*` templates (venue details, the signed-in user's
	/// profile, another user's profile, the jukebox menu, the rotating
	/// "now playing" ticker). ``FeedDisplayModel`` routes sections of this
	/// kind to its typed hidden-data accessors instead of ``visibleSections``.
	case hidden

	/// Maps a section's ``Template`` to the layout it renders as. Returns
	/// `nil` for a template this build doesn't recognize
	/// (``Template/unsupported(_:)``) so the caller can drop that section
	/// instead of guessing a layout (lazy-sections' unknown-kind rule; the
	/// S1.1 boundary note — `unsupported` exists for logging only).
	public init?(template: Template) {
		switch template {
		case .hiddenVenueDetails,
		     .hiddenUserDetails,
		     .hiddenProfile,
		     .hiddenJukeboxList,
		     .hiddenExtraContentSong:
			self = .hidden

		case .horizontalAward,
		     .horizontalSong,
		     .horizontalVIP,
		     .horizontalPerson,
		     .container:
			self = .carousel

		case .matrixAwardSmall,
		     .matrixAwardMedium,
		     .matrixSongSmall,
		     .matrixSongMedium,
		     .matrixPersonSmall,
		     .matrixPersonMedium,
		     .matrixPromotionMedium,
		     .matrixJukeboxLarge,
		     .matrixControlLarge:
			self = .grid

		case .venue,
		     .award,
		     .checkIn,
		     .song,
		     .feedItem,
		     .vip,
		     .person,
		     .promotion,
		     .advert,
		     .jukeboxList,
		     .topUp,
		     .artist:
			self = .list

		case .unsupported:
			return nil
		}
	}
}
