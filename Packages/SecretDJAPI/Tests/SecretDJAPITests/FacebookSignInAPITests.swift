import Foundation
import SecretDJDomain
import Testing

@testable import SecretDJAPI

/// `facebooksignin` (S4.4/D1 kept) — split out from `AuthAPITests` to keep
/// that file under the lint size limit; the `facebookSignIn`/`applesignin`
/// pair still share `SocialSignInWirePayload` and the `FacebookSignIn.json`
/// fixture (see `AuthAPITests.applesignin`'s decode test).
struct FacebookSignInAPITests {
	private static func makeClient(transport: some APITransport) -> APIClient {
		APIClient(
			configuration: APIClientConfiguration(
				environment: .production,
				deviceIdentifier: "idfv",
				screenWidth: 390,
				clientVersion: "5.1.4",
				isKiosk: false,
			),
			implicitParameters: FakeImplicitParameterProvider(),
			transport: transport,
		)
	}

	@Test func `always sends fbid, the access token, and the pre-built auth digest, unsigned`() async throws {
		let recorder = RequestRecorder()
		let json = Data(#"{"Success": true, "User": "u", "ScreenName": "s", "Param": "p", "Created": false}"#.utf8)
		let client = FacebookSignInAPITests.makeClient(transport: FakeAPITransport(
			outcome: .success(json),
			recorder: recorder,
		))

		_ = try await client.facebookSignIn(
			facebookUserId: "10154089931213890",
			accessToken: "fb-token",
			auth: "digest",
		)

		let request = try #require(recorder.requests.first)
		#expect(request.url?.path == "/facebooksignin")
		let parameters = try percentEncodedParameters(of: request)
		#expect(parameters["fbid"] == "10154089931213890")
		#expect(parameters["state"] == "fb-token")
		#expect(parameters["auth"] == "digest")
		#expect(parameters["sig"] == nil)
		#expect(parameters["gender"] == nil)
		#expect(parameters["firstname"] == nil)
	}

	/// Unlike `applesignin`, every profile field Facebook's Graph `me`
	/// request returns is sent independently — no all-or-nothing gating,
	/// since the Graph request runs on every sign-in attempt.
	@Test func `sends gender, name, and email independently, not all-or-nothing`() async throws {
		let recorder = RequestRecorder()
		let json = Data(#"{"Success": true, "User": "u", "ScreenName": "s", "Param": "p", "Created": false}"#.utf8)
		let client = FacebookSignInAPITests.makeClient(transport: FakeAPITransport(
			outcome: .success(json),
			recorder: recorder,
		))

		_ = try await client.facebookSignIn(
			facebookUserId: "id",
			accessToken: "tok",
			auth: "digest",
			gender: .female,
			firstName: "Tim",
		)

		let request = try #require(recorder.requests.first)
		let parameters = try percentEncodedParameters(of: request)
		#expect(parameters["gender"] == "female")
		#expect(parameters["firstname"] == "Tim")
		#expect(parameters["lastname"] == nil)
		#expect(parameters["email"] == nil)
	}

	/// `FacebookSignIn.json`: `User`, `ScreenName`, `Param`, `Created`, `Token`.
	@Test func `decodes the server-issued credential and screen name`() async throws {
		let client = FacebookSignInAPITests.makeClient(
			transport: FakeAPITransport(outcome: .success(Fixture.data("FacebookSignIn"))),
		)

		let response = try await client.facebookSignIn(facebookUserId: "id", accessToken: "tok", auth: "digest")

		#expect(response.payload.personId == "00027786_c2eb9af2")
		#expect(response.payload.screenName == "TurboTim")
		#expect(response.payload.issuedCredential == "f46278212c65661b70de203687118f005b67629e")
		#expect(response.payload.created == false)
		#expect(response.rotatedToken == "R5FfWWyPBVwimLIiS9tUnfIsD5U=")
	}

	@Test func `decodes Created true for a brand-new account`() async throws {
		let json = Data(#"{"Success": true, "User": "u", "ScreenName": "s", "Param": "p", "Created": true}"#.utf8)
		let client = FacebookSignInAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

		let response = try await client.facebookSignIn(facebookUserId: "id", accessToken: "tok", auth: "digest")

		#expect(response.payload.created == true)
	}
}
