import DesignSystem
import Foundation
import SecretDJDomain

/// Splits server-rendered text on `"\n"` into the legacy tagged-line
/// convention (LEGACY.md: `FeedCellConfigurator` splits `item.text` into up
/// to four positional labels the server controls), dropping the trailing
/// empty lines the server appends as an alignment trick (a literal
/// `"\n\n\n"`).
extension String {
	var feedTaggedLines: [String] {
		var lines = components(separatedBy: "\n")
		while lines.last?.isEmpty == true {
			lines.removeLast()
		}
		return lines
	}
}

/// One item's cell-rendering data — the only place `Item` crosses into
/// DesignSystem's primitive vocabulary (PLAN.md S3.2: DesignSystem depends
/// on nothing, so its cells never see a Domain type). Derived once, by
/// ``make(item:text:template:)``, when its owning ``FeedDisplayItem`` is
/// built — never per body evaluation (lazy-sections' compute-once rule) —
/// and stored on ``FeedDisplayItem/props``.
public enum FeedCellProps: Hashable, Sendable {
	case media(MediaProps)
	case person(PersonProps)
	case venue(VenueProps)
	case event(EventProps)
	case topUp(TopUpProps)
	case promotion(PromotionProps)
	case controlTile(ControlTileProps)
	/// Nothing to render. Only reachable via ``Item/unsupported(_:)``, which
	/// never actually reaches here — ``FeedDisplayModel`` drops items with no
	/// ``Item/displayText`` before a ``FeedDisplayItem`` exists — but this
	/// case keeps the mapping's switch exhaustive and safe rather than
	/// force-unwrapping an assumption.
	case dropped

	public struct MediaProps: Hashable, Sendable {
		let title: String
		let subtitle: String?
		let placeholderIcon: Theme.Icon
		let artworkURL: URL?
		let accessory: MediaRowCell.Accessory?
	}

	public struct PersonProps: Hashable, Sendable {
		/// Up to four positional tagged lines, carried through unsplit
		/// (never reduced to a name/subtitle pair): legacy's own person
		/// cells (`PersonCollectionViewCell.xib`,
		/// `FeedItemCollectionViewCell.xib`) bind up to four labels by fixed
		/// array index (`FeedCellConfigurator.populateFields`,
		/// `secretdjv3/FeedCellConfigurator.swift:270-275`), and the
		/// previous two-line mapping silently dropped the third ("details")
		/// and fourth ("since"/timestamp) lines a `.feedItem`/`.vip`-
		/// templated person item sends (S9.6). Never empty — falls back to
		/// the person's own `screenName` when the server sent no tagged
		/// text at all. Which lines stack at the top vs. pin to the row's
		/// bottom is ``DesignSystem/PersonRowCell``'s own rendering concern.
		let lines: [String]
		let avatarURL: URL?
		let accessory: MediaRowCell.Accessory?
	}

	public struct VenueProps: Hashable, Sendable {
		let name: String
		let address: String?
		let artworkURL: URL?
		let hasJukebox: Bool
		let isCheckedIn: Bool
	}

	public struct EventProps: Hashable, Sendable {
		let icon: Theme.Icon
		let lines: [String]
	}

	public struct TopUpProps: Hashable, Sendable {
		let title: String
		let subtitle: String?
		let priceText: String
	}

	public struct PromotionProps: Hashable, Sendable {
		let artworkURL: URL?
		let caption: String?
	}

	public struct ControlTileProps: Hashable, Sendable {
		let title: String
		let color: Theme.RGBAComponents
		let icon: Theme.Icon
	}

	/// Maps a Domain payload to its render-ready cell props. `artworkURL`/
	/// `avatarURL` resolve from each payload's decoded
	/// ``SecretDJDomain/ItemImage`` at the row-sized bucket (`size2x2` —
	/// LEGACY.md's per-row thumbnails have no larger/smaller layout variant
	/// today; DesignSystem's row cells render every artwork at a single
	/// fixed size, unlike legacy's device-classed grid/matrix templates),
	/// falling back to `nil` — and the cell's icon fallback — when an item
	/// has no image data or its bucket can't be resolved. Exhaustive over
	/// every ``Item`` case: a new Domain payload fails to compile here until
	/// this mapping accounts for it. Called once, from
	/// ``FeedDisplayItem/init(id:item:text:template:)``.
	static func make(item: Item, text: String, template: Template) -> FeedCellProps {
		switch item {
		case .song(let song):
			songProps(for: song, text: text)

		case .venue(let venue):
			venueOrEventProps(for: venue, text: text, template: template)

		case .person(let person):
			personProps(for: person, text: text)

		case .artist(let artist):
			// Artist.displayText is client-synthesized, not `text` split on
			// newlines (Item+FeedDisplay.swift's own doc: legacy never uses
			// the item's Text for this row). Legacy never resolved a real
			// bucket for artist rows either (`ItemImage.swift`'s
			// `imageBaseURL()` has no `.artist` case), so this reliably
			// stays `nil` today.
			.media(MediaProps(
				title: artist.displayText,
				subtitle: nil,
				placeholderIcon: .song,
				artworkURL: artist.image?.url(for: .size2x2),
				accessory: nil,
			))

		case .jukebox(let jukebox):
			jukeboxProps(for: jukebox, text: text)

		case .topUp(let topUp):
			.topUp(TopUpProps(
				title: text.feedTaggedLines.first ?? topUp.name,
				subtitle: text.feedTaggedLines.dropFirst().first,
				priceText: topUp.displayPrice.isEmpty ? topUp.price : topUp.displayPrice,
			))

		case .promotion(let promotion):
			.promotion(PromotionProps(
				artworkURL: promotion.image?.url(for: .size2x2),
				caption: text.isEmpty ? nil : text,
			))

		case .control(let control):
			.controlTile(ControlTileProps(
				title: text,
				color: Theme.RGBAComponents(hex: control.bgColour) ?? Theme.RGBAComponents(
					red: 0.5,
					green: 0.5,
					blue: 0.5,
				),
				icon: .mood,
			))

		case .unsupported:
			.dropped
		}
	}

	private static func songProps(for song: Song, text: String) -> FeedCellProps {
		.media(MediaProps(
			title: text.feedTaggedLines.first ?? song.title,
			subtitle: text.feedTaggedLines.dropFirst().first,
			placeholderIcon: .song,
			artworkURL: song.image?.url(for: .size2x2),
			// No like affordance on a feed row, intermission or not:
			// `FeedItemCollectionViewCell.xib`/`SongCollectionViewCell.xib`
			// carry no like control, and `FeedCellConfigurator` never wires
			// one into a row — likes live only on the venue header, TuneIn
			// buzz control, and profile header, never a feed row (S9.7,
			// correcting S9.x's invented row accessory).
			accessory: nil,
		))
	}

	private static func personProps(for person: Person, text: String) -> FeedCellProps {
		let lines = text.feedTaggedLines
		return .person(PersonProps(
			// Capped at four: legacy's own `FeedCellConfigurator
			// .populateFields` loop never reads past array index 3 either
			// (`secretdjv3/FeedCellConfigurator.swift:270-275` — tags 101
			// through 104 only), so a fifth tagged line is dropped exactly
			// as it would be by legacy, not silently kept around unused.
			lines: lines.isEmpty ? [person.screenName] : Array(lines.prefix(4)),
			avatarURL: person.image?.url(for: .size2x2),
			// No like affordance: same citation as `songProps`'s own
			// `accessory` comment (S9.7).
			accessory: nil,
		))
	}

	private static func jukeboxProps(for jukebox: Jukebox, text: String) -> FeedCellProps {
		.media(MediaProps(
			title: text.feedTaggedLines.first ?? jukebox.text,
			// Prefer the structured `Description` field over a second tagged
			// line — it's a proper wire field, not a text-split guess.
			subtitle: jukebox.subtitle.isEmpty ? nil : jukebox.subtitle,
			placeholderIcon: .jukebox,
			artworkURL: jukebox.image?.url(for: .size2x2),
			accessory: .chevron,
		))
	}

	/// `.checkIn`/`.award` collapse onto the ``SecretDJDomain/Venue`` payload
	/// (LEGACY.md: "venue-shaped items with a badge image"), but they render
	/// as an activity-feed event (its full tagged-line text, an icon, no
	/// venue badges) rather than a browsable venue row — the template is the
	/// only signal that tells them apart, which is why ``FeedDisplayItem``
	/// carries it. `horizontalAward`/`matrixAward*` stay venue-shaped: they
	/// render in a carousel/grid, where the row-only event layout doesn't fit.
	private static func venueOrEventProps(for venue: Venue, text: String, template: Template) -> FeedCellProps {
		switch template {
		case .checkIn:
			.event(EventProps(icon: .checkIn, lines: text.feedTaggedLines))

		case .award:
			.event(EventProps(icon: .award, lines: text.feedTaggedLines))

		default:
			.venue(VenueProps(
				name: text.feedTaggedLines.first ?? venue.name,
				address: text.feedTaggedLines.dropFirst().first,
				artworkURL: venue.image?.url(for: .size2x2),
				hasJukebox: venue.properties.contains(.hasJukebox),
				isCheckedIn: venue.checkedIn,
			))
		}
	}
}
