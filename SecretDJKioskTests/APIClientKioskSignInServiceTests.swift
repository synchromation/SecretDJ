import Foundation
import SecretDJAPI
import Testing

@testable import SecretDJKiosk

/// Covers ``APIClientKioskSignInService`` — the production
/// ``KioskSignInServicing``, over a fake ``APITransport`` so no real
/// network call happens. The business rule under test is the one PLAN.md
/// S7.1 calls out from LEGACY.md: "kiosk credentials are venue accounts,
/// and the backend pins them to one venue via `Venues.Force`" — a
/// response with no forced venue is rejected outright, mirroring legacy's
/// `kSignInUnauthorisedProblemText` ("wrong type of signin").
@MainActor
struct APIClientKioskSignInServiceTests {
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

	private func makeService(json: String) -> APIClientKioskSignInService {
		let client = APIClient(
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
		return APIClientKioskSignInService(client: client)
	}

	@Test func `returns the forced venue id and rotated token on success`() async throws {
		let service = makeService(json: """
		{"Success": true, "User": "00090552_0c3d31aa", "Venues": {"Force": "00002162_f22f602a"}, "Token": "tok"}
		""")

		let session = try await service.signIn(screenName: "kioskuser", passwordHash: "hash")

		#expect(session.personId == "00090552_0c3d31aa")
		#expect(session.screenName == "kioskuser")
		#expect(session.forcedVenueId == "00002162_f22f602a")
		#expect(session.rotatedToken == "tok")
	}

	@Test func `rejects a successful sign-in that carries no forced venue`() async {
		let service = makeService(json: """
		{"Success": true, "User": "00027786_c2eb9af2", "Token": "tok"}
		""")

		await #expect(throws: KioskSignInError.notAVenueAccount) {
			try await service.signIn(screenName: "notavenue", passwordHash: "hash")
		}
	}

	@Test func `maps a failed envelope to the server error`() async {
		let service = makeService(json: """
		{"Success": false, "Message": "Wrong password."}
		""")

		await #expect(throws: KioskSignInError.server(message: "Wrong password.")) {
			try await service.signIn(screenName: "kioskuser", passwordHash: "hash")
		}
	}
}
