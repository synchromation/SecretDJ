import Foundation

/// Builds `URLRequest`s for the Secret DJ API, reproducing the legacy
/// client's wire format byte-for-byte where the server requires it
/// (LEGACY.md "Backend API and Spotify integration").
///
/// This type only assembles requests — it never sends them. Endpoint
/// methods with typed parameters/payloads land in S1.3, calling into this
/// builder (usually via ``APIClient``).
public struct APIRequestBuilder: Sendable {
	private let configuration: APIClientConfiguration
	private let implicitParameters: any ImplicitParameterProviding
	private let signer: any RequestSigning

	public init(
		configuration: APIClientConfiguration,
		implicitParameters: any ImplicitParameterProviding,
		signer: any RequestSigning = HMACSHA1RequestSigner(),
	) {
		self.configuration = configuration
		self.implicitParameters = implicitParameters
		self.signer = signer
	}

	/// Builds a GET request for `endpoint` (the server's raw path, e.g.
	/// `"signin"` — no leading slash), merging `parameters` with the
	/// implicit parameter set and, when `signed`, a `sig` computed from
	/// `credential`. The preferred language is never a query parameter;
	/// it's set as the request's `Accept-Language` header instead (D11).
	///
	/// Precedence on key collisions matches the legacy client exactly:
	/// implicit parameters overwrite same-named explicit ones, and `sig`
	/// (when present) overwrites last (`secretdjv3/NetworkAccess.swift:202-223`).
	/// - Throws: ``APIError/missingCredential`` when `signed` is `true` and
	///   `credential` is `nil`; ``APIError/requestGeneration`` if the result
	///   would not be a valid URL.
	// S8.1-FOLLOWUP: this header is sent correctly and verified against the
	// live backend (PLAN.md S8.1's D11 end-to-end check, 2026-08-20):
	// `placesnearby` called with `Accept-Language: es/fr/de/nl` returns
	// byte-identical section titles/LikeInfo copy to `en` every time — the
	// server does not localize this endpoint's copy despite D11's text ("the
	// backend returns copy localized for the five languages"). Flagged for
	// the product owner; not a client-side defect, so nothing to fix here —
	// remove this note once the backend is confirmed to localize or D11 is
	// revisited.
	public func request(
		endpoint: String,
		parameters: [String: String],
		signed: Bool,
		credential: APICredential?,
	) throws(APIError) -> URLRequest {
		var allParameters = parameters
		for (key, value) in implicitParameterValues() {
			allParameters[key] = value
		}

		if signed {
			guard let credential else {
				throw .missingCredential
			}
			allParameters["sig"] = signer.signature(token: credential.token, passwordHash: credential.passwordHash)
		}

		let url = try Self.buildURL(
			baseURL: configuration.environment.baseURL,
			endpoint: endpoint,
			parameters: allParameters,
		)

		var request = URLRequest(url: url)
		for (field, value) in configuration.headers {
			request.setValue(value, forHTTPHeaderField: field)
		}
		request.setValue(implicitParameters.preferredLanguage, forHTTPHeaderField: "Accept-Language")
		return request
	}

	/// Builds a `multipart/form-data` `POST` request for `endpoint`,
	/// matching the legacy client's construction
	/// (`secretdjv3/PostRequestProvider.swift`'s `imageRequestBody`): text
	/// fields (`parameters` plus the implicit set and `sig`) followed by one
	/// file part.
	///
	/// Every multipart endpoint in this API always signs — `newavatar`
	/// (S1.3g's `topupnotify` too) is absent from the sig-exclusion list,
	/// and `NetworkAccess.generateAvatarUploadRequest` asserts a
	/// token/password always exist — so `credential` is required, not
	/// optional, here (contrast
	/// ``request(endpoint:parameters:signed:credential:)``).
	///
	/// Unlike that GET builder, this deliberately does *not* mirror one
	/// legacy quirk: `NetworkAccess.generateAvatarUploadRequest` only ever
	/// adds `sig`, never `appmask`/`coords`/`appmodel`. This rewrite
	/// includes the full implicit set here too — S1.2 established it "on
	/// every request" (PLAN.md). It also sets `Accept-Language` from the
	/// same provider seam, so server copy (including this endpoint's
	/// reward toast) arrives localized (D11).
	public func multipartRequest(
		endpoint: String,
		parameters: [String: String],
		fileFieldName: String,
		filename: String,
		mimeType: String,
		fileData: Data,
		credential: APICredential,
	) throws(APIError) -> URLRequest {
		var allParameters = parameters
		for (key, value) in implicitParameterValues() {
			allParameters[key] = value
		}
		allParameters["sig"] = signer.signature(token: credential.token, passwordHash: credential.passwordHash)

		guard let scheme = configuration.environment.baseURL.scheme,
		      let host = configuration.environment.baseURL.host else
		{
			throw .requestGeneration
		}
		guard let url = URL(string: "\(scheme)://\(host)/\(endpoint)") else {
			throw .requestGeneration
		}

		let formBuilder = MultipartFormDataBuilder()
		let body = formBuilder.body(
			fields: allParameters,
			fileFieldName: fileFieldName,
			filename: filename,
			mimeType: mimeType,
			fileData: fileData,
		)

		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.httpBody = body
		for (field, value) in configuration.headers {
			request.setValue(value, forHTTPHeaderField: field)
		}
		request.setValue(formBuilder.contentType, forHTTPHeaderField: "Content-Type")
		request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
		request.setValue(implicitParameters.preferredLanguage, forHTTPHeaderField: "Accept-Language")
		return request
	}

	private func implicitParameterValues() -> [String: String] {
		var values: [String: String] = [
			"appmask": String(implicitParameters.installedApps.rawValue),
		]
		if let location = implicitParameters.location {
			values["coords"] = location.queryValue
		}
		if configuration.isKiosk {
			values["appmodel"] = "1"
		}
		return values
	}

	/// The server needs more percent-escaping than Apple's default query
	/// encoding provides; this reproduces the AFNetworking-compatible
	/// character set the legacy client used, including the `+`/`=`
	/// signature-escaping quirk (`secretdjv3/NetworkingParameterProvider.swift:54-113`).
	private static let legacyAllowedCharacters: CharacterSet = {
		var set = CharacterSet.urlQueryAllowed
		set.remove(charactersIn: "!$&'()*+,;=")
		set.remove(charactersIn: ":#[]@")
		return set
	}()

	/// Both failure guards below are defensive: every ``APIEnvironment``
	/// case yields a valid `https` URL, so neither is reachable through
	/// this package's public inputs today. They stay typed errors rather
	/// than preconditions because a future environment or endpoint source
	/// could make them reachable, and a malformed request should never
	/// crash the app.
	private static func buildURL(
		baseURL: URL,
		endpoint: String,
		parameters: [String: String],
	) throws(APIError) -> URL {
		guard let scheme = baseURL.scheme, let host = baseURL.host else {
			throw .requestGeneration
		}

		let encodedQuery = parameters
			.compactMap { key, value -> String? in
				guard let encodedValue = value.addingPercentEncoding(withAllowedCharacters: legacyAllowedCharacters) else {
					return nil
				}
				return "\(key)=\(encodedValue)"
			}
			.joined(separator: "&")

		guard let url = URL(string: "\(scheme)://\(host)/\(endpoint)?\(encodedQuery)") else {
			throw .requestGeneration
		}
		return url
	}
}
