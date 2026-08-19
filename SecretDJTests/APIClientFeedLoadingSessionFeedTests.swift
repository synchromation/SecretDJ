import FeedUI
import Foundation
import SecretDJAPI
import SecretDJDomain
import Synchronization
import Testing

@testable import SecretDJ

/// ``APIClientFeedLoading/sessionFeed(sessionStore:locationService:endpoint:)``
/// — the factory every S6 feed screen actually constructs: reads the
/// signed-in user/credential fresh on every fetch (never captured once at
/// screen-construction time), rotates the session's token when the response
/// carries one, and fails gracefully rather than crashing when a pending
/// call outlives a sign-out.
@MainActor
enum APIClientFeedLoadingSessionFeedTests {
	struct `Calling the endpoint` {
		@Test func `passes the signed-in user's personId and credential`() async throws {
			let sessionStore = makeSignedInSessionStore(personId: "p1", token: "t1", passwordHash: "h1")
			let locationService = makeLocationService()
			let recorder = EndpointRecorder()
			let loader = APIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
				locationService: locationService,
				endpoint: { userId, credential, page in
					recorder.record(userId: userId, credential: credential, page: page)
					return APIResponse(payload: makeSectionList(), rotatedToken: nil)
				},
			)

			_ = try await loader.load(page: nil)

			#expect(recorder.calls.count == 1)
			#expect(recorder.calls[0].userId == "p1")
			#expect(recorder.calls[0].credential == APICredential(token: "t1", passwordHash: "h1"))
		}

		@Test func `forwards the requested page`() async throws {
			let sessionStore = makeSignedInSessionStore()
			let locationService = makeLocationService()
			let recorder = EndpointRecorder()
			let loader = APIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
				locationService: locationService,
				endpoint: { userId, credential, page in
					recorder.record(userId: userId, credential: credential, page: page)
					return APIResponse(payload: makeSectionList(), rotatedToken: nil)
				},
			)

			_ = try await loader.load(page: 3)

			#expect(recorder.calls[0].page == 3)
		}

		@Test func `throws instead of calling the endpoint when no session is signed in`() async throws {
			let sessionStore = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			let locationService = makeLocationService()
			let recorder = EndpointRecorder()
			let loader = APIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
				locationService: locationService,
				endpoint: { userId, credential, page in
					recorder.record(userId: userId, credential: credential, page: page)
					return APIResponse(payload: makeSectionList(), rotatedToken: nil)
				},
			)

			await #expect(throws: NotSignedInFeedLoadingError.self) {
				try await loader.load(page: nil)
			}
			#expect(recorder.calls.isEmpty)
		}
	}

	struct `Token rotation` {
		@Test func `rotates the session's token when the response carries one`() async throws {
			let sessionStore = makeSignedInSessionStore(token: "old")
			let locationService = makeLocationService()
			let loader = APIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
				locationService: locationService,
				endpoint: { _, _, _ in APIResponse(payload: makeSectionList(), rotatedToken: "new") },
			)

			_ = try await loader.load(page: nil)

			#expect(sessionStore.credential?.token == "new")
		}

		@Test func `leaves the token untouched when the response carries none`() async throws {
			let sessionStore = makeSignedInSessionStore(token: "old")
			let locationService = makeLocationService()
			let loader = APIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
				locationService: locationService,
				endpoint: { _, _, _ in APIResponse(payload: makeSectionList(), rotatedToken: nil) },
			)

			_ = try await loader.load(page: nil)

			#expect(sessionStore.credential?.token == "old")
		}
	}

	struct `Requesting a fresh location` {
		@Test func `requests a fix through the location service when authorized`() async throws {
			let sessionStore = makeSignedInSessionStore()
			let provider = InMemoryLocationProviding(authorizationStatus: .authorized)
			let locationService = LocationService(provider: provider, coordinateBox: LocationCoordinateBox())
			let loader = APIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
				locationService: locationService,
				endpoint: { _, _, _ in APIResponse(payload: makeSectionList(), rotatedToken: nil) },
			)

			_ = try await loader.load(page: nil)

			#expect(provider.requestLocationCallCount == 1)
		}
	}
}

// MARK: - Fixtures

@MainActor
private func makeSignedInSessionStore(
	personId: String = "p1",
	token: String = "t1",
	passwordHash: String = "h1",
) -> SessionStore {
	let sessionStore = SessionStore(
		snapshotStore: InMemorySessionSnapshotStore(),
		credentialStore: InMemoryCredentialStore(),
	)
	sessionStore.signIn(
		user: SessionUser(personId: personId, screenName: "dj"),
		venue: nil,
		credential: APICredential(token: token, passwordHash: passwordHash),
	)
	return sessionStore
}

@MainActor
private func makeLocationService() -> LocationService {
	LocationService(
		provider: InMemoryLocationProviding(authorizationStatus: .authorized),
		coordinateBox: LocationCoordinateBox(),
	)
}

private final nonisolated class EndpointRecorder: Sendable {
	struct Call: Equatable {
		let userId: String
		let credential: APICredential
		let page: Int?
	}

	private let storage = Mutex<[Call]>([])

	func record(userId: String, credential: APICredential, page: Int?) {
		storage.withLock { $0.append(Call(userId: userId, credential: credential, page: page)) }
	}

	var calls: [Call] {
		storage.withLock { $0 }
	}
}
