import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    
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
           (url.scheme == "https" && url.host == "mrtd.app") ||
           (url.scheme == "https" && url.host == "passport-issuer.staging.yivi.app") {
            // The plugin will handle this through its delegate methods
            return super.application(app, open: url, options: options)
        }
        
        return super.application(app, open: url, options: options)
    }
    
    // Handle Universal Links (https://mrtd.app/validate)
    override func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL,
           ((url.host == "mrtd.app" && url.path.hasPrefix("/validate")) ||
            (url.host == "passport-issuer.staging.yivi.app" && url.path.hasPrefix("/start-app"))) {
            // The plugin will handle this through its delegate methods
            return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
        }
        
        return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
}
