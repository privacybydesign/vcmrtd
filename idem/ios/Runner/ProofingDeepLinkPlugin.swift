import Flutter
import UIKit

/**
 * Forwards a tapped vcmrtd:// identity-proofing deep link to Dart. Kept
 * separate from DeepLinkPlugin, which only accepts an https URL carrying
 * sessionId/nonce for the unrelated passport-issuer.yivi.app flow and would
 * reject this shape outright (see identity-proofing-service's deepLink() in
 * backend/internal/api/sessions.go — "vcmrtd://verify?token=...&api=...").
 */
@objc class ProofingDeepLinkPlugin: NSObject, FlutterPlugin {
    private static let channelName = "proofing_deeplink"

    private var channel: FlutterMethodChannel?
    private var initialLink: String?

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = ProofingDeepLinkPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
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
        guard url.scheme == "vcmrtd" else { return false }
        if let channel = channel {
            channel.invokeMethod("onLink", arguments: url.absoluteString)
        } else {
            initialLink = url.absoluteString
        }
        return true
    }
}
