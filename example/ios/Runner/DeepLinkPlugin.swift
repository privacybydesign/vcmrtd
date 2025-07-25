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

// MARK: - Application Delegate Methods
extension DeepLinkPlugin {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Handle launch via URL scheme
        if let url = launchOptions?[.url] as? URL {
            handleURL(url)
        }
        return true
    }
    
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return handleURL(url)
    }
    
    // iOS 13+ Scene Delegate support
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Handle Universal Links
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            return handleURL(url)
        }
        return false
    }
}

// MARK: - Deep Link Processing
private extension DeepLinkPlugin {
    
    func handleURL(_ url: URL) -> Bool {
        let urlString = url.absoluteString
        
        guard isValidMrtdURL(url) else {
            NSLog("Invalid MRTD URL: \(urlString)")
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
    
    func isValidMrtdURL(_ url: URL) -> Bool {
        // Check scheme
        guard let scheme = url.scheme,
              (scheme == "mrtd" || scheme == "https") else {
            return false
        }
        
        // For MRTD scheme, check host
        if scheme == "mrtd" {
            guard url.host == "validate" else {
                return false
            }
        }
        
        // For HTTPS scheme, check domain and path
        if scheme == "https" {
            guard url.host == "mrtd.app",
                  url.path.hasPrefix("/validate") else {
                return false
            }
        }
        
        // Extract query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return false
        }
        
        // Check required parameters
        let requiredParams = ["sessionId", "nonce", "timestamp", "signature"]
        let paramDict = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })
        
        for param in requiredParams {
            guard let value = paramDict[param], !value.isEmpty else {
                return false
            }
        }
        
        // Validate sessionId format (UUID)
        guard let sessionId = paramDict["sessionId"],
              isValidUUID(sessionId) else {
            return false
        }
        
        // Validate timestamp format
        guard let timestampString = paramDict["timestamp"],
              let _ = Int64(timestampString) else {
            return false
        }
        
        // Basic nonce validation (should be Base64)
        guard let nonce = paramDict["nonce"],
              isValidBase64(nonce) else {
            return false
        }
        
        return true
    }
    
    func processDeepLink(url: String) -> Bool {
        guard let urlObj = URL(string: url) else {
            return false
        }
        
        guard isValidMrtdURL(urlObj) else {
            return false
        }
        
        // Log security event
        NSLog("Processing valid MRTD deep link: \(urlObj.host ?? "unknown")")
        
        // Additional security checks could be performed here
        // such as rate limiting, certificate validation, etc.
        
        return true
    }
    
    // MARK: - Validation Helpers
    
    func isValidUUID(_ uuid: String) -> Bool {
        let uuidRegex = "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$"
        let predicate = NSPredicate(format: "SELF MATCHES[c] %@", uuidRegex)
        return predicate.evaluate(with: uuid)
    }
    
    func isValidBase64(_ string: String) -> Bool {
        // Basic Base64 validation
        let base64Regex = "^[A-Za-z0-9+/]*={0,2}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", base64Regex)
        guard predicate.evaluate(with: string) else {
            return false
        }
        
        // Try to decode to verify it's valid Base64
        return Data(base64Encoded: string) != nil
    }
}