/// Persists the auto-lock preference (S6.11) — an in-app replacement for the
/// legacy Settings-bundle `DisableAutoLock` toggle
/// (`secretdjv3/Settings.bundle/Root.plist`; `secretdjv3/UserManager.swift`'s
/// `disableAutoLock`). Abstracting storage behind this protocol keeps
/// ``AutoLockPreferenceModel`` free of persistence details and lets tests
/// substitute an in-memory store (mirrors ``SecretDJAPI/SessionSnapshotStoring``'s
/// own shape).
@MainActor
protocol AutoLockPreferenceStoring {
	/// Whether auto-lock is currently disabled; `false` (the legacy toggle's
	/// own default) when nothing has been saved yet.
	func isAutoLockDisabled() -> Bool

	/// Persists the preference.
	func setAutoLockDisabled(_ isDisabled: Bool)
}
