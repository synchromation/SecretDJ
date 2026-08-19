import Foundation

/// The About/Legal section's external links (S6.11). ``termsOfService``
/// ports the one legacy reference LEGACY.md catalogued
/// (`secretdjv3/AvailableTopUpsViewController.swift`'s "Terms & Conditions"
/// row, `http://www.secretdj.com/terms-conditions/` — upgraded to `https`
/// here since ATS is on with no arbitrary loads, S0.6); no legacy privacy
/// policy URL was ever catalogued, so ``privacyPolicy`` is a placeholder on
/// the same domain.
///
/// // TODO(S9.2): both URLs are placeholders for the product owner to
/// confirm and finalize as part of store-asset readiness (PLAN.md S9.2) —
/// do not treat either as production-correct until then.
enum SettingsLegalLinks {
	static let termsOfService = url("https://www.secretdj.com/terms-conditions/")
	static let privacyPolicy = url("https://www.secretdj.com/privacy-policy/")

	/// Never force-unwrapped (skills: never force-unwrap) — both literals
	/// above are well-formed, so the fallback never actually triggers.
	private static func url(_ string: String) -> URL {
		URL(string: string) ?? URL(fileURLWithPath: "/")
	}
}
