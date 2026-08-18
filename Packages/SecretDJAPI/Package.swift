// swift-tools-version: 6.2
import PackageDescription

let package = Package(
	name: "SecretDJAPI",
	platforms: [
		.iOS(.v26),
		.macOS(.v15),
		.visionOS(.v2),
	],
	products: [
		.library(name: "SecretDJAPI", targets: ["SecretDJAPI"]),
	],
	dependencies: [
		.package(path: "../SecretDJDomain"),
	],
	targets: [
		.target(name: "SecretDJAPI", dependencies: ["SecretDJDomain"]),
		.testTarget(
			name: "SecretDJAPITests",
			dependencies: ["SecretDJAPI"],
			resources: [.copy("Resources")],
		),
	],
	swiftLanguageModes: [.v6],
)
