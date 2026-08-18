import Foundation
import SecretDJDomain

/// Orchestrates one API call end to end: builds the signed request
/// (``APIRequestBuilder``), sends it over the injected ``APITransport``,
/// and decodes the envelope (``APIEnvelopeHeader``) plus the caller's
/// payload type — mapping every failure into a typed ``APIError``.
///
/// Endpoint methods with typed parameters/payloads land in S1.3; this type
/// is the reusable core they call into.
public struct APIClient: Sendable {
	private let requestBuilder: APIRequestBuilder
	private let transport: any APITransport
	private let decoder: JSONDecoder

	public init(
		configuration: APIClientConfiguration,
		implicitParameters: any ImplicitParameterProviding,
		transport: any APITransport,
		signer: any RequestSigning = HMACSHA1RequestSigner(),
	) {
		requestBuilder = APIRequestBuilder(
			configuration: configuration,
			implicitParameters: implicitParameters,
			signer: signer,
		)
		self.transport = transport
		decoder = JSONDecoder()
	}

	/// Calls `endpoint`, decoding its body as `Payload`.
	///
	/// The envelope's `Success` is checked before `Payload` is decoded: a
	/// `false` envelope throws ``APIError/server(message:)`` immediately,
	/// since a failure response's body often omits the fields `Payload`
	/// expects (LEGACY.md "Backend API and Spotify integration" → "Response
	/// envelope and retry").
	public func execute<Payload: Decodable & Sendable>(
		endpoint: String,
		parameters: [String: String],
		signed: Bool,
		credential: APICredential?,
		decodingPayloadAs _: Payload.Type,
	) async throws(APIError) -> APIResponse<Payload> {
		let request = try requestBuilder.request(
			endpoint: endpoint,
			parameters: parameters,
			signed: signed,
			credential: credential,
		)
		return try await send(request) { try decoder.decode(Payload.self, from: $0) }
	}

	/// Calls a `multipart/form-data` endpoint (`newavatar`; S1.3g's
	/// `topupnotify`), decoding its body as `Payload`. Every multipart
	/// endpoint in this API always signs
	/// (``APIRequestBuilder/multipartRequest(endpoint:parameters:fileFieldName:filename:mimeType:fileData:credential:)``'s
	/// doc comment), so `credential` is required rather than optional here.
	public func execute<Payload: Decodable & Sendable>(
		multipartEndpoint endpoint: String,
		parameters: [String: String],
		fileFieldName: String,
		filename: String,
		mimeType: String,
		fileData: Data,
		credential: APICredential,
		decodingPayloadAs _: Payload.Type,
	) async throws(APIError) -> APIResponse<Payload> {
		let request = try requestBuilder.multipartRequest(
			endpoint: endpoint,
			parameters: parameters,
			fileFieldName: fileFieldName,
			filename: filename,
			mimeType: mimeType,
			fileData: fileData,
			credential: credential,
		)
		return try await send(request) { try decoder.decode(Payload.self, from: $0) }
	}

	/// Calls a feed endpoint (S1.3c–e: `placesnearby`, `venuedetails`,
	/// `eventhistory`, `persondetails`, `playhistory`, `extracontent`,
	/// `musicsearch`, `musicselection`, `musicdigest`, `styleinfo`),
	/// decoding its body with ``SectionListDecoder`` rather than a
	/// caller-supplied `Decodable` type — ``SecretDJDomain/SectionList``
	/// deliberately isn't `Decodable` (S1.1's architecture split; see
	/// `SecretDJDomain.Item`'s doc comment). `artistsavailable`'s flat,
	/// non-`SectionList` response shape doesn't go through this — see
	/// ``APIClient/artistsAvailable(userId:venueId:hash:credential:)``.
	public func executeFeed(
		endpoint: String,
		parameters: [String: String],
		signed: Bool,
		credential: APICredential?,
	) async throws(APIError) -> APIResponse<SecretDJDomain.SectionList> {
		let request = try requestBuilder.request(
			endpoint: endpoint,
			parameters: parameters,
			signed: signed,
			credential: credential,
		)
		return try await send(request) { try SectionListDecoder().decode($0) }
	}

	/// The shared transport-send → envelope-check → payload-decode pipeline
	/// every `execute`/`executeFeed` call runs, differing only in how they
	/// built `request` and how `decode` turns the response body into
	/// `Payload`.
	private func send<Payload: Sendable>(
		_ request: URLRequest,
		decode: (Data) throws -> Payload,
	) async throws(APIError) -> APIResponse<Payload> {
		let data: Data
		do {
			data = try await transport.send(request)
		} catch {
			throw .transport(error)
		}

		let header: APIEnvelopeHeader
		do {
			header = try decoder.decode(APIEnvelopeHeader.self, from: data)
		} catch {
			throw .decoding(error)
		}

		guard header.isSuccess else {
			throw .server(message: header.message)
		}

		let payload: Payload
		do {
			payload = try decode(data)
		} catch {
			throw .decoding(error)
		}

		return APIResponse(payload: payload, rotatedToken: header.token)
	}
}
