import Testing

@testable import SharedFeatures

import DesignSystem
import SecretDJDomain

/// The one place `SecretDJDomain.RichToastData` crosses into DesignSystem's
/// primitive `RichToastContent` vocabulary (S8.6) — mirrors
/// `FeedUI/FeedCellProps`' own boundary (PLAN.md S3.2).
struct RichToastContentMappingTests {
	@Test func `carries Title, Headline, and BodyText straight across`() {
		let data = RichToastData(title: "Reward!", headline: "You earned DJ status", bodyText: "Enjoy.", vip: nil)

		let content = RichToastContent(data)

		#expect(content.title == "Reward!")
		#expect(content.headline == "You earned DJ status")
		#expect(content.bodyText == "Enjoy.")
		#expect(content.vip == nil)
	}

	@Test func `splits the VIP's two-line text into a name and a subtitle`() {
		let data = RichToastData(
			title: "",
			headline: "",
			bodyText: "",
			vip: makePerson(text: "oliverk\nis DJ of Bench"),
		)

		let content = RichToastContent(data)

		#expect(content.vip?.name == "oliverk")
		#expect(content.vip?.subtitle == "is DJ of Bench")
	}

	@Test func `carries the VIP's own person id as the tap action id`() {
		let data = RichToastData(title: "", headline: "", bodyText: "", vip: makePerson(personId: "00000087_feae54c9"))

		let content = RichToastContent(data)

		#expect(content.vip?.tapActionID == "00000087_feae54c9")
	}

	/// `secretdjv3/RichToastView.swift`'s `setupVip(_:)` leaves both VIP
	/// labels entirely unset when `Text` has fewer than two newline-separated
	/// lines. This port instead falls back to the VIP's own `screenName` —
	/// a nameless VIP row has no evidence behind it (no captured fixture
	/// confirms that combination ever happens), so this is a deliberate
	/// improvement over reproducing an accidental blank state.
	@Test func `a single-line VIP text falls back to the screen name, with no subtitle`() {
		let data = RichToastData(
			title: "",
			headline: "",
			bodyText: "",
			vip: makePerson(screenName: "oliverk", text: "oliverk"),
		)

		let content = RichToastContent(data)

		#expect(content.vip?.name == "oliverk")
		#expect(content.vip?.subtitle == nil)
	}

	/// Loaded at legacy's own `.size3x3` bucket
	/// (`RichToastView.swift`'s `setupVip(_:)`: `vipImage.loadIntoImageView(vipImageView, sizeClass: .size3x3, ...)`).
	@Test func `resolves the VIP's avatar at the size3x3 bucket`() {
		let image = ItemImage(itemType: .person, uri: "u-1.jpg", size: 100, resolutions: .large)
		let data = RichToastData(title: "", headline: "", bodyText: "", vip: makePerson(image: image))

		let content = RichToastContent(data)

		#expect(content.vip?.avatarURL == image.url(for: .size3x3))
	}
}

private func makePerson(
	personId: String = "1",
	screenName: String = "A",
	text: String = "A\nB",
	image: ItemImage? = nil,
) -> Person {
	Person(
		personId: personId,
		screenName: screenName,
		gender: .unisex,
		likeInfo: LikeInfo(likedByYou: false, info: ""),
		email: nil,
		firstName: nil,
		lastName: nil,
		text: text,
		sortIndex: 0,
		action: nil,
		actions: [],
		image: image,
	)
}
