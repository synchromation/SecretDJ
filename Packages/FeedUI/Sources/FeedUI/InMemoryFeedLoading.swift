import SecretDJDomain

/// Fetches whatever ``Outcome`` a test or preview configured for the
/// requested page instead of making a real call.
///
/// An actor rather than a lock-guarded class: ``FeedScreenModel`` always
/// calls ``load(page:)`` with `await`, so actor isolation is free
/// concurrency safety with none of the `@unchecked Sendable` shortcuts
/// ios-architecture rules out for production code.
public actor InMemoryFeedLoading: FeedLoading {
	/// What ``load(page:)`` does for a configured page — succeed with a
	/// fetched feed, or fail as if the transport or server had.
	public enum Outcome: Sendable {
		case success(SectionList)
		case failure(any Error & Sendable)
	}

	/// Every page this fake was asked to load, in call order — `nil` for a
	/// fresh load, otherwise the requested page index — so a test can assert
	/// which pages ``FeedScreenModel`` requested and how many times.
	public private(set) var requestedPages: [Int?] = []

	private var outcomesByPage: [Int: Outcome] = [:]

	public init() {}

	/// Configures what ``load(page:)`` returns for `page`. Call again for
	/// the same page to replace its outcome (e.g. a refresh returning
	/// different content than the initial load).
	public func setOutcome(_ outcome: Outcome, forPage page: Int?) {
		outcomesByPage[page ?? 0] = outcome
	}

	public func load(page: Int?) async throws -> SectionList {
		requestedPages.append(page)

		switch outcomesByPage[page ?? 0] {
		case .success(let sectionList):
			return sectionList

		case .failure(let error):
			throw error

		case nil:
			throw UnconfiguredPageError(page: page)
		}
	}
}

/// Thrown when ``InMemoryFeedLoading/load(page:)`` is called for a page no
/// test configured an ``InMemoryFeedLoading/Outcome`` for.
public struct UnconfiguredPageError: Error, Sendable, Equatable {
	public let page: Int?
}
