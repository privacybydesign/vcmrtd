import Flutter
import UIKit
import FaceTecSDK

@main
@objc class AppDelegate: FlutterAppDelegate, FaceTecInitializeCallback, FaceTecSessionRequestProcessor, URLSessionDelegate {

    // FaceTec properties
    private var requestCallback: FaceTecSessionRequestProcessorCallback!
    var latestExternalDatabaseRefID: String = ""
    var faceTecSDKInstance: FaceTecSDKInstance?
    var flutterEngine: FlutterEngine?
    var processorChannel: FlutterMethodChannel?
    var controller: FlutterViewController?
    private var flutterInitializeResultCallback: FlutterResult?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Register deep link plugin
        guard let controller = window?.rootViewController as? FlutterViewController else {
            fatalError("Root controller is not FlutterViewController")
        }

        self.controller = controller

        DeepLinkPlugin.register(with: registrar(forPlugin: "DeepLinkPlugin")!)

        // Setup FaceTec channels
        let faceTecSDKChannel = FlutterMethodChannel(name: "com.facetec.sdk", binaryMessenger: controller.binaryMessenger)
        self.processorChannel = FlutterMethodChannel(name: "com.facetec.sdk/livenesscheck", binaryMessenger: controller.binaryMessenger)

        faceTecSDKChannel.setMethodCallHandler(receivedFaceTecSDKMethodCall(call:result:))
        self.processorChannel!.setMethodCallHandler(receivedLivenessCheckProcessorCall(call:result:))

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

    // ============ FaceTec SDK Methods ============

    private func receivedFaceTecSDKMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void {
        switch(call.method) {
        case "initialize":
            guard let args = call.arguments as? Dictionary<String, Any>,
                  let deviceKeyIdentifier = args["deviceKeyIdentifier"] as? String,
                  let faceScanEncryptionKey = args["publicFaceScanEncryptionKey"] as? String
            else {
                return result(FlutterError(code: "InvalidArguments", message: "Missing arguments", details: nil))
            }
            return initialize(deviceKey: deviceKeyIdentifier, publicFaceScanEncryptionKey: faceScanEncryptionKey, result: result)
        case "startLivenessCheck":
            return startLivenessCheck(result: result)
        case "createAPIUserAgentString":
            let data = FaceTec.sdk.getTestingAPIHeader()
            result(data)
        default:
            result(FlutterMethodNotImplemented)
            return
        }
    }

    private func receivedLivenessCheckProcessorCall(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void {
        switch(call.method) {
        case "onResponseBlobReceived":
            let args = call.arguments as? Dictionary<String, Any> ?? nil
            let responseBlob = args?["responseBlob"] as? String ?? ""
            return onResponseBlobReceived(responseBlob: responseBlob)
        case "onUploadProgress":
            let args = call.arguments as? Dictionary<String, Any> ?? nil
            let progress = args?["progress"] as? Float ?? 0
            return onUploadProgress(progress: progress)
        case "onCatastrophicNetworkError":
            return self.onCatastrophicNetworkError()
        default:
            result(FlutterMethodNotImplemented)
            return
        }
    }

    func initialize(deviceKey: String, publicFaceScanEncryptionKey: String, result: @escaping FlutterResult) {
        let ftCustomization = FaceTecCustomization()
        // ftCustomization.overlayCustomization.brandingImage = UIImage(named: "flutter_logo")  // Optional: add your branding image
        FaceTec.sdk.setCustomization(ftCustomization)

        self.flutterInitializeResultCallback = result
        FaceTec.sdk.initializeWithSessionRequest(deviceKeyIdentifier: deviceKey, sessionRequestProcessor: self, completion: self)
    }

    // FaceTecInitializeCallback required method
    func onFaceTecSDKInitializeSuccess(sdkInstance: FaceTecSDKInstance) {
        self.faceTecSDKInstance = sdkInstance
        self.flutterInitializeResultCallback!(true)
        self.flutterInitializeResultCallback = nil
        print("FaceTec SDK Initialized Successfully.")
    }

    // FaceTecInitializeCallback required method
    func onFaceTecSDKInitializeError(error: FaceTecInitializationError) {
        self.flutterInitializeResultCallback!(FlutterError(code: "InitError", message: "There was an issue initializing the FaceTec SDK: \(error)", details: nil))
        self.flutterInitializeResultCallback = nil
        print("Error Initializing FaceTec SDK: \(error)")
    }

    private func startLivenessCheck(result: @escaping FlutterResult) {
        guard let faceTecSDKInstance = self.faceTecSDKInstance else {
            result(FlutterError(code: "NotInitialized", message: "FaceTec SDK not initialized", details: nil))
            return
        }

        let livenessCheckViewController = faceTecSDKInstance.start3DLiveness(with: self)
        self.controller?.present(livenessCheckViewController, animated: true, completion: nil)
        result(true)
    }

    // FaceTecSessionRequestProcessor Implementation

    func onSessionRequest(sessionRequestBlob: String, sessionRequestCallback: any FaceTecSessionRequestProcessorCallback) {
        self.requestCallback = sessionRequestCallback

        let args = [
            "sessionRequestBlob": sessionRequestBlob,
            "externalDatabaseRefID": self.latestExternalDatabaseRefID,
            "userAgentString": FaceTec.sdk.getTestingAPIHeader()
        ] as [String: Any]

        DispatchQueue.main.async {
            self.processorChannel?.invokeMethod("processSession", arguments: args)
        }
    }

    func onFaceTecExit(sessionResult: FaceTecSessionResult) {
        DispatchQueue.main.async {
            self.onComplete(sessionResult.sessionStatus)
        }
    }

    func onComplete(_ status: FaceTecSessionStatus) {
        print("Session Status: " + AppDelegate.getSessionStatusString(status))

        let successful = status == FaceTecSessionStatus.sessionCompleted
        if (!successful) {
            self.latestExternalDatabaseRefID = ""
        }

        print("FaceTecSDK completely done")
    }

    func onResponseBlobReceived(responseBlob: String) {
        requestCallback.processResponse(responseBlob)
    }

    func onUploadProgress(progress: Float) {
        requestCallback.updateProgress(progress)
    }

    func onCatastrophicNetworkError() {
        requestCallback.abortOnCatastrophicError()
        self.requestCallback = nil
    }

    private static func getSessionStatusString(_ status: FaceTecSessionStatus) -> String {
        switch(status) {
        case .sessionCompleted:
            return "Session was completed."
        case .requestAborted:
            return "A request was aborted."
        case .cameraPermissionsDenied:
            return "Camera is required but access prevented by user settings or administrator policy."
        case .userCancelledFaceScan:
            return "User cancelled before completing Face Scan session."
        case .userCancelledIDScan:
            return "User cancelled before completing ID Scan session."
        case .lockedOut:
            return "FaceTec SDK is in a lockout state."
        case .cameraError:
            return "Session cancelled due to a camera error."
        case .unknownInternalError:
            return "Session failed because an unknown or unexpected error occurred."
        }
    }
}
