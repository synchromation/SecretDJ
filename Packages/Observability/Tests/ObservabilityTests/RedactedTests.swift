import Testing

@testable import Observability

struct RedactedTests {
	@Test func `hides the value while hinting at it`() {
		let redacted = Redacted("jane@example.com", label: "email")

		let description = String(describing: redacted)

		#expect(!description.contains("jane@example.com"))
		#expect(!description.contains("example.com"))
		#expect(description.contains("email"))
		#expect(description.contains("j…16"))
	}

	@Test func `the same value always produces the same hint`() {
		let first = String(describing: Redacted("jane@example.com"))
		let second = String(describing: Redacted("jane@example.com"))

		#expect(first == second)
	}

	@Test func `values differing beyond their hint still differ by digest`() {
		let jane = String(describing: Redacted("jane@example.com"))
		let jill = String(describing: Redacted("jill@example.com"))

		#expect(jane != jill)
	}

	@Test func `labels default to a generic value`() {
		let description = String(describing: Redacted("secret"))

		#expect(description.contains("value"))
	}

	@Test func `empty values stay redacted`() {
		let description = String(describing: Redacted("", label: "email"))

		#expect(description.contains("empty"))
	}

	@Test func `interpolating emits only the redacted form`() {
		let message = "signed in as \(Redacted("jane@example.com", label: "email"))"

		#expect(!message.contains("jane@example.com"))
		#expect(message.contains("⟨email:"))
	}
}
