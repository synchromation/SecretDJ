import Foundation
import SecretDJDomain
import Testing

@testable import SecretDJAPI

enum UserAPITests {
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

	private static let credential = APICredential(
		token: "kPV0J8Q+DVABopusWMnQkc6kldY=",
		passwordHash: "889101801761492e1a2140d491c4235a1798e284",
	)

	struct userdetails {
		@Test func `sends the user id and signs the request`() async throws {
			let recorder = RequestRecorder()
			let client = UserAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("PersonDetails")),
				recorder: recorder,
			))

			_ = try await client.userDetails(userId: "00027786_c2eb9af2", credential: UserAPITests.credential)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/userdetails")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			// `userdetails` is absent from the sig-exclusion list
			// (`secretdjv3/NetworkAccess.swift:209`), so it always signs.
			#expect(parameters["sig"] != nil)
		}

		/// `Live/UserDetails.json` — a production `userdetails` capture
		/// (S1's R2 live-capture pass), confirming ``UserDetailsPayload``'s
		/// documented shape for real: `Sections[0].Items[0]` really is the
		/// current user as a `Person`, the same layout `persondetails` uses.
		/// This supersedes the earlier `persondetails`-fixture stand-in —
		/// see ``UserDetailsPayload``'s doc comment.
		@Test func `decodes the Person from the first section's first item`() async throws {
			let client = UserAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.liveData("UserDetails"))),
			)

			let response = try await client.userDetails(
				userId: "01256912_5442fc6c",
				credential: UserAPITests.credential,
			)

			#expect(response.payload.personId == "01256912_5442fc6c")
			#expect(response.payload.screenName == "nickbot")
			#expect(response.payload.gender == .unisex)
		}

		@Test func `throws decoding when the response carries no Person item`() async {
			let json = Data(#"{"Success": true, "Sections": []}"#.utf8)
			let client = UserAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			await #expect(throws: APIError.self) {
				_ = try await client.userDetails(userId: "x", credential: UserAPITests.credential)
			}
		}
	}

	struct setuserdetails {
		@Test func `always sends the user id and signs the request`() async throws {
			let recorder = RequestRecorder()
			let client = UserAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("SetUserDetails")),
				recorder: recorder,
			))

			_ = try await client.setUserDetails(userId: "u", credential: UserAPITests.credential)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/setuserdetails")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "u")
			#expect(parameters["sig"] != nil)
		}

		/// `secretdjv3/UserDetailsAPIAccess.swift`'s `changeUserDetails`
		/// permutation: first/last/screenname/email together, no
		/// gender/password.
		@Test func `full-details permutation sends only the profile fields`() async throws {
			let recorder = RequestRecorder()
			let client = UserAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("SetUserDetails")),
				recorder: recorder,
			))

			_ = try await client.setUserDetails(
				userId: "u",
				firstName: "Tim",
				lastName: "Harrison",
				screenName: "TurboTim",
				email: "tim@example.com",
				credential: UserAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["firstname"] == "Tim")
			#expect(parameters["lastname"] == "Harrison")
			#expect(parameters["screenname"] == "TurboTim")
			#expect(parameters["email"] == "tim%40example.com")
			#expect(parameters["gender"] == nil)
			#expect(parameters["password"] == nil)
		}

		/// `secretdjv3/UserDetailsAPIAccess.swift`'s `changePassword`
		/// permutation: only `user` + `password` (a SHA-1 hash).
		@Test func `password-only permutation sends only the hashed password`() async throws {
			let recorder = RequestRecorder()
			let client = UserAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("SetUserDetails")),
				recorder: recorder,
			))

			_ = try await client.setUserDetails(
				userId: "u",
				passwordHash: "newhash",
				credential: UserAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["password"] == "newhash")
			#expect(parameters["firstname"] == nil)
			#expect(parameters["gender"] == nil)
		}

		/// `secretdjv3/UserDetailsAPIAccess.swift`'s `changeGender`
		/// permutation: only `user` + `gender` (the legacy wire string, not
		/// the numeric `GenderId`).
		@Test func `gender-only permutation sends only the wire gender string`() async throws {
			let recorder = RequestRecorder()
			let client = UserAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("SetUserDetails")),
				recorder: recorder,
			))

			_ = try await client.setUserDetails(userId: "u", gender: .female, credential: UserAPITests.credential)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["gender"] == "female")
			#expect(parameters["password"] == nil)
			#expect(parameters["firstname"] == nil)
		}

		/// `secretdjv3/UserDetailsAPIAccess.swift`'s `changeUserName`
		/// permutation: only `user` + `screenname`.
		@Test func `username-only permutation sends only the screen name`() async throws {
			let recorder = RequestRecorder()
			let client = UserAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("SetUserDetails")),
				recorder: recorder,
			))

			_ = try await client.setUserDetails(userId: "u", screenName: "NewName", credential: UserAPITests.credential)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["screenname"] == "NewName")
			#expect(parameters["firstname"] == nil)
			#expect(parameters["gender"] == nil)
		}

		/// `SetUserDetails.json`: `Success: true`, `ReturnCode: 0`, `Message: ""`.
		@Test func `decodes ReturnCode 0 as success`() async throws {
			let client = UserAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("SetUserDetails"))),
			)

			let response = try await client.setUserDetails(userId: "u", credential: UserAPITests.credential)

			#expect(response.payload.returnCode == 0)
		}

		/// No legacy fixture captures `setuserdetails`'s failure path; this
		/// shape is constructed from the documented contract
		/// (`secretdjv3/UserDetailsAPIAccess.swift`'s `saveUserDetails`: any
		/// non-zero `ReturnCode` plus `Message` is the failure).
		/// // LIVE-CAPTURE: the exact non-zero codes this endpoint sends
		/// aren't documented beyond "non-zero means failure".
		@Test func `surfaces a non-zero ReturnCode and message without throwing`() async throws {
			let json = Data(#"{"Success": true, "ReturnCode": -1, "Message": "That screen name is taken."}"#.utf8)
			let client = UserAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.setUserDetails(userId: "u", credential: UserAPITests.credential)

			#expect(response.payload.returnCode == -1)
			#expect(response.payload.message == "That screen name is taken.")
		}
	}

	struct newavatar {
		@Test func `POSTs a signed multipart body with the user id and JPEG file part`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "Response": {"Text": "Thanks!"}, "Token": "t"}"#.utf8)
			let client = UserAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))
			let imageData = Data("fake-jpeg-bytes".utf8)

			_ = try await client.uploadAvatar(
				userId: "00027786_c2eb9af2",
				imageData: imageData,
				credential: UserAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.httpMethod == "POST")
			#expect(request.url?.path == "/newavatar")
			let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
			#expect(contentType.hasPrefix("multipart/form-data; boundary="))

			let text = try bodyText(of: request)
			#expect(text.contains("name=\"user\""))
			#expect(text.contains("00027786_c2eb9af2"))
			#expect(text.contains("name=\"sig\""))
			#expect(text.contains(#"name="avatarfile"; filename="avatar.jpg""#))
			#expect(text.contains("Content-Type: image/jpeg"))
			#expect(text.contains("fake-jpeg-bytes"))
		}

		/// Constructed from the documented contract (LEGACY.md's catalog:
		/// "`Response.Text` toast"; `secretdjv3/AvatarAPIAccess.swift` only
		/// ever reads that field) — see ``AvatarUploadPayload``'s doc comment
		/// for why `AvatarChange.json` isn't used here.
		/// // LIVE-CAPTURE: exact reward copy is unconfirmed; this fixture
		/// uses placeholder text to prove the field threads through untouched.
		@Test func `decodes the reward text from Response Text`() async throws {
			let json = Data(
				#"{"Success": true, "Response": {"Text": "You earned 1 free credit!"}, "Token": "t"}"#.utf8,
			)
			let client = UserAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.uploadAvatar(
				userId: "u",
				imageData: Data(),
				credential: UserAPITests.credential,
			)

			#expect(response.payload.text == "You earned 1 free credit!")
		}

		/// The legacy fixture nominally captured for this endpoint
		/// (`AvatarChange.json`: `Success`, `Image`, `Token` — no `Response`
		/// key at all) doesn't match the documented `Response.Text` contract
		/// that `secretdjv3/AvatarAPIAccess.swift` actually parses. The only
		/// legacy test that loads it (`AvatarAPIAccessTests.testReportsAvatarChange`)
		/// never asserts on its parsed content, so nothing pins this
		/// mismatch as intentional — it isn't trustworthy evidence of the
		/// real success shape, and decoding it correctly throws here.
		@Test func `throws decoding the legacy AvatarChange fixture, which lacks a Response object`() async {
			let client = UserAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("AvatarChange"))),
			)

			await #expect(throws: APIError.self) {
				_ = try await client.uploadAvatar(userId: "u", imageData: Data(), credential: UserAPITests.credential)
			}
		}
	}

	struct requestdeleteaccount {
		@Test func `sends the user id and signs the request`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "Message": "Your account will be deleted."}"#.utf8)
			let client = UserAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.requestDeleteAccount(userId: "00027786_c2eb9af2", credential: UserAPITests.credential)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/requestdeleteaccount")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["sig"] != nil)
		}

		/// No legacy fixture exists for this endpoint at all.
		/// // LIVE-CAPTURE: exact confirmation copy is unconfirmed.
		@Test func `decodes the confirmation message on success`() async throws {
			let json = Data(#"{"Success": true, "Message": "Your account will be deleted."}"#.utf8)
			let client = UserAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.requestDeleteAccount(userId: "u", credential: UserAPITests.credential)

			#expect(response.payload.message == "Your account will be deleted.")
		}

		/// `secretdjv3/RequestDeleteAccountAPIAccess.swift` reads the same
		/// top-level `Success` the envelope already gates on — a `false`
		/// envelope throws before this endpoint's own payload is reached.
		@Test func `throws server on a failed envelope`() async {
			let json = Data(#"{"Success": false, "Message": "Could not delete account."}"#.utf8)
			let client = UserAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			do {
				_ = try await client.requestDeleteAccount(userId: "u", credential: UserAPITests.credential)
				Issue.record("expected requestDeleteAccount to throw")
			} catch APIError.server(let message) {
				#expect(message == "Could not delete account.")
			} catch {
				Issue.record("expected .server, got \(error)")
			}
		}
	}
}
