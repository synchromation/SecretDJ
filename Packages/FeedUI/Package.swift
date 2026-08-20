// swift-tools-version: 6.2
import PackageDescription

let package = Package(
	name: "FeedUI",
	platforms: [
		.iOS(.v26),
		.macOS(.v15),
		.visionOS(.v2),
	],
	products: [
		.library(name: "FeedUI", targets: ["FeedUI"]),
	],
	dependencies: [
		.package(path: "../SecretDJDomain"),
		.package(path: "../DesignSystem"),
		.package(path: "../Observability"),
	],
	targets: [
		.target(name: "FeedUI", dependencies: ["SecretDJDomain", "DesignSystem", "Observability"]),
		.testTarget(name: "FeedUITests", dependencies: ["FeedUI", "Observability"]),
	],
	swiftLanguageModes: [.v6],
)
