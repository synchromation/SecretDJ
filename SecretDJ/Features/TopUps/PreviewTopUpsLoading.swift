import FeedUI
import SecretDJDomain

/// A ``FeedUI/FeedLoading`` that returns a fixed top-up catalog immediately
/// — previews only, never production (previews always inject fakes, per
/// swiftui-views). Mirrors ``PreviewVenueLoading``.
struct PreviewTopUpsLoading: FeedLoading {
	private let sectionList: SectionList

	func load(page _: Int?) async throws -> SectionList {
		sectionList
	}

	static func loaded() -> PreviewTopUpsLoading {
		PreviewTopUpsLoading(sectionList: SectionList(
			hash: FeedHash(rawValue: "preview"),
			sections: [topUpSection()],
			actions: [],
		))
	}

	static func empty() -> PreviewTopUpsLoading {
		PreviewTopUpsLoading(sectionList: SectionList(hash: FeedHash(rawValue: "preview"), sections: [], actions: []))
	}

	private static func topUpSection() -> Section {
		Section(
			itemType: .topUp,
			template: .topUp,
			title: "Grab a Top Up",
			index: 0,
			store: nil,
			hash: nil,
			items: [
				.topUp(TopUp(
					sku: "credits.5",
					vendor: .appleAppStore,
					name: "5 credits",
					productDescription: "",
					price: "£0.99",
					displayPrice: "£0.99",
					currencyCode: "GBP",
					url: nil,
					numCredits: 5,
					text: "5 credits\n£0.99",
					sortIndex: 0,
					action: nil,
					actions: [],
				)),
				.topUp(TopUp(
					sku: "credits.20",
					vendor: .appleAppStore,
					name: "20 credits",
					productDescription: "",
					price: "£1.99",
					displayPrice: "£1.99",
					currencyCode: "GBP",
					url: nil,
					numCredits: 20,
					text: "20 credits\nBest value — £1.99",
					sortIndex: 1,
					action: nil,
					actions: [],
				)),
			],
		)
	}
}
