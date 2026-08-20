import FeedUI
import Foundation
import SecretDJAPI
import SecretDJDomain
import Synchronization
import Testing

@testable import SecretDJKiosk

/// ``KioskAPIClientFeedLoading/sessionFeed(sessionStore:endpoint:)`` — the
/// kiosk-local mirror of the consumer's own
/// `APIClientFeedLoadingSessionFeedTests`, minus its "Requesting a fresh
/// location" struct (``KioskAPIClientFeedLoading``'s own doc comment: the
/// kiosk has no location feature to request a fix through).
@MainActor
enum KioskAPIClientFeedLoadingTests {
	struct `Calling the endpoint` {
		@Test func `passes the signed-in user's personId and credential`() async throws {
			let sessionStore = makeSignedInKioskSessionStore(personId: "p1", token: "t1", passwordHash: "h1")
			let recorder = EndpointRecorder()
			let loader = KioskAPIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
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
			let sessionStore = makeSignedInKioskSessionStore()
			let recorder = EndpointRecorder()
			let loader = KioskAPIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
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
			let recorder = EndpointRecorder()
			let loader = KioskAPIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
				endpoint: { userId, credential, page in
					recorder.record(userId: userId, credential: credential, page: page)
					return APIResponse(payload: makeSectionList(), rotatedToken: nil)
				},
			)

			await #expect(throws: KioskNotSignedInFeedLoadingError.self) {
				try await loader.load(page: nil)
			}
			#expect(recorder.calls.isEmpty)
		}
	}

	struct `Token rotation` {
		@Test func `rotates the session's token when the response carries one`() async throws {
			let sessionStore = makeSignedInKioskSessionStore(token: "old")
			let loader = KioskAPIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
				endpoint: { _, _, _ in APIResponse(payload: makeSectionList(), rotatedToken: "new") },
			)

			_ = try await loader.load(page: nil)

			#expect(sessionStore.credential?.token == "new")
		}

		@Test func `leaves the token untouched when the response carries none`() async throws {
			let sessionStore = makeSignedInKioskSessionStore(token: "old")
			let loader = KioskAPIClientFeedLoading.sessionFeed(
				sessionStore: sessionStore,
				endpoint: { _, _, _ in APIResponse(payload: makeSectionList(), rotatedToken: nil) },
			)

			_ = try await loader.load(page: nil)

			#expect(sessionStore.credential?.token == "old")
		}
	}
}

// MARK: - Fixtures

private nonisolated func makeSectionList() -> SectionList {
	SectionList(hash: FeedHash(rawValue: "h1"), sections: [], actions: [])
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
