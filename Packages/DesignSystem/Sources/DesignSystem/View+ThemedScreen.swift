import SwiftUI

extension View {
	/// The one screen-level surface treatment every screen in both apps
	/// applies (S9.5 — "make the rewrite actually look like legacy"):
	/// paints `background` edge-to-edge, clears the system material a
	/// `List`/`Form`'s own scroll content would otherwise paint on top of
	/// it, and carries that same fill up into the navigation bar so a
	/// pushed/presented screen never flashes system chrome around this
	/// app's own dark-first canvas. `role` defaults to
	/// ``Theme/ColorRole/background``; a screen built on a grouped surface
	/// (mirroring `Theme.ColorRole.secondaryBackground`'s own doc comment)
	/// passes that role instead so its bar matches.
	///
	/// This replaces every screen's own ad hoc `.background(Theme.ColorRole
	/// .background.color)` — the fill was already there, but nothing also
	/// cleared a List's own system background or matched the bar behind it,
	/// so a themed screen still showed a stock nav bar. The tab bar itself
	/// isn't covered here: only one screen (`TabsView`) ever hosts a
	/// `TabView`, so it themes `.tabBar` directly rather than every screen
	/// carrying a modifier that's a no-op everywhere else.
	public func themedScreen(_ role: Theme.ColorRole = .background) -> some View {
		// `ToolbarPlacement.navigationBar` is `@available(macOS, unavailable)`
		// — this package also builds for macOS (its own `Package.swift`
		// platform list), even though only the iOS apps ever mount this
		// modifier, so the bar-theming half is iOS/visionOS-only at compile
		// time; every platform still gets the background/scroll-material half.
		#if os(iOS) || os(visionOS)
			background(role.color)
				.scrollContentBackground(.hidden)
				.toolbarBackground(role.color, for: .navigationBar)
				.toolbarBackground(.visible, for: .navigationBar)
		#else
			background(role.color)
				.scrollContentBackground(.hidden)
		#endif
	}

	/// The tab bar's own half of the same treatment — split out from
	/// ``themedScreen(_:)`` because only one screen in either app
	/// (`TabsView`) ever hosts a `TabView`; a `.tabBar` call on every other
	/// screen would just be a no-op. Same macOS caveat as ``themedScreen(_:)``.
	public func themedTabBar(_ role: Theme.ColorRole = .background) -> some View {
		#if os(iOS) || os(visionOS)
			toolbarBackground(role.color, for: .tabBar)
				.toolbarBackground(.visible, for: .tabBar)
		#else
			self
		#endif
	}
}
