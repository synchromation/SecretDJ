import DesignSystem
import Foundation
import SecretDJDomain

/// One rotating ticker entry (PLAN.md S6.9), derived once from a fetched
/// ``Item`` — never re-derived per render, mirroring lazy-sections'
/// compute-once rule even though the ticker itself isn't a lazy-sections
/// feed. Mirrors `secretdjv3/ExtraContentManager.swift`'s
/// `ExtraContentViewConfiguration`, built from a song or person's own
/// `text`/`Image` payload. Every other ``Item`` case never reaches the
/// ticker — `init?(item:)` returns `nil` for them, matching legacy's
/// `presentExtraContent(item:)` guard (`if let song = item as? Song ... else
/// if let person = item as? Person ... else { return }`).
struct ExtraContentEntry: Identifiable, Hashable {
	/// Which routing rule ``ExtraContentTapRoute`` applies for this entry —
	/// see its own doc comment.
	enum Kind: Hashable {
		case song
		case person
	}

	let id: String
	let kind: Kind
	let imageURL: URL?
	let placeholderIcon: Theme.Icon
	let artworkShape: RemoteArtworkView.Shape
	/// The small caption line above ``title`` — non-nil only for a song
	/// entry whose ``title``/``subtitle`` came from a three-or-more-line
	/// split (the legacy "Now playing…" literal); every other case leaves
	/// this `nil`, matching legacy's own blank-string branches.
	let caption: String?
	let title: String?
	let subtitle: String?

	/// Direct construction for previews and tests — production only ever
	/// builds an entry through ``init(item:)``, which is the one that
	/// exercises the real tagged-line splitting.
	init(
		id: String,
		kind: Kind,
		imageURL: URL?,
		placeholderIcon: Theme.Icon,
		artworkShape: RemoteArtworkView.Shape,
		caption: String?,
		title: String?,
		subtitle: String?,
	) {
		self.id = id
		self.kind = kind
		self.imageURL = imageURL
		self.placeholderIcon = placeholderIcon
		self.artworkShape = artworkShape
		self.caption = caption
		self.title = title
		self.subtitle = subtitle
	}

	init?(item: Item) {
		switch item {
		case .song(let song):
			id = "song-\(song.songId)"
			kind = .song
			imageURL = song.image?.url(for: .size4x4)
			placeholderIcon = .song
			artworkShape = .rounded
			(caption, title, subtitle) = Self.songLines(from: song.text)

		case .person(let person):
			id = "person-\(person.personId)"
			kind = .person
			imageURL = person.image?.url(for: .size4x4)
			placeholderIcon = .profile
			artworkShape = .circle
			(caption, title, subtitle) = Self.personLines(from: person.text)

		case .venue,
		     .artist,
		     .jukebox,
		     .topUp,
		     .promotion,
		     .control,
		     .unsupported:
			return nil
		}
	}

	/// Legacy's `extraContentViewConfig(song:)`: splits raw `text` on
	/// `"\n"` (no trailing-empty trimming — deliberately not FeedUI's more
	/// tolerant `feedTaggedLines`, which solves a different problem for row
	/// cells) and branches on the surviving component count. Three or more
	/// components add the localized "Now playing…" caption above the
	/// title/subtitle split; fewer components shift straight into
	/// title/subtitle with no caption at all.
	private static func songLines(from text: String) -> (caption: String?, title: String?, subtitle: String?) {
		let components = text.components(separatedBy: "\n")
		switch components.count {
		case 1:
			return (nil, components[0].isEmpty ? nil : components[0], nil)

		case 2:
			return (nil, components[0].isEmpty ? nil : components[0], components[1].isEmpty ? nil : components[1])

		default:
			return (
				nowPlayingCaption,
				components[0].isEmpty ? nil : components[0],
				components[1].isEmpty ? nil : components[1],
			)
		}
	}

	/// Legacy's `extraContentViewConfig(person:)`: only three or more
	/// tagged lines produce any text at all — fewer leaves every line
	/// blank, reproduced verbatim (including the legacy oddity that a
	/// person entry can render with no text, only its avatar).
	private static func personLines(from text: String) -> (caption: String?, title: String?, subtitle: String?) {
		let components = text.components(separatedBy: "\n")
		guard components.count >= 3 else { return (nil, nil, nil) }
		return (
			components[0].isEmpty ? nil : components[0],
			components[1].isEmpty ? nil : components[1],
			components[2].isEmpty ? nil : components[2],
		)
	}

	private static var nowPlayingCaption: String {
		String(
			localized: "Now playing…",
			comment: "Small caption above a song's title/artist in the extra-content ticker shown on Places Nearby and a venue's screen (LEGACY.md's extra-content ticker; the legacy literal \"Now playing...\").",
		)
	}
}
