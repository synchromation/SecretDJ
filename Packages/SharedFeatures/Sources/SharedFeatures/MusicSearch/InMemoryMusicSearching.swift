import SecretDJDomain

/// A scriptable ``MusicSearching`` fake for tests and previews — never
/// touches the network. Mirrors the consumer app's `InMemoryLikeToggling`
/// shape.
@MainActor
public final class InMemoryMusicSearching: MusicSearching {
	public struct SearchCall: Equatable, Sendable {
		public let query: String
		public let mode: MusicSearchMode
	}

	public enum Outcome: Sendable {
		case success(SectionList)
		case failure(MusicSearchError)
	}

	/// Every ``search(query:mode:)`` call, in call order — a test's way to
	/// assert what was searched, and how many times (e.g. proving a
	/// debounced query only fires once).
	public private(set) var searchCalls: [SearchCall] = []
	public private(set) var artistsAvailableCallCount = 0
	public private(set) var songsForArtistCalls: [String] = []

	public var artistsAvailableResult: Result<[Artist], MusicSearchError> = .success([])
	public var songsForArtistResult: Result<SectionList, MusicSearchError> = .success(
		SectionList(hash: FeedHash(rawValue: ""), sections: [], actions: []),
	)

	private var searchOutcomes: [SearchCall: Outcome] = [:]
	private var isSearchHanging = false
	private var searchContinuation: CheckedContinuation<Void, Never>?

	public init() {}

	/// Configures what ``search(query:mode:)`` returns for `query`/`mode`.
	public func setOutcome(_ outcome: Outcome, forQuery query: String, mode: MusicSearchMode) {
		searchOutcomes[SearchCall(query: query, mode: mode)] = outcome
	}

	/// Makes the next ``search(query:mode:)`` call suspend until
	/// ``resumeSearch(with:)`` releases it — lets a test observe
	/// ``SearchModel``'s stale-response suppression by changing the query
	/// again while a search is still in flight.
	public func hangSearch() {
		isSearchHanging = true
	}

	/// Releases a hung ``search(query:mode:)`` call, returning `outcome`
	/// directly rather than consulting ``setOutcome(_:forQuery:mode:)``'s
	/// table.
	public func resumeSearch(with outcome: Outcome) {
		hungOutcome = outcome
		isSearchHanging = false
		searchContinuation?.resume()
		searchContinuation = nil
	}

	private var hungOutcome: Outcome?

	public func search(query: String, mode: MusicSearchMode) async throws(MusicSearchError) -> SectionList {
		let call = SearchCall(query: query, mode: mode)
		searchCalls.append(call)

		if isSearchHanging {
			await withCheckedContinuation { searchContinuation = $0 }
			switch hungOutcome {
			case .success(let sectionList): return sectionList
			case .failure(let error): throw error
			case nil: break
			}
		}

		switch searchOutcomes[call] {
		case .success(let sectionList):
			return sectionList
		case .failure(let error):
			throw error
		case nil:
			throw .server(message: "InMemoryMusicSearching: no outcome configured for query '\(query)' in mode \(mode)")
		}
	}

	public func artistsAvailable() async throws(MusicSearchError) -> [Artist] {
		artistsAvailableCallCount += 1

		switch artistsAvailableResult {
		case .success(let artists): return artists
		case .failure(let error): throw error
		}
	}

	public func songs(forArtist artistName: String) async throws(MusicSearchError) -> SectionList {
		songsForArtistCalls.append(artistName)

		switch songsForArtistResult {
		case .success(let sectionList): return sectionList
		case .failure(let error): throw error
		}
	}
}

extension InMemoryMusicSearching.SearchCall: Hashable {}
