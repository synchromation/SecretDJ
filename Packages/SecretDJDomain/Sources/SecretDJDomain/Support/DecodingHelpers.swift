extension String {
	/// `nil` when this decoded string is empty — the legacy server uses `""`
	/// as its sentinel for "this optional field has no value" (previews,
	/// affiliate URLs, promotion URLs, ...).
	var nonEmptyOrNil: String? {
		isEmpty ? nil : self
	}
}
