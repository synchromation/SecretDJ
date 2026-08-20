import FeedUI
import SecretDJAPI
import SecretDJDomain

/// The kiosk's own ``FeedUI/FeedLoading`` adapter over ``SecretDJAPI/APIClient``
/// — every S7.4+ kiosk feed screen constructs one, closing over whichever
/// endpoint call that screen needs, the same shape as the consumer app's own
/// `APIClientFeedLoading` (`SecretDJ/Support/Feed/APIClientFeedLoading.swift`).
///
/// Deliberately **not** shared/extracted between the two apps, and built
/// fresh here rather than reused: the consumer's version also requests a
/// fresh GPS fix ahead of every load (LEGACY.md's "every feed fetch first
/// requests a fresh location" rule, `LocationService`'s doc comment on bug
/// #181's workaround) — a consumer-only refresh rule for a phone that moves.
/// The kiosk is a fixed venue iPad with no location feature at all
/// (``KioskDeviceImplicitParameterProvider``'s own doc comment defers one to
/// a later task), so extracting the consumer's version to a shared package
/// would either drag `LocationService` (app-local by its own doc comment)
/// into a shared target, or bolt an unused optional-location parameter onto
/// every caller for a rule that only ever applies to one app. A small
/// kiosk-local type, minus that one rule, is the more honest fit
/// (ios-architecture: no dependency a type doesn't need).
struct KioskAPIClientFeedLoading: FeedLoading {
	typealias Fetch = @Sendable (_ page: Int?) async throws -> APIResponse<SectionList>

	private let fetch: Fetch

	init(fetch: @escaping Fetch) {
		self.fetch = fetch
	}

	func load(page: Int?) async throws -> SectionList {
		try await fetch(page).payload
	}
}

/// Thrown by ``KioskAPIClientFeedLoading/sessionFeed(sessionStore:endpoint:)``'s
/// `fetch` when no session is signed in at the moment a load fires — mirrors
/// the consumer's own `NotSignedInFeedLoadingError` doc comment: a kiosk feed
/// screen only ever exists while a venue session is signed in, so this
/// defends against a pending auto-refresh tick outliving a sign-out/staff
/// reset rather than a state the UI needs to render.
struct KioskNotSignedInFeedLoadingError: Error, Equatable {}

extension KioskAPIClientFeedLoading {
	/// The factory every kiosk feed screen actually calls: reads the current
	/// ``SecretDJAPI/SessionUser``/``SecretDJAPI/APICredential`` fresh on
	/// every fetch — never captured once at screen-construction time, since
	/// the kiosk home stays on screen (and its header keeps polling) for as
	/// long as the venue stays signed in, far longer than one token's
	/// lifetime — and rotates the session's token when the response carries
	/// one (mirrors the consumer's own `sessionFeed` factory).
	static func sessionFeed(
		sessionStore: SessionStore,
		endpoint: @escaping @Sendable (_ userId: String, _ credential: APICredential, _ page: Int?) async throws
			-> APIResponse<SectionList>,
	) -> KioskAPIClientFeedLoading {
		KioskAPIClientFeedLoading(fetch: { page in
			let session = await MainActor.run { (sessionStore.user?.personId, sessionStore.credential) }
			guard let userId = session.0, let credential = session.1 else {
				throw KioskNotSignedInFeedLoadingError()
			}

			let response = try await endpoint(userId, credential, page)

			if let rotatedToken = response.rotatedToken {
				await MainActor.run { sessionStore.rotateToken(rotatedToken) }
			}

			return response
		})
	}
}
