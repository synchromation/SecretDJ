import Foundation

/// Stores the auto-lock preference as a `Bool` in `UserDefaults`, under the
/// same key the legacy Settings-bundle toggle used
/// (`secretdjv3/Settings.bundle/Root.plist`'s `DisableAutoLock`) — not for
/// migration (D6: no legacy migration), just so the key a developer greps
/// for stays recognizable.
@MainActor
struct UserDefaultsAutoLockPreferenceStore: AutoLockPreferenceStoring {
	private static let key = "DisableAutoLock"

	private let defaults: UserDefaults

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	func isAutoLockDisabled() -> Bool {
		defaults.bool(forKey: Self.key)
	}

	func setAutoLockDisabled(_ isDisabled: Bool) {
		defaults.set(isDisabled, forKey: Self.key)
	}
}
