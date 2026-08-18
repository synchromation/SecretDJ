import Foundation
import Testing

@testable import SecretDJAPI

enum APIRequestBuilderTests {
	private static func makeBuilder(
		isKiosk: Bool = false,
		location: APICoordinate? = nil,
		installedApps: InstalledAppsMask = [],
		preferredLanguage: String = "en-GB",
	) -> APIRequestBuilder {
		APIRequestBuilder(
			configuration: APIClientConfiguration(
				environment: .production,
				deviceIdentifier: "idfv",
				screenWidth: 390,
				clientVersion: "5.1.4",
				isKiosk: isKiosk,
			),
			implicitParameters: FakeImplicitParameterProvider(
				location: location,
				installedApps: installedApps,
				preferredLanguage: preferredLanguage,
			),
		)
	}

	/// Percent-encoded name→value pairs, read without decoding so the
	/// pinned encoding-quirk tests can assert on the raw escape sequences.
	private static func percentEncodedParameters(of request: URLRequest) throws -> [String: String] {
		let url = try #require(request.url)
		let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
		let items = components.percentEncodedQueryItems ?? []
		return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
	}

	struct `URL targeting` {
		@Test func `targets the environment's base URL host over https`() throws {
			let builder = makeBuilder()

			let request = try builder.request(endpoint: "placesnearby", parameters: [:], signed: false, credential: nil)

			let url = try #require(request.url)
			#expect(url.scheme == "https")
			#expect(url.host == "api4.secretdj.com")
		}

		@Test func `the endpoint becomes the URL path`() throws {
			let builder = makeBuilder()

			let request = try builder.request(endpoint: "signin", parameters: [:], signed: false, credential: nil)

			#expect(request.url?.path == "/signin")
		}
	}

	struct `Explicit parameters` {
		@Test func `carries caller-supplied parameters through to the query`() throws {
			let builder = makeBuilder()

			let request = try builder.request(
				endpoint: "userdetails",
				parameters: ["user": "00000087_feae54c9"],
				signed: false,
				credential: nil,
			)

			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["user"] == "00000087_feae54c9")
		}
	}

	struct `Implicit parameters` {
		@Test func `always includes appmask`() throws {
			let builder = makeBuilder(installedApps: [.twitter, .uber])

			let request = try builder.request(endpoint: "placesnearby", parameters: [:], signed: false, credential: nil)

			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["appmask"] == "6")
		}

		@Test func `always includes the device language`() throws {
			let builder = makeBuilder(preferredLanguage: "es-ES")

			let request = try builder.request(endpoint: "placesnearby", parameters: [:], signed: false, credential: nil)

			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["lang"] == "es-ES")
		}

		@Test func `includes coords formatted to six decimal places when a location is known`() throws {
			let builder = makeBuilder(location: APICoordinate(latitude: 51.5, longitude: -0.1))

			let request = try builder.request(endpoint: "placesnearby", parameters: [:], signed: false, credential: nil)

			// "," is in the AFNetworking sub-delimiter escape set, so it's
			// percent-encoded here too (this helper reads raw, undecoded
			// values — see its doc comment).
			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["coords"] == "51.500000%2C-0.100000")
		}

		@Test func `omits coords when no location fix is known`() throws {
			let builder = makeBuilder(location: nil)

			let request = try builder.request(endpoint: "placesnearby", parameters: [:], signed: false, credential: nil)

			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["coords"] == nil)
		}

		@Test func `includes appmodel=1 for a kiosk configuration`() throws {
			let builder = makeBuilder(isKiosk: true)

			let request = try builder.request(endpoint: "placesnearby", parameters: [:], signed: false, credential: nil)

			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["appmodel"] == "1")
		}

		@Test func `omits appmodel for a consumer configuration`() throws {
			let builder = makeBuilder(isKiosk: false)

			let request = try builder.request(endpoint: "placesnearby", parameters: [:], signed: false, credential: nil)

			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["appmodel"] == nil)
		}

		/// Matches the legacy `+=` merge precedence
		/// (`secretdjv3/NetworkAccess.swift:202-223`, `NetworkAccess.swift:227-231`):
		/// implicit parameters overwrite a same-named explicit one.
		@Test func `an implicit parameter overwrites a same-named explicit one`() throws {
			let builder = makeBuilder(installedApps: [.facebook])

			let request = try builder.request(
				endpoint: "placesnearby",
				parameters: ["appmask": "999"],
				signed: false,
				credential: nil,
			)

			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["appmask"] == "1")
		}
	}

	struct `Query encoding quirk` {
		/// Pinned from `SecretDJTests/NetworkAccessTests.swift`'s
		/// `testEncodesQueryParametersAsExpectedByServer`.
		@Test func `escapes plus and equals exactly as the legacy client did`() throws {
			let builder = makeBuilder()

			let request = try builder.request(
				endpoint: "placesnearby",
				parameters: ["test": "YJDV3QHWb0davPI0pUyEA+n1LsQ="],
				signed: false,
				credential: nil,
			)

			let url = try #require(request.url)
			#expect(url.absoluteString.contains("test=YJDV3QHWb0davPI0pUyEA%2Bn1LsQ%3D"))
		}

		/// The AFNetworking sub-delimiter set
		/// (`secretdjv3/NetworkingParameterProvider.swift:104-113`).
		@Test func `escapes every AFNetworking sub-delimiter character`() throws {
			let builder = makeBuilder()

			let request = try builder.request(
				endpoint: "placesnearby",
				parameters: ["test": "!$&'()*+,;="],
				signed: false,
				credential: nil,
			)

			let url = try #require(request.url)
			let encodedValue = "%21%24%26%27%28%29%2A%2B%2C%3B%3D"
			#expect(url.absoluteString.contains("test=\(encodedValue)"))
		}

		/// The AFNetworking general-delimiter subset the legacy client also
		/// re-escapes (`secretdjv3/NetworkingParameterProvider.swift:104-113`).
		@Test func `escapes every AFNetworking general-delimiter character`() throws {
			let builder = makeBuilder()

			let request = try builder.request(
				endpoint: "placesnearby",
				parameters: ["test": ":#[]@"],
				signed: false,
				credential: nil,
			)

			let url = try #require(request.url)
			let encodedValue = "%3A%23%5B%5D%40"
			#expect(url.absoluteString.contains("test=\(encodedValue)"))
		}

		@Test func `leaves ordinary alphanumeric characters unescaped`() throws {
			let builder = makeBuilder()

			let request = try builder.request(
				endpoint: "placesnearby",
				parameters: ["test": "abcXYZ123"],
				signed: false,
				credential: nil,
			)

			let url = try #require(request.url)
			#expect(url.absoluteString.contains("test=abcXYZ123"))
		}
	}

	struct Signing {
		@Test func `omits sig when the endpoint is not signed`() throws {
			let builder = makeBuilder()

			let request = try builder.request(endpoint: "signin", parameters: [:], signed: false, credential: nil)

			let parameters = try percentEncodedParameters(of: request)
			#expect(parameters["sig"] == nil)
		}

		@Test func `appends a sig computed by the signer when signed`() throws {
			let builder = APIRequestBuilder(
				configuration: APIClientConfiguration(
					environment: .production,
					deviceIdentifier: "idfv",
					screenWidth: 390,
					clientVersion: "5.1.4",
					isKiosk: false,
				),
				implicitParameters: FakeImplicitParameterProvider(),
				signer: HMACSHA1RequestSigner(),
			)
			let credential = APICredential(
				token: "kPV0J8Q+DVABopusWMnQkc6kldY=",
				passwordHash: "889101801761492e1a2140d491c4235a1798e284",
			)

			let request = try builder.request(
				endpoint: "placesnearby",
				parameters: [:],
				signed: true,
				credential: credential,
			)

			// "/" is deliberately left unescaped — the legacy allowed-character
			// set excludes it from re-encoding (RFC 3986 §3.4;
			// `secretdjv3/NetworkingParameterProvider.swift:106`).
			let url = try #require(request.url)
			#expect(url.absoluteString.contains("sig=aT2uJ/sUIn/14v1XhnrlZzJgYL8%3D"))
		}

		@Test func `throws missingCredential when signed but no credential is supplied`() {
			let builder = makeBuilder()

			#expect(throws: APIError.self) {
				try builder.request(endpoint: "userdetails", parameters: [:], signed: true, credential: nil)
			}
		}
	}

	struct Headers {
		@Test func `sets the structured User-Agent header`() throws {
			let builder = makeBuilder()

			let request = try builder.request(endpoint: "placesnearby", parameters: [:], signed: false, credential: nil)

			#expect(request.value(forHTTPHeaderField: "User-Agent") == "secret dj idfv:390:514")
		}

		@Test func `sets the static Accept headers`() throws {
			let builder = makeBuilder()

			let request = try builder.request(endpoint: "placesnearby", parameters: [:], signed: false, credential: nil)

			#expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
			#expect(request.value(forHTTPHeaderField: "Accept-Language") == "en")
			#expect(request.value(forHTTPHeaderField: "Accept-Encoding") == "gzip")
		}
	}
}
