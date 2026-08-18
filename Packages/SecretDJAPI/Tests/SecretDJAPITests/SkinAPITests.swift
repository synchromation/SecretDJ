import Foundation
import Testing

@testable import SecretDJAPI

enum SkinAPITests {
	private static func makeClient(transport: some APITransport) -> APIClient {
		APIClient(
			configuration: APIClientConfiguration(
				environment: .production,
				deviceIdentifier: "idfv",
				screenWidth: 390,
				clientVersion: "5.1.4",
				isKiosk: true,
			),
			implicitParameters: FakeImplicitParameterProvider(),
			transport: transport,
		)
	}

	private static let credential = APICredential(
		token: "kPV0J8Q+DVABopusWMnQkc6kldY=",
		passwordHash: "889101801761492e1a2140d491c4235a1798e284",
	)

	struct skinresources {
		/// `secretdjv3/SkinAPIAccess.swift`'s `skinAssets`: `user`, `venue`.
		@Test func `sends user and venue, and signs the request`() async throws {
			let recorder = RequestRecorder()
			let client = SkinAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("SkinResources")),
				recorder: recorder,
			))

			_ = try await client.skinResources(
				userId: "00027786_c2eb9af2",
				venueId: "00007022_f86cba2b",
				credential: SkinAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/skinresources")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["venue"] == "00007022_f86cba2b")
			#expect(parameters["sig"] != nil)
		}

		/// `SkinResources.json`: the behavioral texts D10 names explicitly.
		@Test func `decodes the behavioral config texts`() async throws {
			let client = SkinAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("SkinResources"))),
			)

			let response = try await client.skinResources(
				userId: "u", venueId: "v", credential: SkinAPITests.credential,
			)

			#expect(response.payload
				.attractURL == URL(string: "http://pages.secretdj.com/kiosk/amex-2017/attract.html"))
			#expect(response.payload.attractTimeoutSeconds == 120)
			#expect(response.payload.idleTimeoutSeconds == 20)
			#expect(response.payload.headerHeight == 150)
		}

		/// Toast chrome (`SkinText` ids 1010-1013 —
		/// `secretdjv3/SimpleToastView.swift`'s `initializeKioskAttributes`).
		@Test func `decodes the toast appearance`() async throws {
			let client = SkinAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("SkinResources"))),
			)

			let response = try await client.skinResources(
				userId: "u", venueId: "v", credential: SkinAPITests.credential,
			)

			let toast = try #require(response.payload.toast)
			#expect(toast.backgroundColor == "#D8000000")
			#expect(toast.textColor == "#D8FCB700")
			#expect(toast.borderColor == "#00000000")
			#expect(toast.borderWidth == 0)
		}

		/// Every `SkinColor` role in `SkinResources.json` decodes into
		/// ``SkinManifest/colors``, keyed by role rather than the legacy
		/// magic numeric id (D10).
		@Test func `decodes every present chrome color, keyed by role`() async throws {
			let client = SkinAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("SkinResources"))),
			)

			let response = try await client.skinResources(
				userId: "u", venueId: "v", credential: SkinAPITests.credential,
			)

			#expect(response.payload.colors.count == 11)
			#expect(response.payload.colors[.standardButtonDefault] == "#FFFFFFFF")
			#expect(response.payload.colors[.jukeboxCellText] == "#E0D4D4D4")
			#expect(response.payload.colors[.nowPlayingTint] == "#FFFCC129")
			#expect(response.payload.colors[.artistCellBackground] == "#FFB0B0AD")
			#expect(response.payload.colors[.keyboardKeyHighlight] == "#FFFFFFFF")
		}

		/// Every `SkinAsset` role in `SkinResources.json` decodes into
		/// ``SkinManifest/images``, keyed by role and holding the asset's
		/// remote URL (downloading it is a caller concern — S7.2).
		@Test func `decodes every present chrome image, keyed by role`() async throws {
			let client = SkinAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("SkinResources"))),
			)

			let response = try await client.skinResources(
				userId: "u", venueId: "v", credential: SkinAPITests.credential,
			)

			#expect(response.payload.images.count == 34)
			#expect(
				response.payload.images[.nowPlayingBackground] ==
					URL(string: "http://secretdj.s3.amazonaws.com/resources/r-00000005/r-01001.png"),
			)
			#expect(
				response.payload.images[.requestSong] ==
					URL(string: "http://secretdj.s3.amazonaws.com/resources/r-00000005/r-01201.png"),
			)
		}

		/// D10's forward-compatibility guarantee: entries this build doesn't
		/// map to a typed role (search placeholders, and any ids not in the
		/// legacy `SkinAsset`/`SkinColor`/`SkinText` catalogue) survive as raw
		/// dictionaries keyed by the server's numeric id, rather than being
		/// silently dropped.
		@Test func `preserves unrecognized properties and images raw, keyed by id`() async throws {
			let client = SkinAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("SkinResources"))),
			)

			let response = try await client.skinResources(
				userId: "u", venueId: "v", credential: SkinAPITests.credential,
			)

			// `SkinResources.json`'s 28 Properties minus the 19 this build maps
			// to a typed role (4 behavioral texts, 4 toast fields, 11 colors).
			#expect(response.payload.unknownProperties.count == 9)
			#expect(response.payload.unknownProperties[1343] == "Tap on Artist Name for Songs...")
			#expect(response.payload.unknownProperties[1361] == "Search by Title or Artist...")

			// `SkinResources.json`'s 37 Images minus the 34 known `SkinAsset` roles.
			#expect(response.payload.unknownImages.count == 3)
			#expect(
				response.payload.unknownImages[1310] ==
					URL(string: "http://secretdj.s3.amazonaws.com/resources/r-00000005/r-01310.png"),
			)
		}

		/// A skin with no behavioral texts at all decodes to `nil` fields
		/// rather than throwing — S7.2's caller (or a DesignSystem default)
		/// decides the fallback, not this decode.
		@Test func `missing behavioral texts decode to nil rather than throwing`() async throws {
			let json = Data(#"{"Success": true, "Response": {"Images": [], "Properties": []}}"#.utf8)
			let client = SkinAPITests.makeClient(transport: FakeAPITransport(outcome: .success(json)))

			let response = try await client.skinResources(
				userId: "u",
				venueId: "v",
				credential: SkinAPITests.credential,
			)

			#expect(response.payload.attractURL == nil)
			#expect(response.payload.attractTimeoutSeconds == nil)
			#expect(response.payload.idleTimeoutSeconds == nil)
			#expect(response.payload.toast == nil)
			#expect(response.payload.colors.isEmpty)
			#expect(response.payload.images.isEmpty)
			#expect(response.payload.unknownProperties.isEmpty)
			#expect(response.payload.unknownImages.isEmpty)
		}
	}
}
