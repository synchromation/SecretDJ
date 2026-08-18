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

		for section in sectionList.sections {
			guard let kind = FeedSectionKind(template: section.template) else {
				dropped.append(DroppedSection(template: section.template, title: section.title, index: section.index))
				continue
			}

			if kind == .hidden {
				hidden.append(section)
				continue
			}

			let items = section.items.compactMap { item in
				item.displayText.map { FeedDisplayItem(id: item.stableID, item: item, text: $0) }
			}

			visible.append(
				VisibleSection(
					id: "\(section.template.rawValue)-\(section.index)",
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
}
