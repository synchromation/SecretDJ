import Foundation
import SecretDJDomain

/// Decodes a Secret DJ feed response body into
/// ``SecretDJDomain/SectionList`` — the `Templates`-driven dispatch from raw
/// `Items` JSON to a concrete ``SecretDJDomain/Item`` payload that S1.1 left
/// to this package (see `SecretDJDomain.Item`'s `// S1.3:` doc comment).
///
/// Ported from `secretdjv3/SectionList.swift` and `secretdjv3/Section.swift`,
/// with two deliberate departures from the legacy dictionary-walking
/// version:
/// - **Every section survives**, hidden and visible alike, in the order the
///   server sent them. Legacy sorted visible sections and separated a
///   `hiddenSections` array at parse time for its own UIKit data source;
///   this package's `SecretDJDomain/SectionList` is a flat `sections` list
///   by design, and deciding what's renderable is FeedUI's job (S3.1's
///   Domain→`SectionKind` mapping), not this decode step's.
/// - **Unknown templates never drop a section.** Legacy's `SectionList.init`
///   silently discards any section whose template it doesn't recognize
///   (falling back to a synthesized empty section when that empties the
///   whole feed). This decoder instead keeps the section and decodes every
///   one of its items as `Item.unsupported(template)` — the unknown-kind
///   tolerance PLAN.md's S1.1 note describes, with the actual *dropping*
///   deferred to FeedUI's lazy-sections mapping.
///
/// A malformed individual item — one whose `Data` doesn't satisfy its
/// dispatched type's required fields — is dropped without failing the rest
/// of the section, matching legacy's per-item tolerance
/// (`secretdjv3/Section.swift`'s `parseItem` returning `nil`).
public struct SectionListDecoder: Sendable {
	public init() {}

	/// - Throws: whatever `JSONDecoder` throws for JSON that isn't even
	///   syntactically a Secret DJ envelope (e.g. malformed JSON, or a
	///   `Sections`/`Actions` entry of the wrong JSON type). Individual
	///   malformed items and sections degrade instead of throwing — see the
	///   type's doc comment.
	public func decode(_ data: Data) throws -> SecretDJDomain.SectionList {
		let wire = try JSONDecoder().decode(SectionListWire.self, from: data)
		return SecretDJDomain.SectionList(
			hash: FeedHash(rawValue: wire.hash ?? ""),
			sections: wire.sections.map(\.section),
			actions: wire.actions ?? [],
		)
	}
}

/// The top-level feed envelope's variable body: `Hash` (the feed-wide
/// change-detection token, distinct from each section's own `Custom.Hash`),
/// `Sections`, and section-list-wide `Actions`.
private struct SectionListWire: Decodable {
	let hash: String?
	let sections: [SectionWire]
	let actions: [Action]?

	private enum CodingKeys: String, CodingKey {
		case hash = "Hash"
		case sections = "Sections"
		case actions = "Actions"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		hash = try container.decodeIfPresent(String.self, forKey: .hash)
		sections = try container.decodeIfPresent([SectionWire].self, forKey: .sections) ?? []
		actions = try container.decodeIfPresent([Action].self, forKey: .actions)
	}
}

/// One `Sections` entry, decoded straight into the ``SecretDJDomain/Section``
/// it represents — `Section` itself isn't `Decodable` (S1.1's architecture
/// split), so this wire type does the construction instead of conforming it.
private struct SectionWire: Decodable {
	let section: Section

	private enum CodingKeys: String, CodingKey {
		case itemTypeRawValue = "ItemTypeId"
		case templateRawValues = "Templates"
		case title = "Title"
		case index = "Index"
		case custom = "Custom"
		case items = "Items"
	}

	private enum CustomKeys: String, CodingKey {
		case store = "Store"
		case hash = "Hash"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		let itemType = try ItemType(rawValue: container.decodeIfPresent(Int64.self, forKey: .itemTypeRawValue) ?? 0)
		let rawTemplates = try container.decodeIfPresent([Int].self, forKey: .templateRawValues) ?? []
		let template = Self.activeTemplate(for: rawTemplates)
		let title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
		let index = try container.decodeIfPresent(Int.self, forKey: .index) ?? 0

		var store: AffiliateStore?
		var hash: FeedHash?
		if let custom = try? container.nestedContainer(keyedBy: CustomKeys.self, forKey: .custom) {
			store = try custom.decodeIfPresent(AffiliateStore.self, forKey: .store)
			hash = try custom.decodeIfPresent(String.self, forKey: .hash).map(FeedHash.init(rawValue:))
		}

		section = try Section(
			itemType: itemType,
			template: template,
			title: title,
			index: index,
			store: store,
			hash: hash,
			items: Self.items(in: container, template: template),
		)
	}

	/// Picks the section's governing template the way legacy's
	/// `firstValidTemplate` did: the first array entry this build
	/// recognizes, over an earlier code it doesn't — never the reverse, so
	/// a `[203, 200]` array (a real `persondetails` shape — a "Your
	/// Favourite Tunes" section listing both `horizontalSong` and `song`)
	/// resolves to `horizontalSong`, not `song`. A missing or empty
	/// `Templates` array mirrors legacy's `.unknown` sentinel, itself raw
	/// value `0` in the legacy `Template` enum.
	private static func activeTemplate(for rawTemplates: [Int]) -> Template {
		let mapped = rawTemplates.isEmpty ? [Template(rawValue: 0)] : rawTemplates.map(Template.init(rawValue:))
		if let known = mapped.first(where: { if case .unsupported = $0 { return false }
			return true
		}) {
			return known
		}
		// Every candidate was unsupported: keep the first one so its raw
		// code still reaches logging/metrics, rather than losing it.
		return mapped[0]
	}

	/// Decodes `Items` into ``SecretDJDomain/Item`` values per `template`'s
	/// dispatch, dropping (not throwing for) any entry that fails to decode
	/// as its dispatched type — the item-level tolerance this type's doc
	/// comment describes. A missing `Items` key decodes as no items, rather
	/// than legacy's `?? [[:]]` fallback (`secretdjv3/Section.swift:149`),
	/// which parsed one spurious empty-dictionary item — an accident of the
	/// Objective-C-era code, not a contract worth preserving.
	private static func items(in container: KeyedDecodingContainer<CodingKeys>, template: Template) throws -> [Item] {
		guard var itemsContainer = try? container.nestedUnkeyedContainer(forKey: .items) else {
			return []
		}

		var items: [Item] = []
		while !itemsContainer.isAtEnd {
			let itemDecoder = try itemsContainer.superDecoder()
			if let item = decodeItem(from: itemDecoder, template: template) {
				items.append(item)
			}
		}
		return items
	}

	/// Dispatches one raw `Items` entry to its ``SecretDJDomain/Item`` case
	/// by `template`, mirroring `secretdjv3/Section.swift`'s `parseItem`
	/// switch. `nil` means this one item was malformed and should be
	/// dropped; an unrecognized template never reaches decode at all —
	/// every one of its items becomes `.unsupported(template)`.
	private static func decodeItem(from decoder: Decoder, template: Template) -> Item? {
		switch template {
		case .venue,
		     .hiddenVenueDetails,
		     .award,
		     .checkIn,
		     .horizontalAward,
		     .matrixAwardSmall,
		     .matrixAwardMedium:
			(try? Venue(from: decoder)).map(Item.venue)
		case .song,
		     .matrixSongSmall,
		     .matrixSongMedium,
		     .horizontalSong,
		     .hiddenExtraContentSong:
			(try? Song(from: decoder)).map(Item.song)
		case .feedItem,
		     .hiddenUserDetails,
		     .hiddenProfile,
		     .vip,
		     .person,
		     .horizontalVIP,
		     .horizontalPerson,
		     .matrixPersonSmall,
		     .matrixPersonMedium:
			(try? Person(from: decoder)).map(Item.person)
		case .promotion,
		     .advert,
		     .matrixPromotionMedium:
			(try? Promotion(from: decoder)).map(Item.promotion)
		case .jukeboxList,
		     .matrixJukeboxLarge,
		     .hiddenJukeboxList:
			(try? Jukebox(from: decoder)).map(Item.jukebox)
		case .topUp:
			(try? TopUp(from: decoder)).map(Item.topUp)
		case .artist:
			(try? Artist(from: decoder)).map(Item.artist)
		case .matrixControlLarge:
			(try? Control(from: decoder)).map(Item.control)
		case .container,
		     .unsupported:
			.unsupported(template)
		}
	}
}
