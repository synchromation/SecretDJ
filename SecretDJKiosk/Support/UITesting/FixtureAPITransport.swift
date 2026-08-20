import Foundation
import SecretDJAPI

/// A canned ``SecretDJAPI/APITransport`` for UI-test mode (PLAN.md S8.2) —
/// mirrors the consumer app's own `FixtureAPITransport`
/// (`SecretDJ/Support/UITesting/FixtureAPITransport.swift`). Never touches
/// `URLSession`; every feed endpoint the kiosk calls (`musicdigest`,
/// `musicselection`, `styleinfo`, `musicsearch`, `nowplaying`, ...) decodes
/// through the same permissive `SectionListDecoder`, so one deterministic
/// fixture list answers all of them. `skinresources` is deliberately not
/// special-cased here: ``UITestDependencies`` pre-seeds the kiosk's
/// `InMemorySkinStoring` directly, so `SkinModel.start()`'s cache-hit path
/// never calls it in the first place (see that type's own doc comment).
struct FixtureAPITransport: APITransport {
	func send(_ request: URLRequest) async throws -> Data {
		let endpoint = request.url?.path.trimmingCharacters(in: Self.slash) ?? ""
		let json = endpoint == "artistsavailable" ? Self.artistsAvailableJSON : Self.feedJSON
		return Data(json.utf8)
	}

	private static let slash = CharacterSet(charactersIn: "/")

	private static let feedJSON = """
	{
		"Success": true,
		"Token": "fixture-token",
		"Hash": "fixture-hash-1",
		"ElapsedTime": "0.01 seconds",
		"Sections": [
			{
				"Title": "Now Playing",
				"ItemTypeId": 200,
				"Templates": [200],
				"Index": 0,
				"Custom": { "Hash": "fixture-hash-1" },
				"Items": [{
					"Text": "Fixture Song",
					"Index": 0,
					"Data": {
						"SongId": "fixture-song-1",
						"Title": "Fixture Song",
						"Artist": "Fixture Artist",
						"LikeInfo": { "LikedByYou": false, "Info": "8 people buzzed this" }
					}
				}]
			},
			{
				"Title": "Fixture Venue",
				"ItemTypeId": 100,
				"Templates": [100],
				"Index": 1,
				"Custom": { "Hash": "fixture-hash-1" },
				"Items": [{
					"Text": "Fixture Venue",
					"Index": 0,
					"Data": {
						"Venue": "fixture-venue-1",
						"VenueName": "Fixture Venue",
						"VenueAddress": "1 Fixture Way",
						"Telephone": "",
						"Lat": 51.5074,
						"Lng": -0.1278,
						"ZoneName": "Fixture Zone",
						"Properties": 3,
						"CheckedIn": true,
						"MachineControl": true,
						"LikeInfo": { "LikedByYou": false, "Info": "12 people like this venue" }
					}
				}]
			},
			{
				"Title": "Fixture People",
				"ItemTypeId": 304,
				"Templates": [304],
				"Index": 2,
				"Custom": {},
				"Items": [{
					"Text": "Fixture Person",
					"Index": 0,
					"Data": {
						"User": "fixture-person-1",
						"ScreenName": "Fixture Person",
						"GenderId": 0,
						"LikeInfo": { "LikedByYou": false, "Info": "Like this person" }
					}
				}]
			}
		],
		"Actions": []
	}
	"""

	private static let artistsAvailableJSON = """
	{
		"Success": true,
		"Token": "fixture-token",
		"Artists": [],
		"TopupAllowed": false,
		"Hash": ""
	}
	"""
}
