// swift-tools-version: 6.2
import PackageDescription

let package = Package(
	name: "SharedFeatures",
	platforms: [
		.iOS(.v26),
		.macOS(.v15),
		.visionOS(.v2),
	],
	products: [
		.library(name: "SharedFeatures", targets: ["SharedFeatures"]),
	],
	dependencies: [
		.package(path: "../SecretDJDomain"),
		.package(path: "../FeedUI"),
		.package(path: "../DesignSystem"),
	],
	targets: [
		.target(
			name: "SharedFeatures",
			dependencies: [
				"SecretDJDomain",
				"FeedUI",
				"DesignSystem",
			],
		),
		.testTarget(name: "SharedFeaturesTests", dependencies: ["SharedFeatures"]),
	],
	swiftLanguageModes: [.v6],
)
