import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private static var passportIssuerHost: String {
        Bundle.main.object(forInfoDictionaryKey: "DeepLinkPassportIssuerHost") as? String ?? ""
    }
    private static var mrtdAppHost: String {
        Bundle.main.object(forInfoDictionaryKey: "DeepLinkMrtdAppHost") as? String ?? ""
    }
    private static var mrtdValidatePath: String {
        Bundle.main.object(forInfoDictionaryKey: "DeepLinkMrtdValidatePath") as? String ?? ""
    }
    private static var passportIssuerStartPath: String {
        Bundle.main.object(forInfoDictionaryKey: "DeepLinkPassportIssuerStartPath") as? String ?? ""
    }

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Register deep link plugin
        guard let controller = window?.rootViewController as? FlutterViewController else {
            fatalError("Root controller is not FlutterViewController")
        }

        DeepLinkPlugin.register(with: registrar(forPlugin: "DeepLinkPlugin")!)

        // Register image_channel for JP2 passport photo decoding (UIImage handles JPEG 2000 natively)
        ImageDecodeChannel.register(with: registrar(forPlugin: "ImageDecodeChannel")!)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // Handle URL schemes (mrtd://)
    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // Let the deep link plugin handle first
        if url.scheme == "mrtd" ||
           (url.scheme == "https" && url.host == AppDelegate.mrtdAppHost) ||
           (url.scheme == "https" && url.host == AppDelegate.passportIssuerHost) {
            // The plugin will handle this through its delegate methods
            return super.application(app, open: url, options: options)
        }
        
        return super.application(app, open: url, options: options)
    }
    
    // Handle Universal Links.
    override func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL,
           ((!AppDelegate.mrtdAppHost.isEmpty &&
             !AppDelegate.mrtdValidatePath.isEmpty &&
             url.host == AppDelegate.mrtdAppHost &&
             url.path.hasPrefix(AppDelegate.mrtdValidatePath)) ||
            (!AppDelegate.passportIssuerHost.isEmpty &&
             !AppDelegate.passportIssuerStartPath.isEmpty &&
             url.host == AppDelegate.passportIssuerHost &&
             url.path.hasPrefix(AppDelegate.passportIssuerStartPath))) {
            // The plugin will handle this through its delegate methods
            return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
        }
        
        return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
}
