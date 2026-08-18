import Foundation
import SecretDJDomain
import Testing

@testable import SecretDJAPI

enum SearchAPITests {
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

	struct musicsearch {
		/// `secretdjv3/SearchAPIAccess.swift`'s `search`: `user`, `venue`,
		/// `q`, `type`, `searchmask`.
		@Test func `sends every search parameter and signs the request`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "Sections": []}"#.utf8)
			let client = SearchAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.musicSearch(
				userId: "00027786_c2eb9af2",
				venueId: "00007022_f86cba2b",
				query: "Antmusic",
				type: .songs,
				mask: .computeLikes,
				credential: SearchAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/musicsearch")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["venue"] == "00007022_f86cba2b")
			#expect(parameters["q"] == "Antmusic")
			#expect(parameters["type"] == "2")
			#expect(parameters["searchmask"] == "1")
			#expect(parameters["sig"] != nil)
		}

		@Test func `sends the artists type code as 8`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "Sections": []}"#.utf8)
			let client = SearchAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))

			_ = try await client.musicSearch(
				userId: "u", venueId: "v", query: "q", type: .artists, mask: .none,
				credential: SearchAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["type"] == "8")
			#expect(parameters["searchmask"] == "0")
		}

		/// `Live/MusicSearch.json` — a production `musicsearch` capture (S1's
		/// R2 live-capture pass) for the query "beatles" against a real
		/// venue: a single results section, zero matches for this venue's
		/// catalogue. No legacy fixture existed for this endpoint, and the
		/// live response carries no top-level `Hash` — top-level hash
		/// decoding itself is already covered generically by
		/// `SectionListDecoderFixtureTests`.
		@Test func `decodes the response as a SectionList`() async throws {
			let client = SearchAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.liveData("MusicSearch"))),
			)

			let response = try await client.musicSearch(
				userId: "u", venueId: "v", query: "q", type: .songs, mask: .computeLikes,
				credential: SearchAPITests.credential,
			)

			#expect(response.payload.hash == FeedHash(rawValue: ""))
			#expect(response.payload.sections.first?.title == "Results for 'beatles'")
			#expect(response.payload.sections.first?.items.isEmpty == true)
		}
	}

	struct songsforartist {
		/// `secretdjv3/ArtistSearchFeedInteractor.swift`'s
		/// `SongsForVariableArtistFeedDataProvider.songsForArtist`: the
		/// same `musicsearch` call, but `type: .artists` with the artist's
		/// own name as `q` — there's no separate songs-for-artist endpoint.
		@Test func `searches by the artist's name with the artists type code`() async throws {
			let recorder = RequestRecorder()
			let json = Data(#"{"Success": true, "Sections": []}"#.utf8)
			let client = SearchAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(json),
				recorder: recorder,
			))
			// `songsForArtist` queries with `artist.name` — the sort-friendly
			// "Name" field (`secretdjv3/Artist.swift`: e.g. "Breeders, The"),
			// not the display `artist` field ("Artist": "The Breeders").
			let artist = Artist(
				name: "Breeders, The",
				artist: "The Breeders",
				numSongs: 12,
				sortIndex: 0,
				action: nil,
				actions: [],
			)

			_ = try await client.songsForArtist(
				artist,
				userId: "u",
				venueId: "v",
				credential: SearchAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/musicsearch")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["q"] == "Breeders%2C%20The")
			#expect(parameters["type"] == "8")
			#expect(parameters["searchmask"] == "1")
		}
	}

	struct artistsavailable {
		/// `secretdjv3/SearchAPIAccess.swift`'s `artists`: `user`, `venue`,
		/// optional `hash`.
		@Test func `sends user and venue, omitting hash when none is supplied`() async throws {
			let recorder = RequestRecorder()
			let client = SearchAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("ArtistsAvailable")),
				recorder: recorder,
			))

			_ = try await client.artistsAvailable(
				userId: "00027786_c2eb9af2",
				venueId: "00007022_f86cba2b",
				hash: nil,
				credential: SearchAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			#expect(request.url?.path == "/artistsavailable")
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00027786_c2eb9af2")
			#expect(parameters["venue"] == "00007022_f86cba2b")
			#expect(parameters["hash"] == nil)
			#expect(parameters["sig"] != nil)
		}

		@Test func `sends hash when supplied`() async throws {
			let recorder = RequestRecorder()
			let client = SearchAPITests.makeClient(transport: FakeAPITransport(
				outcome: .success(Fixture.data("ArtistsAvailable")),
				recorder: recorder,
			))

			_ = try await client.artistsAvailable(
				userId: "u",
				venueId: "v",
				hash: FeedHash(rawValue: "previous-hash"),
				credential: SearchAPITests.credential,
			)

			let request = try #require(recorder.requests.first)
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["hash"] == "previous-hash")
		}

		/// `ArtistsAvailable.json`: a flat `Artists` array (1042 entries),
		/// `TopupAllowed: true`, `Hash: "ef973ee7c137542b6e164ee9b765e414"` —
		/// unlike every other feed endpoint, no `Sections` at all
		/// (`secretdjv3/SearchAPIAccess.swift`'s `sectionList(fromAvailableArtistDictionary:)`
		/// only ever reads `Artists`/`TopupAllowed`).
		@Test func `decodes the flat artist array, topup flag, and hash`() async throws {
			let client = SearchAPITests.makeClient(
				transport: FakeAPITransport(outcome: .success(Fixture.data("ArtistsAvailable"))),
			)

			let response = try await client.artistsAvailable(
				userId: "u",
				venueId: "v",
				hash: nil,
				credential: SearchAPITests.credential,
			)

			#expect(response.payload.artists.count == 1042)
			#expect(response.payload.artists.first?.name == "1975, The")
			#expect(response.payload.artists.first?.artist == "The 1975")
			#expect(response.payload.artists.first?.numSongs == 3)
			#expect(response.payload.topUpAllowed == true)
			#expect(response.payload.hash == FeedHash(rawValue: "ef973ee7c137542b6e164ee9b765e414"))
		}
	}
}
