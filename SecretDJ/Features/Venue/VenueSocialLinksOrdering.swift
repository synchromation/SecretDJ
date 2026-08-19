import SecretDJDomain

/// The venue screen's one client-side content rule (LEGACY.md business rule
/// 10, "Venue social links: Instagram-first ordering, max 3"; ported from
/// `secretdjv3/VenueFeedViewController.swift`'s `filterSocials`/
/// `prioritiseSocialItems`): reorders and caps the social-links section
/// (`ItemType.event`, holding `Promotion` items keyed by
/// ``SecretDJDomain/SocialPlatform``'s well-known negative ids) so Instagram
/// leads when present, Twitter and the website follow, and Facebook only
/// fills a spare slot. Applied to the raw feed before ``FeedUI/FeedScreenModel``
/// ever sees it, so the existing generic promotion rendering needs no
/// venue-specific branch.
///
/// Legacy also pads a short result out to the cap with promotions that carry
/// an *empty* url ("if we still don't have our max then get all the empty
/// socials") — LEGACY.md's own preserved-rules list names only the
/// reordering/capping rule, not that padding, and a promotion with no url
/// can't open anything on tap, so this port drops that branch as dead
/// weight rather than carrying it forward.
enum VenueSocialLinksOrdering {
	private static let maxSocials = 3

	/// Applies the rule to every `ItemType.event` section in `sectionList`,
	/// leaving every other section untouched and in its original order.
	static func prioritized(_ sectionList: SectionList) -> SectionList {
		SectionList(
			hash: sectionList.hash,
			sections: sectionList.sections.map(prioritized(section:)),
			actions: sectionList.actions,
		)
	}

	private static func prioritized(section: Section) -> Section {
		guard section.itemType == .event else { return section }

		let promotions = validPromotions(in: section.items)
		// No early return for an empty `promotions`: legacy's own capping
		// step runs unconditionally on the section's items regardless of
		// validity (`prioritiseSocialItems`'s final "ensure is no greater
		// than max length"), and since this port drops invalid promotions
		// outright rather than padding with them, an all-invalid section
		// must end up with zero items — not pass through with every invalid
		// item still attached.
		let ordered = promotions.contains(where: { $0.socialPlatform == .instagram })
			? instagramFirst(promotions)
			: promotions

		return Section(
			itemType: section.itemType,
			template: section.template,
			title: section.title,
			index: section.index,
			store: section.store,
			hash: section.hash,
			items: Array(ordered.prefix(maxSocials)).map(Item.promotion),
		)
	}

	/// Legacy's `haveValidSocialSite`: a social item only counts once its
	/// `promotionURL` is non-empty — an id matching a well-known social
	/// platform with no url is treated as if that platform were absent.
	private static func validPromotions(in items: [Item]) -> [Promotion] {
		items.compactMap {
			guard case .promotion(let promotion) = $0, let url = promotion.url, !url.isEmpty else { return nil }
			return promotion
		}
	}

	/// Legacy's `prioritiseSocialItems`, Instagram-present branch: Instagram
	/// leads, then Twitter and the website if present, then Facebook only
	/// when a slot remains — capping happens in the caller.
	private static func instagramFirst(_ promotions: [Promotion]) -> [Promotion] {
		var ordered: [Promotion] = []

		if let instagram = promotions.first(where: { $0.socialPlatform == .instagram }) {
			ordered.append(instagram)
		}
		if let twitter = promotions.first(where: { $0.socialPlatform == .twitter }) {
			ordered.append(twitter)
		}
		if let website = promotions.first(where: { $0.socialPlatform == .website }) {
			ordered.append(website)
		}
		if ordered.count < maxSocials, let facebook = promotions.first(where: { $0.socialPlatform == .facebook }) {
			ordered.append(facebook)
		}

		return ordered
	}
}
