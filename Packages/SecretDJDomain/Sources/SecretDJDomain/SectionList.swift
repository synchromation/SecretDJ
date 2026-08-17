/// A successfully fetched feed: the server's top-level response wrapper,
/// minus the envelope concerns (`Success`/`Message`/rotating `Token`) that
/// belong to SecretDJAPI rather than this value model (LEGACY.md "Domain
/// model and persistence").
///
/// S1.3: not `Decodable` — see ``Item``'s note on the architecture split.
public struct SectionList: Sendable, Hashable {
	/// This feed's change-detection token — two fetches with an equal hash
	/// have unchanged content.
	public let hash: FeedHash
	public let sections: [Section]
	/// Section-list-wide actions (e.g. nav-bar buttons), independent of any
	/// single section.
	public let actions: [Action]

	public init(hash: FeedHash, sections: [Section], actions: [Action]) {
		self.hash = hash
		self.sections = sections
		self.actions = actions
	}
}
