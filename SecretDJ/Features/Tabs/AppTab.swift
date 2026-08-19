/// The signed-in app's three root tabs (LEGACY.md "Launch and root
/// navigation" — `TabBarConfigurationProvider`'s Places Nearby / Activity
/// feed / Profile; the legacy News tab was dead code, dropped here).
enum AppTab: CaseIterable, Hashable {
	case placesNearby
	case activity
	case profile
}
