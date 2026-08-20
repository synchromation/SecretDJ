import DesignSystem
import SecretDJDomain

extension RichToastContent {
	/// Ports `secretdjv3/RichToastView.swift`'s `populateViews(_:)`/
	/// `setupVip(_:)` field mapping from the domain-layer wire payload
	/// (``SecretDJDomain/RichToastData``) to DesignSystem's own primitive
	/// vocabulary — the one place that domain type crosses into
	/// DesignSystem, mirroring `FeedUI/FeedCellProps`' own boundary
	/// (PLAN.md S3.2). The consuming app (or ``TuneInScreen``) calls this at
	/// the point a rich toast is actually enqueued, never earlier.
	public init(_ data: RichToastData) {
		self.init(
			title: data.title,
			headline: data.headline,
			bodyText: data.bodyText,
			vip: data.vip.map(Vip.init),
		)
	}
}

extension RichToastContent.Vip {
	/// `setupVip(_:)`'s two-line `Text` split — `person.text`'s first line
	/// is the name, its second the subtitle. Unlike legacy (which leaves
	/// both labels unset when fewer than two lines are present), a
	/// single-line (or empty) ``Person/text`` falls back to
	/// ``Person/screenName`` with no subtitle — see
	/// ``RichToastContentMappingTests``' own doc comment on why this is a
	/// deliberate improvement rather than a faithful port of that edge case.
	/// The avatar resolves at legacy's own `.size3x3` bucket
	/// (`RichToastView.swift`'s `setupVip(_:)`:
	/// `loadIntoImageView(vipImageView, sizeClass: .size3x3, ...)`).
	init(_ person: Person) {
		let lines = person.text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
		let name = lines.count >= 2 ? String(lines[0]) : person.screenName
		let subtitle = lines.count >= 2 ? String(lines[1]) : nil

		self.init(
			name: name,
			subtitle: subtitle,
			avatarURL: person.image?.url(for: .size3x3),
			tapActionID: person.personId,
		)
	}
}
