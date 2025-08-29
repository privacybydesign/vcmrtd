import Flutter
import UIKit
import Foundation

/**
 * DeepLinkPlugin handles deep link processing for MRTD validation on iOS
 * Integrates with Flutter's MethodChannel for cross-platform communication
 */
@objc class DeepLinkPlugin: NSObject, FlutterPlugin {
    private static let channelName = "deep_link_handler"
    private static let methodGetInitialLink = "getInitialLink"
    private static let methodHandleDeepLink = "handleDeepLink"
    
    private var channel: FlutterMethodChannel?
    private var initialLink: String?
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = DeepLinkPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case DeepLinkPlugin.methodGetInitialLink:
            result(initialLink)
            initialLink = nil // Clear after first access
            
        case DeepLinkPlugin.methodHandleDeepLink:
            guard let url = call.arguments as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "URL is required", details: nil))
                return
            }
            let handled = processDeepLink(url: url)
            result(["success": handled])
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

extension DeepLinkPlugin {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Handle launch via URL scheme (custom schemes)
        if let url = launchOptions?[.url] as? URL {
            handleURL(url)
        }
        return true
    }
    
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return handleURL(url)
    }
    
    // iOS 13+ Scene Delegate support (Universal Links)
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            return handleURL(url)
        }
        return false
    }
}

private extension DeepLinkPlugin {
    
    func handleURL(_ url: URL) -> Bool {
        let urlString = url.absoluteString
        
        guard isValidURL(url) else {
            NSLog("Invalid URL: \(urlString)")
            return false
        }
        
        // If Flutter is ready, send immediately
        if let channel = channel {
            channel.invokeMethod(DeepLinkPlugin.methodHandleDeepLink, arguments: urlString)
        } else {
            // Store for later retrieval
            initialLink = urlString
        }
        
        return true
    }
    
    func isValidURL(_ url: URL) -> Bool {
        // Require HTTPS
        guard url.scheme == "https" else { return false }
        
        // Require host/path to match start-app endpoint
        let host = url.host ?? ""
        let path = url.path
        guard host == "passport-issuer.staging.yivi.app",
              path.hasPrefix("/start-app") else { return false }
        
        // Extract query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else { return false }
        
        var params: [String: String] = [:]
        for item in queryItems {
            if let value = item.value { params[item.name] = value }
        }
        
        // Validate required params
        guard let sessionId = params["sessionId"], isValidSessionId(sessionId),
              let nonce = params["nonce"], isValidNonce(nonce) else { return false }
        
        return true
    }
    
    func processDeepLink(url: String) -> Bool {
        guard let urlObj = URL(string: url) else { return false }
        guard isValidURL(urlObj) else { return false }
        
        // Log security event
        NSLog("Processing valid MRTD deep link: \(urlObj.host ?? "unknown")")
        return true
    }
    
    // MARK: - Validation Helpers
    
    /// 32-char alphanumeric (not a UUID)
    func isValidSessionId(_ sessionId: String) -> Bool {
        return sessionId.range(of: "^[A-Za-z0-9]{32}$", options: .regularExpression) != nil
    }
    
    /// 16-char hexadecimal
    func isValidNonce(_ nonce: String) -> Bool {
        return nonce.range(of: "^[0-9a-fA-F]{16}$", options: .regularExpression) != nil
    }
}
