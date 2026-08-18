import SecretDJDomain

/// The render-ready projection of a Domain ``SectionList`` — lazy-sections'
/// "Section kinds are a closed enum" and "stable server-derived ids" rules
/// applied to the real feed vocabulary (PLAN.md S3.1).
public struct FeedDisplayModel: Sendable {
	/// A titled, kinded group of render-ready items — lazy-sections'
	/// `FeedSection`, minus hidden sections (routed to the typed hidden-data
	/// accessors below instead).
	public struct VisibleSection: Sendable, Hashable, Identifiable {
		/// Stable across refreshes as long as the server keeps sending this
		/// section at the same template and position — derived from the
		/// section's own server fields, never its array position.
		public let id: String
		public let kind: FeedSectionKind
		public let title: String
		public let items: [FeedDisplayItem]
	}

	/// Sections whose template mapped to a renderable ``FeedSectionKind``
	/// (``FeedSectionKind/hidden`` excluded), in server order.
	public let visibleSections: [VisibleSection]
	/// Sections whose template mapped to ``FeedSectionKind/hidden`` — data
	/// channels read through the typed accessors below, never rendered.
	public let hiddenSections: [Section]
	/// Sections whose template this build doesn't recognize, preserved for
	/// logging (see ``DroppedSection``).
	public let droppedSections: [DroppedSection]

	/// Projects a fetched feed into render-ready sections, routing each of
	/// `sectionList`'s sections to ``visibleSections``, ``hiddenSections``,
	/// or ``droppedSections`` by its template's ``FeedSectionKind``. An
	/// item this build can't map to a payload (``Item/unsupported(_:)``,
	/// carrying no ``Item/displayText``) is silently dropped from its
	/// section rather than rendered blank.
	public init(sectionList: SectionList) {
		var visible: [VisibleSection] = []
		var hidden: [Section] = []
		var dropped: [DroppedSection] = []
		// Scoped to this init call: a repeated id only needs breaking within
		// the one section/page list being built here, never across calls
		// (`appendPage` merges by id itself, and a fresh page's own
		// same-slot repeats start their numbering over — see `FeedScreenModel`).
		var sectionIDOccurrences: [String: Int] = [:]

		for section in sectionList.sections {
			guard let kind = FeedSectionKind(template: section.template) else {
				dropped.append(DroppedSection(template: section.template, title: section.title, index: section.index))
				continue
			}

			if kind == .hidden {
				hidden.append(section)
				continue
			}

			var itemIDOccurrences: [String: Int] = [:]
			let items = section.items.compactMap { item -> FeedDisplayItem? in
				guard let text = item.displayText else { return nil }
				return FeedDisplayItem(
					id: Self.deduplicated(item.stableID, occurrences: &itemIDOccurrences),
					item: item,
					text: text,
					template: section.template,
				)
			}

			let baseID = Self.sectionID(template: section.template, index: section.index, hash: section.hash)

			visible.append(
				VisibleSection(
					id: Self.deduplicated(baseID, occurrences: &sectionIDOccurrences),
					kind: kind,
					title: section.title,
					items: items,
				),
			)
		}

		visibleSections = visible
		hiddenSections = hidden
		droppedSections = dropped
	}

	/// A section's server-derived id: its template and index, plus its own
	/// change-detection hash when the server sent one — two sections sharing
	/// a template/index but carrying different hashes (e.g. a page boundary
	/// re-sending the "same" slot with fresh content) already differ before
	/// ``deduplicated(_:occurrences:)`` ever has to break a tie.
	private static func sectionID(template: Template, index: Int, hash: FeedHash?) -> String {
		var id = "\(template.rawValue)-\(index)"
		if let hash {
			id += "-\(hash.rawValue)"
		}
		return id
	}

	/// Breaks a repeated id with a deterministic occurrence suffix
	/// (`"200-0#2"`) — the server can omit or duplicate ``Section/index``
	/// (the decoder defaults a missing `Index` to `0`), and the same song
	/// can appear twice in one section; `ForEach` needs every id distinct
	/// regardless. The first occurrence stays unsuffixed, so an id with no
	/// collision at all matches what a caller (e.g. `appendPage`'s
	/// by-id section lookup) already expects.
	private static func deduplicated(_ id: String, occurrences: inout [String: Int]) -> String {
		let count = (occurrences[id] ?? 0) + 1
		occurrences[id] = count
		return count == 1 ? id : "\(id)#\(count)"
	}
}
