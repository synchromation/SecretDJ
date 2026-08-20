import Foundation
import SecretDJAPI

/// A canned ``SecretDJAPI/APITransport`` for UI-test mode (PLAN.md S8.2) —
/// never touches `URLSession`, so nothing built on it can ever reach the
/// real network. Every feed endpoint this app calls (`placesnearby`,
/// `venue`, `activity`, `profile`, `nowplaying`, `musicselection`,
/// `musicdigest`, `styleinfo`, `musicsearch`, `extracontent`,
/// `topupdetails`, ...) decodes its body through the same permissive
/// `SectionListDecoder`, so one deterministic fixture list — one song, one
/// venue, one person, one top-up, each with an unmistakably synthetic
/// "Fixture ..." name, plus the insert-coin/search nav-bar actions S6.12
/// renders — answers every one of them and gives the accessibility audit a
/// real cell of each kind to inspect on whichever screen asks. Only
/// `artistsavailable`'s differently-shaped payload needs its own reply;
/// every other endpoint (including every write endpoint — `like`, `checkin`,
/// `requestsong`, `setuserdetails`, ...) is never exercised by navigation
/// alone, so this transport doesn't special-case them.
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
				"Title": "Fixture Venue",
				"ItemTypeId": 100,
				"Templates": [100],
				"Index": 0,
				"Custom": { "Hash": "fixture-hash-1" },
				"Items": [{
					"Text": "Fixture Venue\\n1 Fixture Way\\n0.1 miles",
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
						"CheckedIn": false,
						"MachineControl": true,
						"LikeInfo": { "LikedByYou": false, "Info": "12 people like this venue" }
					}
				}]
			},
			{
				"Title": "Now Playing",
				"ItemTypeId": 200,
				"Templates": [200],
				"Index": 1,
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
			},
			{
				"Title": "Fixture Credits",
				"ItemTypeId": 700,
				"Templates": [700],
				"Index": 3,
				"Custom": {},
				"Items": [{
					"Text": "Fixture Credits",
					"Index": 0,
					"Data": {
						"SKU": "fixture.topup.1",
						"VendorId": 2,
						"Name": "Fixture Credits",
						"Description": "10 fixture credits",
						"Price": "0.99",
						"DisplayPrice": "$0.99",
						"CurrencyCode": "USD",
						"NumCredits": 10
					}
				}]
			}
		],
		"Actions": [
			{ "Id": 1, "Button": 100 },
			{ "Id": 200, "Button": 300 }
		]
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
