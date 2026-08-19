/// Where this build's Facebook app credentials live (S4.4; LEGACY.md
/// "Monetization, identity, analytics, and compliance" → "Facebook config").
/// `appID` and `displayName` are carried over verbatim from the legacy
/// plist; `clientToken` has no legacy equivalent — the legacy app predates
/// the modern Facebook SDK's requirement for one.
enum FacebookConfiguration {
	static let appID = "144876722233890"
	static let displayName = "Secret DJ"

	/// A real client token from Meta's App Dashboard (Settings → Advanced →
	/// Platform → iOS → Client Token) has never been issued for this app id,
	/// so this stays the literal placeholder below until one is filled in.
	/// ``isConfigured`` gates every place that placeholder would otherwise
	/// reach the SDK.
	static let clientToken = "MISSING-SEE-META-DASHBOARD"

	/// `false` while ``clientToken`` is still the placeholder. Facebook
	/// sign-in must degrade gracefully rather than crash: while this is
	/// `false`, the Facebook button doesn't render and the Facebook SDK is
	/// never initialized.
	static var isConfigured: Bool {
		clientToken != "MISSING-SEE-META-DASHBOARD"
	}
}
