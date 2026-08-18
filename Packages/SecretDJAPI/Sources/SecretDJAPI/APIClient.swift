import Foundation

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
		return try await send(request)
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
		return try await send(request)
	}

	/// The shared transport-send → envelope-check → payload-decode pipeline
	/// both `execute` overloads run, differing only in how they built
	/// `request`.
	private func send<Payload: Decodable & Sendable>(_ request: URLRequest) async throws(APIError)
		-> APIResponse<Payload>
	{
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
			payload = try decoder.decode(Payload.self, from: data)
		} catch {
			throw .decoding(error)
		}

		return APIResponse(payload: payload, rotatedToken: header.token)
	}
}
