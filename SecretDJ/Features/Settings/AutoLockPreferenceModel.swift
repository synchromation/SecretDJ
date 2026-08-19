import Observability
import Observation
import UIKit

/// Drives the auto-lock toggle (S6.11) — an in-app replacement for the
/// legacy Settings-bundle `DisableAutoLock` toggle, applied to
/// `UIApplication.isIdleTimerDisabled` the moment it changes, and again on
/// every scene activation via ``applyPersistedPreference(store:)`` — porting
/// `secretdjv3/SceneDelegate.swift`'s `sceneDidBecomeActive` comment
/// verbatim: "Set auto-lock (we do this here so that changes to the
/// settings update automatically)". The system side effect stays a direct,
/// unseamed call (mirrors `AudioSessionConfiguration`'s own one-shot
/// `AVAudioSession` call) — only the *preference itself* needs a seam for
/// ``ChangeDetailsModel``-style testing, which ``AutoLockPreferenceStoring``
/// provides.
@Observable
@MainActor
final class AutoLockPreferenceModel {
	private(set) var isDisabled: Bool

	private let store: any AutoLockPreferenceStoring
	private let observability: ObservabilityPipeline

	init(store: any AutoLockPreferenceStoring, observability: ObservabilityPipeline = .disabled) {
		self.store = store
		self.observability = observability
		isDisabled = store.isAutoLockDisabled()
	}

	/// Persists `newValue` and applies it to the idle timer immediately. A
	/// no-op when `newValue` already matches ``isDisabled``.
	func updateIsDisabled(_ newValue: Bool) {
		guard newValue != isDisabled else {
			return
		}

		observability.interaction("toggleAutoLock")
		isDisabled = newValue
		store.setAutoLockDisabled(newValue)
		UIApplication.shared.isIdleTimerDisabled = newValue
	}

	/// Re-applies `store`'s persisted preference to the idle timer — call on
	/// every scene activation (the composition root's own porting of
	/// `secretdjv3/SceneDelegate.swift`'s `sceneDidBecomeActive`), so a
	/// change made while backgrounded (or on another scene) still takes
	/// effect.
	static func applyPersistedPreference(store: any AutoLockPreferenceStoring) {
		UIApplication.shared.isIdleTimerDisabled = store.isAutoLockDisabled()
	}
}
