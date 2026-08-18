import Testing

@testable import SecretDJ

enum ProfileDetailsValidatorTests {
	struct `First name` {
		@Test func `fails when empty`() {
			#expect(ProfileDetailsValidator.validate(firstName: "") == .missing)
		}

		@Test func `fails when it contains invalid characters`() {
			#expect(ProfileDetailsValidator.validate(firstName: "!") == .invalidCharacters)
		}

		@Test func `passes for a valid name`() {
			#expect(ProfileDetailsValidator.validate(firstName: "Secret") == nil)
		}

		@Test func `passes for a name with a hyphen and an apostrophe`() {
			#expect(ProfileDetailsValidator.validate(firstName: "Mary-O'Brien") == nil)
		}
	}

	struct `Last name` {
		@Test func `fails when empty`() {
			#expect(ProfileDetailsValidator.validate(lastName: "") == .missing)
		}

		@Test func `fails when it contains invalid characters`() {
			#expect(ProfileDetailsValidator.validate(lastName: "!") == .invalidCharacters)
		}

		@Test func `passes for a valid name`() {
			#expect(ProfileDetailsValidator.validate(lastName: "DJ") == nil)
		}
	}

	struct Email {
		@Test func `fails for an address with invalid characters`() {
			#expect(ProfileDetailsValidator.validate(email: "!!!@£££") == .invalidCharacters)
		}

		@Test func `fails for an empty address`() {
			#expect(ProfileDetailsValidator.validate(email: "") == .invalidCharacters)
		}

		@Test func `passes for a valid address`() {
			#expect(ProfileDetailsValidator.validate(email: "secret@dj.com") == nil)
		}
	}

	struct `Screen name` {
		@Test func `fails when empty`() {
			#expect(ProfileDetailsValidator.validate(screenName: "") == .missing)
		}

		@Test func `fails when shorter than five characters`() {
			#expect(ProfileDetailsValidator.validate(screenName: "Fred") == .invalidCharacters)
		}

		@Test func `fails when it contains invalid characters`() {
			#expect(ProfileDetailsValidator.validate(screenName: "!!!!!") == .invalidCharacters)
		}

		@Test func `passes for a valid screen name`() {
			#expect(ProfileDetailsValidator.validate(screenName: "SecretDJ") == nil)
		}
	}

	struct Password {
		@Test func `fails when empty`() {
			#expect(ProfileDetailsValidator.validate(password: "") == .missing)
		}

		@Test func `fails when shorter than five characters`() {
			#expect(ProfileDetailsValidator.validate(password: "AAAA") == .tooShort)
		}

		@Test func `passes at exactly five characters`() {
			#expect(ProfileDetailsValidator.validate(password: "12345") == nil)
		}
	}
}
