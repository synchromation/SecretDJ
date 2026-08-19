import FacebookCore
import UIKit

/// The `UIApplicationDelegate` this otherwise-SwiftUI-lifecycle app needs
/// only for the Facebook SDK's two required hooks
/// (`secretdjv3/AppDelegate.swift`'s "initialises the Facebook SDK" /
/// `secretdjv3/SceneDelegate.swift`'s "forwards incoming URLs to the
/// Facebook SDK", rebuilt for `UIApplicationDelegateAdaptor`). Both no-op
/// while ``FacebookConfiguration/isConfigured`` is `false` — the SDK is
/// never initialized without a real client token.
final class AppDelegate: NSObject, UIApplicationDelegate {
	/// UIKit calls this directly at launch regardless of scene
	/// configuration, so it's where the SDK is initialized.
	func application(
		_ application: UIApplication,
		didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil,
	) -> Bool {
		guard FacebookConfiguration.isConfigured else {
			return true
		}

		return ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
	}

	/// This app is scene-based with no custom `UISceneDelegate`, so UIKit
	/// never calls this itself — `SecretDJApp`'s `onOpenURL` calls it
	/// explicitly, giving the Facebook SDK's SSO/Safari sign-in callback
	/// one place to land regardless of which lifecycle hook delivers it.
	func application(
		_ app: UIApplication,
		open url: URL,
		options: [UIApplication.OpenURLOptionsKey: Any] = [:],
	) -> Bool {
		guard FacebookConfiguration.isConfigured else {
			return false
		}

		return ApplicationDelegate.shared.application(app, open: url, options: options)
	}
}
