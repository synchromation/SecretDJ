import Foundation
import SecretDJAPI
import Testing

@testable import SecretDJKiosk

/// ``APIClientSkinLoading`` — reads the signed-in user/venue/credential
/// fresh on every call (never captured once at construction time, matching
/// ``APIClientAtmosphereChanging``'s own doc comment in the consumer app)
/// and rotates the session's token when the response carries one.
@MainActor
struct APIClientSkinLoadingTests {
	private struct FakeTransport: APITransport {
		let outcome: Result<Data, StubError>

		func send(_: URLRequest) async throws -> Data {
			try outcome.get()
		}
	}

	private struct StubError: Error {}

	private struct FakeImplicitParameterProvider: ImplicitParameterProviding {
		var location: APICoordinate? {
			nil
		}

		var installedApps: InstalledAppsMask {
			[]
		}

		var preferredLanguage: String {
			"en"
		}
	}

	private func makeClient(json: String) -> APIClient {
		APIClient(
			configuration: APIClientConfiguration(
				environment: .production,
				deviceIdentifier: "idfv",
				screenWidth: 1024,
				clientVersion: "6.0.0",
				isKiosk: true,
			),
			implicitParameters: FakeImplicitParameterProvider(),
			transport: FakeTransport(outcome: .success(Data(json.utf8))),
		)
	}

	private func makeSignedInSessionStore(
		personId: String = "p1",
		venueId: String = "v1",
		token: String = "t1",
		passwordHash: String = "h1",
	) -> SessionStore {
		let sessionStore = SessionStore(
			snapshotStore: InMemorySessionSnapshotStore(),
			credentialStore: InMemoryCredentialStore(),
		)
		sessionStore.signIn(
			user: SessionUser(personId: personId, screenName: "dj"),
			venue: SessionVenue(venueId: venueId, name: venueId),
			credential: APICredential(token: token, passwordHash: passwordHash),
		)
		return sessionStore
	}

	@Test func `throws notSignedIn instead of calling the endpoint when no session is signed in`() async {
		let sessionStore = SessionStore(
			snapshotStore: InMemorySessionSnapshotStore(),
			credentialStore: InMemoryCredentialStore(),
		)
		let loading = APIClientSkinLoading(client: makeClient(json: "{}"), sessionStore: sessionStore)

		await #expect(throws: SkinLoadingError.notSignedIn) {
			try await loading.fetchManifest()
		}
	}

	@Test func `fetches the manifest for the signed-in user and venue`() async throws {
		let sessionStore = makeSignedInSessionStore()
		let loading = APIClientSkinLoading(
			client: makeClient(json: """
			{"Success": true, "Response": {"Images": [], "Properties": [{"Id": 1004, "Text": "20"}]}}
			"""),
			sessionStore: sessionStore,
		)

		let manifest = try await loading.fetchManifest()

		#expect(manifest.idleTimeoutSeconds == 20)
	}

	@Test func `rotates the session's token when the response carries one`() async throws {
		let sessionStore = makeSignedInSessionStore(token: "old")
		let loading = APIClientSkinLoading(
			client: makeClient(json: """
			{"Success": true, "Response": {"Images": [], "Properties": []}, "Token": "new"}
			"""),
			sessionStore: sessionStore,
		)

		_ = try await loading.fetchManifest()

		#expect(sessionStore.credential?.token == "new")
	}

	@Test func `maps a failed envelope to the server error`() async {
		let sessionStore = makeSignedInSessionStore()
		let loading = APIClientSkinLoading(
			client: makeClient(json: """
			{"Success": false, "Message": "Nope."}
			"""),
			sessionStore: sessionStore,
		)

		await #expect(throws: SkinLoadingError.server(message: "Nope.")) {
			try await loading.fetchManifest()
		}
	}

	@Test func `maps a transport failure to a connection error`() async {
		let sessionStore = makeSignedInSessionStore()
		let client = APIClient(
			configuration: APIClientConfiguration(
				environment: .production,
				deviceIdentifier: "idfv",
				screenWidth: 1024,
				clientVersion: "6.0.0",
				isKiosk: true,
			),
			implicitParameters: FakeImplicitParameterProvider(),
			transport: FakeTransport(outcome: .failure(StubError())),
		)
		let loading = APIClientSkinLoading(client: client, sessionStore: sessionStore)

		await #expect(throws: SkinLoadingError.connection) {
			try await loading.fetchManifest()
		}
	}
}
