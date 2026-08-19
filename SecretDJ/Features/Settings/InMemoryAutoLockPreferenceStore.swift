/// An in-memory ``AutoLockPreferenceStoring`` fake for tests and previews —
/// never touches real `UserDefaults`.
@MainActor
final class InMemoryAutoLockPreferenceStore: AutoLockPreferenceStoring {
	private var isDisabled: Bool

	init(isDisabled: Bool = false) {
		self.isDisabled = isDisabled
	}

	func isAutoLockDisabled() -> Bool {
		isDisabled
	}

	func setAutoLockDisabled(_ isDisabled: Bool) {
		self.isDisabled = isDisabled
	}
}
