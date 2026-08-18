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

/// One item's cell-rendering data, derived once from its Domain payload —
/// the only place `Item` crosses into DesignSystem's primitive vocabulary
/// (PLAN.md S3.2: DesignSystem depends on nothing, so its cells never see a
/// Domain type). Exhaustive over every ``Item`` case: a new Domain payload
/// fails to compile here until this mapping accounts for it.
enum FeedCellProps: Hashable {
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

	struct MediaProps: Hashable {
		let title: String
		let subtitle: String?
		let placeholderIcon: Theme.Icon
		let artworkURL: URL?
		let accessory: MediaRowCell.Accessory?
	}

	struct PersonProps: Hashable {
		let name: String
		let subtitle: String?
		let avatarURL: URL?
		let accessory: MediaRowCell.Accessory?
	}

	struct VenueProps: Hashable {
		let name: String
		let address: String?
		let artworkURL: URL?
		let hasJukebox: Bool
		let isCheckedIn: Bool
	}

	struct EventProps: Hashable {
		let icon: Theme.Icon
		let lines: [String]
	}

	struct TopUpProps: Hashable {
		let title: String
		let subtitle: String?
		let priceText: String
	}

	struct PromotionProps: Hashable {
		let artworkURL: URL?
		let caption: String?
	}

	struct ControlTileProps: Hashable {
		let title: String
		let color: Theme.RGBAComponents
		let icon: Theme.Icon
	}
}

extension FeedDisplayItem {
	/// This item's cell props. Domain fields carry no artwork URL yet
	/// (no Domain type decodes an image URI at S3.2 — a gap for a later
	/// Domain task, not something this mapping should guess at), so every
	/// `artworkURL`/`avatarURL` below is `nil` today; the cells already
	/// render their icon fallback in that case.
	var cellProps: FeedCellProps {
		switch item {
		case .song(let song):
			.media(FeedCellProps.MediaProps(
				title: text.feedTaggedLines.first ?? song.title,
				subtitle: text.feedTaggedLines.dropFirst().first,
				placeholderIcon: .song,
				artworkURL: nil,
				// Inert on the consumer (LEGACY.md "Audio and playback") —
				// no like affordance to show for the intermission placeholder.
				accessory: song.isIntermission ? nil : likeAccessory(for: song.likeInfo),
			))

		case .venue(let venue):
			venueOrEventProps(for: venue)

		case .person(let person):
			.person(FeedCellProps.PersonProps(
				name: text.feedTaggedLines.first ?? person.screenName,
				subtitle: text.feedTaggedLines.dropFirst().first,
				avatarURL: nil,
				accessory: likeAccessory(for: person.likeInfo),
			))

		case .artist(let artist):
			// Artist.displayText is client-synthesized, not `text` split on
			// newlines (Item+FeedDisplay.swift's own doc: legacy never uses
			// the item's Text for this row).
			.media(FeedCellProps.MediaProps(
				title: artist.displayText,
				subtitle: nil,
				placeholderIcon: .song,
				artworkURL: nil,
				accessory: nil,
			))

		case .jukebox(let jukebox):
			.media(FeedCellProps.MediaProps(
				title: text.feedTaggedLines.first ?? jukebox.text,
				// Prefer the structured `Description` field over a second
				// tagged line — it's a proper wire field, not a text-split
				// guess.
				subtitle: jukebox.subtitle.isEmpty ? nil : jukebox.subtitle,
				placeholderIcon: .jukebox,
				artworkURL: nil,
				accessory: .chevron,
			))

		case .topUp(let topUp):
			.topUp(FeedCellProps.TopUpProps(
				title: text.feedTaggedLines.first ?? topUp.name,
				subtitle: text.feedTaggedLines.dropFirst().first,
				priceText: topUp.displayPrice.isEmpty ? topUp.price : topUp.displayPrice,
			))

		case .promotion:
			.promotion(FeedCellProps.PromotionProps(artworkURL: nil, caption: text.isEmpty ? nil : text))

		case .control(let control):
			.controlTile(FeedCellProps.ControlTileProps(
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

	/// `.checkIn`/`.award` collapse onto the ``SecretDJDomain/Venue`` payload
	/// (LEGACY.md: "venue-shaped items with a badge image"), but they render
	/// as an activity-feed event (its full tagged-line text, an icon, no
	/// venue badges) rather than a browsable venue row — the template is the
	/// only signal that tells them apart, which is why ``FeedDisplayItem``
	/// carries it. `horizontalAward`/`matrixAward*` stay venue-shaped: they
	/// render in a carousel/grid, where the row-only event layout doesn't fit.
	private func venueOrEventProps(for venue: Venue) -> FeedCellProps {
		switch template {
		case .checkIn:
			.event(FeedCellProps.EventProps(icon: .checkIn, lines: text.feedTaggedLines))

		case .award:
			.event(FeedCellProps.EventProps(icon: .award, lines: text.feedTaggedLines))

		default:
			.venue(FeedCellProps.VenueProps(
				name: text.feedTaggedLines.first ?? venue.name,
				address: text.feedTaggedLines.dropFirst().first,
				artworkURL: nil,
				hasJukebox: venue.properties.contains(.hasJukebox),
				isCheckedIn: venue.checkedIn,
			))
		}
	}

	private func likeAccessory(for likeInfo: LikeInfo) -> MediaRowCell.Accessory {
		.like(isLiked: likeInfo.likedByYou, summary: likeInfo.info.isEmpty ? nil : likeInfo.info)
	}
}
