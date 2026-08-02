// swift-tools-version: 6.2
import PackageDescription

let package = Package(
	name: "Observability",
	platforms: [
		.iOS(.v18),
		.macOS(.v15),
		.visionOS(.v2),
	],
	products: [
		.library(name: "Observability", targets: ["Observability"]),
		.library(name: "ObservabilitySentry", targets: ["ObservabilitySentry"]),
		.library(name: "ObservabilityTelemetryDeck", targets: ["ObservabilityTelemetryDeck"]),
	],
	dependencies: [
		.package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.0.0"),
		.package(url: "https://github.com/TelemetryDeck/SwiftSDK", from: "2.0.0"),
	],
	targets: [
		.target(name: "Observability"),
		.target(
			name: "ObservabilitySentry",
			dependencies: [
				"Observability",
				.product(name: "Sentry", package: "sentry-cocoa"),
			],
		),
		.target(
			name: "ObservabilityTelemetryDeck",
			dependencies: [
				"Observability",
				.product(name: "TelemetryDeck", package: "SwiftSDK"),
			],
		),
		.testTarget(name: "ObservabilityTests", dependencies: ["Observability"]),
	],
	swiftLanguageModes: [.v6],
)
