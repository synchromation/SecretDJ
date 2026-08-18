@testable import SecretDJAPI

struct FakeImplicitParameterProvider: ImplicitParameterProviding {
	var location: APICoordinate?
	var installedApps: InstalledAppsMask
	var preferredLanguage: String

	init(
		location: APICoordinate? = nil,
		installedApps: InstalledAppsMask = [],
		preferredLanguage: String = "en",
	) {
		self.location = location
		self.installedApps = installedApps
		self.preferredLanguage = preferredLanguage
	}
}
