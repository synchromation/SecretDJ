import Foundation
import SecretDJDomain
import Testing

@testable import SecretDJAPI

enum AuthAPITests {
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

	struct signin {
		@Test func `sends screenname and the already-hashed password, unsigned`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "User": "00027786_c2eb9af2", "Token": "t"}"#.utf8)
			let client = AuthAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.signIn(
				screenName: "TurboTim",
				passwordHash: "889101801761492e1a2140d491c4235a1798e284",
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/signin")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["screenname"] == "TurboTim")
			#expect(parameters["password"] == "889101801761492e1a2140d491c4235a1798e284")
			// `signin` is in the legacy sig-exclusion list
			// (`secretdjv3/NetworkAccess.swift:209`) — no `sig` parameter.
			#expect(parameters["sig"] == nil)
		}

		/// Shape matches `KioskSignIn.json`: `Success`, `User`, `Venues.Force`, `Token`.
		@Test func `decodes the forced venue id from Venues Force`() async throws {
			let client = AuthAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("KioskSignIn"))),
			)

			let response = try await client.signIn(screenName: "kioskuser", passwordHash: "hash")

			#expect(response.payload.personId == "00090552_0c3d31aa")
			#expect(response.payload.forcedVenueId == "00002162_f22f602a")
			#expect(response.payload.created == false)
			#expect(response.payload.issuedCredential == nil)
			#expect(response.rotatedToken == "+QA3fzUfb6lDhyn+cZ1DEiOoEOk=")
		}

		/// No legacy fixture omits `Venues` (`KioskSignIn.json` is the only
		/// captured `signin` response, and it forces a venue) — this shape is
		/// constructed directly from LEGACY.md's documented contract
		/// ("optional `Venues.Force`").
		@Test func `omits the forced venue id when Venues is absent`() async throws {
			let json = Data(#"{"Success": true, "User": "00027786_c2eb9af2", "Token": "t"}"#.utf8)
			let client = AuthAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.signIn(screenName: "TurboTim", passwordHash: "hash")

			#expect(response.payload.forcedVenueId == nil)
			#expect(response.payload.screenName == "TurboTim")
		}

		@Test func `throws server with the message on a failed envelope`() async {
			let json = Data(#"{"Success": false, "Message": "Wrong password."}"#.utf8)
			let client = AuthAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			do {
				_ = try await client.signIn(screenName: "x", passwordHash: "y")
				Issue.record("expected signIn to throw")
			} catch APIError.server(let message) {
				#expect(message == "Wrong password.")
			} catch {
				Issue.record("expected .server, got \(error)")
			}
		}
	}

	struct createuser {
		@Test func `sends every profile field plus the already-hashed password, unsigned`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "User": "x", "Token": "t"}"#.utf8)
			let client = AuthAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.createUser(
				firstName: "Tim",
				lastName: "Harrison",
				gender: .male,
				email: "tim@example.com",
				screenName: "TurboTim",
				passwordHash: "hash",
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/createuser")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["firstname"] == "Tim")
			#expect(parameters["lastname"] == "Harrison")
			// `secretdjv3/Gender.swift`'s `Gender.text()` — the wire sends the
			// string form, not the numeric `GenderId` responses decode.
			#expect(parameters["gender"] == "male")
			#expect(parameters["email"] == "tim%40example.com")
			#expect(parameters["screenname"] == "TurboTim")
			#expect(parameters["password"] == "hash")
			#expect(parameters["sig"] == nil)
		}

		@Test(arguments: [
			(Gender.unisex, "unspecified"),
			(Gender.male, "male"),
			(Gender.female, "female"),
		])
		func `maps every Gender case to its legacy wire string`(pair: (
			gender: Gender,
			wireValue: String,
		)) async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "User": "x", "Token": "t"}"#.utf8)
			let client = AuthAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.createUser(
				firstName: "a",
				lastName: "b",
				gender: pair.gender,
				email: "e",
				screenName: "s",
				passwordHash: "p",
			)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["gender"] == pair.wireValue)
		}

		/// `SignUp.json`: `Success`, `User`, `Image: []`, `Token`.
		@Test func `decodes the new personId and marks the account created`() async throws {
			let client = AuthAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("SignUp"))),
			)

			let response = try await client.createUser(
				firstName: "a",
				lastName: "b",
				gender: .unisex,
				email: "e",
				screenName: "NewScreenName",
				passwordHash: "p",
			)

			#expect(response.payload.personId == "00318136_b9463c08")
			#expect(response.payload.screenName == "NewScreenName")
			#expect(response.payload.created == true)
			#expect(response.payload.forcedVenueId == nil)
		}
	}

	struct applesignin {
		@Test func `always sends appuid and the pre-built auth digest, unsigned`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "User": "u", "ScreenName": "s", "Param": "p", "Created": false}"#.utf8)
			let client = AuthAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.appleSignIn(appleUserId: "00001234_a1b2c3d4", auth: "digest")

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/applesignin")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["appuid"] == "00001234_a1b2c3d4")
			#expect(parameters["auth"] == "digest")
			#expect(parameters["sig"] == nil)
			#expect(parameters["firstname"] == nil)
		}

		/// `secretdjv3/LoginAPIAccess.swift`'s
		/// `if let firstName, let lastName, let email` — first-auth name/email
		/// are all-or-nothing.
		@Test func `sends name and email together only when all three are supplied`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "User": "u", "ScreenName": "s", "Param": "p", "Created": true}"#.utf8)
			let client = AuthAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.appleSignIn(
				appleUserId: "00001234_a1b2c3d4",
				auth: "digest",
				firstName: "Tim",
				lastName: "Harrison",
				email: "tim@example.com",
			)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["firstname"] == "Tim")
			#expect(parameters["lastname"] == "Harrison")
			#expect(parameters["email"] == "tim%40example.com")
		}

		@Test func `omits name and email when only some are supplied`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "User": "u", "ScreenName": "s", "Param": "p", "Created": false}"#.utf8)
			let client = AuthAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.appleSignIn(appleUserId: "id", auth: "digest", firstName: "Tim")

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["firstname"] == nil)
			#expect(parameters["lastname"] == nil)
			#expect(parameters["email"] == nil)
		}

		/// LEGACY.md documents `applesignin`'s response as "same as facebook";
		/// `FacebookSignIn.json` pins that shared shape (`User`, `ScreenName`,
		/// `Param`, `Created`, `Token`) — see `FacebookSignInAPITests` for the
		/// same fixture exercised through `facebookSignIn` itself.
		@Test func `decodes the server-issued credential and screen name`() async throws {
			let client = AuthAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("FacebookSignIn"))),
			)

			let response = try await client.appleSignIn(appleUserId: "id", auth: "digest")

			#expect(response.payload.personId == "00027786_c2eb9af2")
			#expect(response.payload.screenName == "TurboTim")
			#expect(response.payload.issuedCredential == "f46278212c65661b70de203687118f005b67629e")
			#expect(response.payload.created == false)
			#expect(response.rotatedToken == "R5FfWWyPBVwimLIiS9tUnfIsD5U=")
		}

		@Test func `decodes Created true for a brand-new social account`() async throws {
			let json = Data(#"{"Success": true, "User": "u", "ScreenName": "s", "Param": "p", "Created": true}"#.utf8)
			let client = AuthAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.appleSignIn(appleUserId: "id", auth: "digest")

			#expect(response.payload.created == true)
		}
	}

	struct resetpassword {
		@Test func `sends screenname when resetting by screen name, unsigned`() async throws {
			let recorder = RequestRecorder()
			let client = AuthAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("PasswordChange")),
				recorder: recorder,
			))

			_ = try await client.resetPassword(screenName: "TurboTim")

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/resetpassword")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["screenname"] == "TurboTim")
			#expect(parameters["email"] == nil)
			#expect(parameters["sig"] == nil)
		}

		@Test func `sends email when resetting by email, unsigned`() async throws {
			let recorder = RequestRecorder()
			let client = AuthAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("PasswordChange")),
				recorder: recorder,
			))

			_ = try await client.resetPassword(email: "tim@example.com")

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["email"] == "tim%40example.com")
			#expect(parameters["screenname"] == nil)
		}

		/// `PasswordChange.json`: `Success: true`, `ReturnCode: 0`, `Message: ""`.
		@Test func `decodes ReturnCode 0 as success, not an envelope failure`() async throws {
			let client = AuthAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("PasswordChange"))),
			)

			let response = try await client.resetPassword(screenName: "TurboTim")

			#expect(response.payload.returnCode == 0)
		}

		/// `PasswordChangeFail.json`: `Success: true` (!) with `ReturnCode:
		/// -100` — the envelope's own `Success` stays `true` even on this
		/// endpoint's documented failure code, so this must decode rather
		/// than throw `.server`.
		@Test func `surfaces a non-zero ReturnCode and message without throwing`() async throws {
			let client = AuthAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("PasswordChangeFail"))),
			)

			let response = try await client.resetPassword(screenName: "")

			#expect(response.payload.returnCode == -100)
			#expect(response.payload
				.message == "Sorry, you must enter either the username or email associated with your account.")
		}
	}
}
