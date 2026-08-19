import Foundation
import SecretDJAPI
import Synchronization
import Testing

@testable import SecretDJ

/// ``APIClientPromotionEngaging`` — reads the signed-in session fresh on
/// every call, is a silent no-op with no session (never touching the
/// transport), and rotates the session's token when the response carries
/// one.
@MainActor
enum APIClientPromotionEngagingTests {
	struct `Calling the endpoint` {
		@Test func `never touches the transport when no session is signed in`() async {
			let sessionStore = SessionStore(
				snapshotStore: InMemorySessionSnapshotStore(),
				credentialStore: InMemoryCredentialStore(),
			)
			let transport = RecordingAPITransport(response: .success(#"{"Success":true}"#))
			let engaging = APIClientPromotionEngaging(
				client: makeClient(transport: transport),
				sessionStore: sessionStore,
			)

			await engaging.engage(venueId: "v1", promotionId: 42)

			#expect(transport.requestCount == 0)
		}

		@Test func `calls the promote endpoint when signed in`() async {
			let sessionStore = makeSignedInSessionStore()
			let transport = RecordingAPITransport(response: .success(#"{"Success":true}"#))
			let engaging = APIClientPromotionEngaging(
				client: makeClient(transport: transport),
				sessionStore: sessionStore,
			)

			await engaging.engage(venueId: "v1", promotionId: 42)

			#expect(transport.requestCount == 1)
			#expect(transport.lastRequestURL?.absoluteString.contains("promote") == true)
		}

		@Test func `is silent when the call fails`() async {
			let sessionStore = makeSignedInSessionStore()
			let transport = RecordingAPITransport(response: .failure(URLError(.notConnectedToInternet)))
			let engaging = APIClientPromotionEngaging(
				client: makeClient(transport: transport),
				sessionStore: sessionStore,
			)

			await engaging.engage(venueId: "v1", promotionId: 42)

			#expect(transport.requestCount == 1)
		}
	}

	struct `Token rotation` {
		@Test func `rotates the session's token when the response carries one`() async {
			let sessionStore = makeSignedInSessionStore(token: "old")
			let transport = RecordingAPITransport(response: .success(#"{"Success":true,"Token":"new"}"#))
			let engaging = APIClientPromotionEngaging(
				client: makeClient(transport: transport),
				sessionStore: sessionStore,
			)

			await engaging.engage(venueId: "v1", promotionId: 42)

			#expect(sessionStore.credential?.token == "new")
		}

		@Test func `leaves the token untouched when the response carries none`() async {
			let sessionStore = makeSignedInSessionStore(token: "old")
			let transport = RecordingAPITransport(response: .success(#"{"Success":true}"#))
			let engaging = APIClientPromotionEngaging(
				client: makeClient(transport: transport),
				sessionStore: sessionStore,
			)

			await engaging.engage(venueId: "v1", promotionId: 42)

			#expect(sessionStore.credential?.token == "old")
		}
	}
}

// MARK: - Fixtures

private func makeClient(transport: RecordingAPITransport) -> APIClient {
	APIClient(
		configuration: APIClientConfiguration(
			environment: .production,
			deviceIdentifier: "test",
			screenWidth: 390,
			clientVersion: "1.0.0",
			isKiosk: false,
		),
		implicitParameters: NoImplicitParameters(),
		transport: transport,
	)
}

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

private struct NoImplicitParameters: ImplicitParameterProviding {
	let location: APICoordinate? = nil
	let installedApps: InstalledAppsMask = []
	let preferredLanguage = "en"
}

/// A scriptable ``APITransport`` fake that records every request it was
/// asked to send — never touches the network.
private final class RecordingAPITransport: APITransport, @unchecked Sendable {
	enum Response {
		case success(String)
		case failure(any Error)
	}

	private let response: Response
	private let storage = Mutex<(count: Int, lastURL: URL?)>((0, nil))

	init(response: Response) {
		self.response = response
	}

	var requestCount: Int {
		storage.withLock(\.count)
	}

	var lastRequestURL: URL? {
		storage.withLock(\.lastURL)
	}

	func send(_ request: URLRequest) async throws -> Data {
		storage.withLock {
			$0.count += 1
			$0.lastURL = request.url
		}

		switch response {
		case .success(let json):
			return Data(json.utf8)

		case .failure(let error):
			throw error
		}
	}
}
