import FeedUI
import SecretDJAPI
import SecretDJDomain

/// The app-side ``FeedLoading`` adapter over ``APIClient`` — every S6 feed
/// screen constructs one, closing over whichever endpoint call that screen
/// needs via `fetch`. Requests a fresh one-shot location fix ahead of every
/// load, matching legacy's "every feed fetch first requests a fresh
/// location" rule (LEGACY.md "Refresh rules" — `FeedViewController`'s
/// refresh path calls `LocationManager.shared.requestLocation()` on every
/// tick, independent of whether that screen's own feed uses location).
///
/// Both closures are `@Sendable`/`async` — this type is defined in the app
/// target, which builds with default main-actor isolation
/// (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), but ``FeedLoading`` itself
/// is declared in FeedUI (no such default) as a plain nonisolated
/// requirement. A caller closing over a `@MainActor` dependency (a
/// ``SessionStore``, a ``LocationService``) must therefore hop with
/// `await MainActor.run { … }` inside its closure — the same crossing
/// ``LocationCoordinateBox`` solves for reads, done here for a call instead.
/// See ``sessionFeed(sessionStore:locationService:endpoint:)`` for the
/// concrete pattern.
struct APIClientFeedLoading: FeedLoading {
	/// One endpoint call. `page` is `nil` for a full reload (initial
	/// load/pull-to-refresh/auto-refresh tick) and a positive index for
	/// ``FeedScreenModel/loadNextPage()``'s pagination; an endpoint with no
	/// paging concept (`placesnearby`) simply ignores it.
	typealias Fetch = @Sendable (_ page: Int?) async throws -> APIResponse<SectionList>
	typealias RequestLocation = @Sendable () async -> Void

	private let fetch: Fetch
	private let requestLocation: RequestLocation

	init(fetch: @escaping Fetch, requestLocation: @escaping RequestLocation) {
		self.fetch = fetch
		self.requestLocation = requestLocation
	}

	func load(page: Int?) async throws -> SectionList {
		await requestLocation()
		return try await fetch(page).payload
	}
}

/// Thrown by ``APIClientFeedLoading/sessionFeed(sessionStore:locationService:endpoint:)``'s
/// `fetch` when no session is signed in at the moment a load fires — e.g. a
/// pending auto-refresh tick outliving a sign-out. A feed screen only ever
/// exists while signed in, so this is a defensive guard against that race
/// rather than a state the UI needs to render.
struct NotSignedInFeedLoadingError: Error, Equatable {}

extension APIClientFeedLoading {
	/// The factory every session-authenticated S6 feed screen actually
	/// calls: reads the current ``SessionUser``/``APICredential`` fresh on
	/// every fetch — never captured once at screen-construction time, since
	/// a screen's auto-refresh ticks can span far longer than one token's
	/// lifetime — and rotates the session's token when the response carries
	/// one (``APIResponse/rotatedToken``'s doc comment: "rotates on (almost)
	/// every response"; every other authenticated call site in this app
	/// follows the same rotate-after-call contract).
	static func sessionFeed(
		sessionStore: SessionStore,
		locationService: LocationService,
		endpoint: @escaping @Sendable (_ userId: String, _ credential: APICredential, _ page: Int?) async throws
			-> APIResponse<SectionList>,
	) -> APIClientFeedLoading {
		APIClientFeedLoading(
			fetch: { page in
				let session = await MainActor.run { (sessionStore.user?.personId, sessionStore.credential) }
				guard let userId = session.0, let credential = session.1 else {
					throw NotSignedInFeedLoadingError()
				}

				let response = try await endpoint(userId, credential, page)

				if let rotatedToken = response.rotatedToken {
					await MainActor.run { sessionStore.rotateToken(rotatedToken) }
				}

				return response
			},
			requestLocation: {
				await MainActor.run { locationService.requestLocation() }
			},
		)
	}
}
