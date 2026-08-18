import Foundation

@testable import SecretDJAPI

struct StubTransportError: Error, Equatable {
	let message: String
}

struct FakeAPITransport: APITransport {
	let outcome: Result<Data, StubTransportError>

	func send(_: URLRequest) async throws -> Data {
		try outcome.get()
	}
}
