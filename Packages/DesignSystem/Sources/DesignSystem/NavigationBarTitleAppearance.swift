#if canImport(UIKit)
	import UIKit

	extension Theme {
		/// Legacy's bold 24pt navigation-bar title, ported as a
		/// `UINavigationBarAppearance` proxy since SwiftUI has no first-class
		/// title-font modifier on iOS (see below).
		///
		/// ### Legacy provenance
		/// `secretdjv3/AppDelegate.swift:24-31` is the shipped title styling:
		/// an iOS-15+ `UINavigationBarAppearance` (guarded by `#available(iOS
		/// 15, *)`, added for "bug #90 View title text is corrupted on Sign
		/// up IOS 15") setting `titleTextAttributes` to `"Helvetica Neue
		/// Bold"` 24pt in `AppColors.navigationTitleText` — every currently
		/// supported OS version runs this path, not the older pre-iOS-15
		/// fallback at `:84-87` (`FontConfig.light` 20pt), so 24pt Bold is
		/// the target here; do not "fix" it back down to 20. The color is
		/// exactly ``Theme/ColorRole/primaryText``'s own dark value (0.831
		/// white — `ColorRole`'s doc comment already records this same
		/// provenance), reused here rather than a second hardcoded literal.
		///
		/// `secretdjv3/KioskAppDelegate.swift:78-81` never gained the same
		/// iOS-15 branch: its `application(didFinishLaunchingWithOptions:)`
		/// (`:16-22`) calls straight into `setupApplication`, which only ever
		/// sets the legacy `UINavigationBar.appearance()` proxy at
		/// `FontConfig.light` 20pt. So, unlike every other design token
		/// (`ColorRole`, `TextStyle`, ``View/themedScreen(_:)``), the two
		/// legacy apps' title styling actually diverged — the kiosk simply
		/// never received the consumer app's own bug-#90 fix. Both apps
		/// call ``apply()`` here, deliberately unifying them on the
		/// consumer app's corrected appearance rather than reproducing an
		/// unfixed kiosk regression.
		///
		/// ### Why an appearance proxy, not a SwiftUI modifier
		/// Checked against the iOS 26 SDK's `SwiftUI.swiftinterface`:
		/// `SwiftUI.View.navigationTitle(_:)` has exactly one overload that
		/// would let a title carry its own `.font` —
		/// `navigationTitle<V>(@ViewBuilder _ title: () -> V)` — but it's
		/// `@available(iOS, unavailable)` (watchOS/other-platform only), so
		/// no first-class route exists on iOS as of this SDK.
		/// `UINavigationBarAppearance` is the same mechanism legacy itself
		/// used.
		///
		/// ### Dynamic Type
		/// Legacy's 24pt was a fixed literal; ``scaledTitleFont(forContentSizeCategory:)``
		/// scales it via `UIFontMetrics(forTextStyle: .title2)` — the
		/// closest built-in scaling curve to a custom 24pt base (`.title2`'s
		/// own default is 22pt, not an exact match; `.title3` is 20,
		/// `.title1` is 28 — `.title2` is nearest). This is the same
		/// "no exact semantic style matches, anchor to the nearest one"
		/// escape hatch `Theme.TextStyle`'s own doc comment already
		/// documents for `PersonRowCell`'s 14pt labels. `UIFontMetrics
		/// .scaledFont(for:)` doesn't require its input to already equal the
		/// anchor style's own base size — it treats whatever size is passed
		/// as that style's size at the default ("Large") category and scales
		/// every other category relative to it, so anchoring on `.title2`
		/// here still scales our own 24pt base proportionately; the 22-vs-24
		/// mismatch doesn't distort it.
		///
		/// `UIFontMetrics`-scaled fonts don't auto-update the way SwiftUI's
		/// own `Font.system` does — call ``apply()`` again (``observeContentSizeCategoryChanges()``
		/// does this automatically) whenever the size category changes.
		@MainActor
		public enum NavigationBarTitleAppearance {
			/// Builds the current appearance and applies it to
			/// `UINavigationBar.appearance()` (every bar created from this
			/// point on) and to every navigation bar already mounted in a
			/// connected scene. The `.appearance()` proxy only affects
			/// *future* instances — an in-flight Dynamic Type change needs an
			/// already-visible bar's own `standardAppearance`/
			/// `scrollEdgeAppearance`/`compactAppearance` reassigned directly
			/// to redraw without a relaunch.
			public static func apply() {
				let appearance = makeAppearance()

				UINavigationBar.appearance().standardAppearance = appearance
				UINavigationBar.appearance().scrollEdgeAppearance = appearance
				UINavigationBar.appearance().compactAppearance = appearance

				for navigationController in allNavigationControllers() {
					navigationController.navigationBar.standardAppearance = appearance
					navigationController.navigationBar.scrollEdgeAppearance = appearance
					navigationController.navigationBar.compactAppearance = appearance
					navigationController.navigationBar.setNeedsLayout()
				}
			}

			/// Starts observing `UIContentSizeCategory.didChangeNotification`
			/// and reapplying ``apply()`` on every change. Call once, from
			/// each app root's `init()`, right alongside the initial
			/// ``apply()`` call — and retain the returned token for the
			/// app's lifetime, or `NotificationCenter` drops the observation
			/// as soon as it deallocates.
			@MainActor
			public static func observeContentSizeCategoryChanges() -> NSObjectProtocol {
				NotificationCenter.default.addObserver(
					forName: UIContentSizeCategory.didChangeNotification,
					object: nil,
					queue: .main,
				) { _ in
					Task { @MainActor in apply() }
				}
			}

			static func makeAppearance() -> UINavigationBarAppearance {
				// No `configureWith...Background()` call: those only touch
				// `backgroundColor`/`backgroundEffect`/`shadowColor` — this
				// proxy sets title attributes only, exactly per the "compose
				// with `themedScreen`'s own bar background" requirement, so
				// `themedScreen`'s `.toolbarBackground` keeps owning the bar's
				// fill and shadow untouched.
				let appearance = UINavigationBarAppearance()

				let attributes: [NSAttributedString.Key: Any] = [
					.foregroundColor: Theme.ColorRole.primaryText.token.uiColor,
					.font: scaledTitleFont(),
				]
				appearance.titleTextAttributes = attributes
				// Legacy predates large titles entirely — it has no distinct
				// large-title style to port, so every screen gets the same
				// 24pt-anchored title regardless of which display mode it
				// happens to use.
				appearance.largeTitleTextAttributes = attributes

				return appearance
			}

			/// The scaled title font for `category` (the current system
			/// category when `nil`). Exposed for testing — deterministic for
			/// a given category, so it's the one piece of this file that's
			/// pure enough to unit test without standing up real navigation
			/// bars. `nonisolated`, unlike the rest of this enum: it touches
			/// no shared UIKit state (`UIFont`/`UIFontMetrics` values only),
			/// so a test can call it directly with no `MainActor` hop.
			public nonisolated static func scaledTitleFont(forContentSizeCategory category: UIContentSizeCategory? =
				nil)
				-> UIFont
			{
				let base = UIFont.systemFont(ofSize: 24, weight: .bold)
				let metrics = UIFontMetrics(forTextStyle: .title2)

				guard let category else {
					return metrics.scaledFont(for: base)
				}

				return metrics.scaledFont(
					for: base,
					compatibleWith: UITraitCollection(preferredContentSizeCategory: category),
				)
			}

			private static func allNavigationControllers() -> [UINavigationController] {
				let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
				let roots = windowScenes.flatMap(\.windows).compactMap(\.rootViewController)
				return roots.flatMap(navigationControllers(in:))
			}

			/// Walks `viewController`'s children and presented controller
			/// looking for `UINavigationController`s — public API only
			/// (`children`/`presentedViewController`), no reach into
			/// SwiftUI's own private hosting types, since a `NavigationStack`
			/// still ultimately mounts a real `UINavigationController`
			/// somewhere in that public tree.
			private static func navigationControllers(in viewController: UIViewController) -> [UINavigationController] {
				var result: [UINavigationController] = []
				if let navigationController = viewController as? UINavigationController {
					result.append(navigationController)
				}
				for child in viewController.children {
					result.append(contentsOf: navigationControllers(in: child))
				}
				if let presented = viewController.presentedViewController {
					result.append(contentsOf: navigationControllers(in: presented))
				}
				return result
			}
		}
	}
#endif
