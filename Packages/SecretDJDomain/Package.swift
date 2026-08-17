// swift-tools-version: 6.2
import PackageDescription

let package = Package(
	name: "SecretDJDomain",
	platforms: [
		.iOS(.v26),
		.macOS(.v15),
		.visionOS(.v2),
	],
	products: [
		.library(name: "SecretDJDomain", targets: ["SecretDJDomain"]),
	],
	targets: [
		.target(name: "SecretDJDomain"),
		.testTarget(name: "SecretDJDomainTests", dependencies: ["SecretDJDomain"]),
	],
	swiftLanguageModes: [.v6],
)
