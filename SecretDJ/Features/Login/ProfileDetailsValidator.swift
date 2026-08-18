/// Why a sign-up field failed client-side validation. Views map each case to
/// its own localized message; the validator itself carries no copy.
enum ProfileFieldValidationError: Equatable {
	/// The field was left empty.
	case missing
	/// The field doesn't match its allowed character pattern.
	case invalidCharacters
	/// The field is non-empty but shorter than the required minimum.
	case tooShort
}

/// Sign-up field validation ported from the legacy client's gate on
/// `createuser` (`secretdjv3/ProfileDetailsValidator.swift`), enforced
/// before submission to match the server's own rules.
enum ProfileDetailsValidator {
	/// `[a-zA-Z][a-zA-Z0-9-']{0,29}` — 1 to 30 characters
	/// (`secretdjv3/ProfileDetailsValidator.swift`'s `validate(firstName:)`).
	static func validate(firstName: String) -> ProfileFieldValidationError? {
		validate(name: firstName)
	}

	/// Same pattern as ``validate(firstName:)``
	/// (`secretdjv3/ProfileDetailsValidator.swift`'s `validate(lastName:)`).
	static func validate(lastName: String) -> ProfileFieldValidationError? {
		validate(name: lastName)
	}

	private static func validate(name: String) -> ProfileFieldValidationError? {
		guard !name.isEmpty else {
			return .missing
		}
		guard name.wholeMatch(of: nameRegex) != nil else {
			return .invalidCharacters
		}
		return nil
	}

	/// `[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}` — "the same
	/// validation RegEx as the server"
	/// (`secretdjv3/ProfileDetailsValidator.swift`'s `validate(emailAddress:)`).
	static func validate(email: String) -> ProfileFieldValidationError? {
		guard email.wholeMatch(of: emailRegex) != nil else {
			return .invalidCharacters
		}
		return nil
	}

	/// `[a-zA-Z][a-zA-Z0-9-'.]{4,29}` — 5 to 30 characters
	/// (`secretdjv3/ProfileDetailsValidator.swift`'s `validate(userName:)`).
	static func validate(screenName: String) -> ProfileFieldValidationError? {
		guard !screenName.isEmpty else {
			return .missing
		}
		guard screenName.wholeMatch(of: screenNameRegex) != nil else {
			return .invalidCharacters
		}
		return nil
	}

	/// At least 5 characters
	/// (`secretdjv3/ProfileDetailsValidator.swift`'s `validate(password:)`).
	static func validate(password: String) -> ProfileFieldValidationError? {
		guard !password.isEmpty else {
			return .missing
		}
		guard password.count >= 5 else {
			return .tooShort
		}
		return nil
	}

	// The hyphen sits last in each character class below (rather than
	// between `9` and `'` as in the legacy Objective-C-style pattern text)
	// so it reads unambiguously as a literal across regex engines; the set
	// of accepted characters is unchanged.
	private static let nameRegex = /[a-zA-Z][a-zA-Z0-9'-]{0,29}/
	private static let screenNameRegex = /[a-zA-Z][a-zA-Z0-9'.-]{4,29}/
	private static let emailRegex = /[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}/
}
