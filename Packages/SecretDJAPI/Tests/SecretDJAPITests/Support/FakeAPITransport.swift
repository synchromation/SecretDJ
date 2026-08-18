import Foundation

@testable import SecretDJAPI

struct StubTransportError: Error, Equatable {
	let message: String
}

/// Records every `URLRequest` a ``FakeAPITransport`` sends, so endpoint
/// tests can assert on the built request (path/parameters/signing) without
/// a real network call. A reference type so it survives being captured
/// before the fake is handed to the code under test.
final class RequestRecorder: @unchecked Sendable {
	private let lock = NSLock()
	private var storedRequests: [URLRequest] = []

	var requests: [URLRequest] {
		lock.lock()
		defer { lock.unlock() }
		return storedRequests
	}

	fileprivate func record(_ request: URLRequest) {
		lock.lock()
		defer { lock.unlock() }
		storedRequests.append(request)
	}
}

struct FakeAPITransport: APITransport {
	let outcome: Result<Data, StubTransportError>
	let recorder: RequestRecorder?

	init(outcome: Result<Data, StubTransportError>, recorder: RequestRecorder? = nil) {
		self.outcome = outcome
		self.recorder = recorder
	}

	func send(_ request: URLRequest) async throws -> Data {
		recorder?.record(request)
		return try outcome.get()
	}
}
