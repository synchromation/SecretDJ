import SecretDJDomain

extension Gender {
	/// The wire's string form that `createuser`/`setuserdetails` send —
	/// distinct from the numeric `GenderId` that responses decode
	/// (`secretdjv3/Gender.swift`'s `Gender.text()`).
	var wireValue: String {
		switch self {
		case .unisex:
			"unspecified"

		case .male:
			"male"

		case .female:
			"female"
		}
	}
}
