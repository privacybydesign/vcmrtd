import Flutter
import UIKit

/**
 * Forwards a tapped vcmrtd:// identity-proofing deep link, or its https
 * Universal Link form (https://idem.yivi.app/verify?handover=...&api=...), to Dart. Kept
 * separate from DeepLinkPlugin, which only accepts an https URL carrying
 * sessionId/nonce for the unrelated passport-issuer.yivi.app flow and would
 * reject this shape outright (see identity-proofing-service's deepLink() in
 * backend/internal/api/sessions.go — "vcmrtd://verify?token=...&api=...").
 */
@objc class ProofingDeepLinkPlugin: NSObject, FlutterPlugin {
    private static let channelName = "proofing_deeplink"

    // The https Universal Link form of the vcmrtd:// link (Runner.entitlements).
    private static let universalLinkHost = "idem.yivi.app"
    private static let universalLinkPath = "/verify"

    /// A vcmrtd:// link, or the https Universal Link on idem.yivi.app/verify.
    static func isProofingLink(_ url: URL) -> Bool {
        if url.scheme == "vcmrtd" { return true }
        return url.scheme == "https" && url.host == universalLinkHost && url.path == universalLinkPath
    }

    /// The https link a Universal Link activity carries, when it is a proofing link.
    static func proofingLink(in activity: NSUserActivity) -> URL? {
        guard activity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = activity.webpageURL, isProofingLink(url) else { return nil }
        return url
    }

    private var channel: FlutterMethodChannel?
    private var initialLink: String?

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = ProofingDeepLinkPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        // See DeepLinkPlugin.register for why both are registered.
        registrar.addApplicationDelegate(instance)
        registrar.addSceneDelegate(instance)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getInitialLink":
            result(initialLink)
            initialLink = nil // only ever answered once per cold start

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

extension ProofingDeepLinkPlugin {

    /// Cold start via a vcmrtd:// link: stash it for Dart's first
    /// getInitialLink call, since Flutter isn't ready to receive a method
    /// channel invocation yet at this point.
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if let url = launchOptions?[.url] as? URL, url.scheme == "vcmrtd" {
            initialLink = url.absoluteString
        }
        return true
    }

    /// The app was already running when the link was tapped.
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return forward(url)
    }

    /// A tapped Universal Link, on a cold or a warm start.
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard let url = ProofingDeepLinkPlugin.proofingLink(in: userActivity) else { return false }
        return forward(url)
    }

    private func forward(_ url: URL) -> Bool {
        guard ProofingDeepLinkPlugin.isProofingLink(url) else { return false }
        if let channel = channel {
            channel.invokeMethod("onLink", arguments: url.absoluteString)
        } else {
            initialLink = url.absoluteString
        }
        return true
    }
}

/// UIScene life cycle equivalents of the UIApplication callbacks above. Flutter hands
/// these to plugins in registration order until one returns true, so only proofing
/// links (vcmrtd:// and the idem.yivi.app Universal Link) are claimed.
extension ProofingDeepLinkPlugin: FlutterSceneLifeCycleDelegate {

    /// Cold start: the launch URL (or Universal Link activity) rides in on the scene
    /// connection rather than in launchOptions. Stashed for getInitialLink, as in
    /// didFinishLaunchingWithOptions.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions?) -> Bool {
        let schemeLink = connectionOptions?.urlContexts.first(where: { $0.url.scheme == "vcmrtd" })?.url
        let universalLink = connectionOptions?.userActivities.lazy.compactMap(ProofingDeepLinkPlugin.proofingLink(in:)).first
        guard let url = schemeLink ?? universalLink else { return false }
        initialLink = url.absoluteString
        return true
    }

    /// The app was already running when the link was tapped.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
        guard let url = URLContexts.first(where: { $0.url.scheme == "vcmrtd" })?.url else { return false }
        return forward(url)
    }

    /// A tapped Universal Link while the app was already running.
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) -> Bool {
        guard let url = ProofingDeepLinkPlugin.proofingLink(in: userActivity) else { return false }
        return forward(url)
    }
}
