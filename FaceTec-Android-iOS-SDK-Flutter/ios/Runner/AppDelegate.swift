import UIKit
import Flutter
import FaceTecSDK

@main
@objc class AppDelegate: FlutterAppDelegate, FaceTecInitializeCallback, FaceTecSessionRequestProcessor, URLSessionDelegate {
    //
    // AppDelegate acts as the ViewController for the FaceTec session and implements the Session Request Processor class.
    //
    // Save the FaceTec SDK request callback so it can be accessed in the 3 helper methods
    private var requestCallback: FaceTecSessionRequestProcessorCallback!
    var latestExternalDatabaseRefID: String = ""
    var faceTecSDKInstance: FaceTecSDKInstance?
    var flutterEngine: FlutterEngine?
    var processorChannel: FlutterMethodChannel?
    var controller: FlutterViewController?
    private var flutterInitializeResultCallback: FlutterResult?
    
    override init() {
        super.init()
    }
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        self.controller = window?.rootViewController as? FlutterViewController
        
        // Application() creates processor channels for commmunicating with main.dart and LivenessCheckProcessor.dart.
        // Other processors you may create will be instantiated through another method channel.
        let faceTecSDKChannel = FlutterMethodChannel(name: "com.facetec.sdk", binaryMessenger: self.controller!.binaryMessenger)
        self.processorChannel = FlutterMethodChannel(name: "com.facetec.sdk/livenesscheck", binaryMessenger: self.controller!.binaryMessenger)
        
        faceTecSDKChannel.setMethodCallHandler(receivedFaceTecSDKMethodCall(call:result:))
        self.processorChannel!.setMethodCallHandler(receivedLivenessCheckProcessorCall(call:result:))

        GeneratedPluginRegistrant.register(with: self)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func receivedFaceTecSDKMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void {
        // Used to handle calls received over the "com.facetec.sdk" channel.
        // Currently two methods are implemented: initialize and startLivenessCheck.
        // When you make a call in main.dart or another file linked to the "com.facetec.sdk"
        // method channel, it will be received here and you will need to add logic for handling
        // that request.
        switch(call.method) {
        case "initialize":
            guard let args = call.arguments as? Dictionary<String, Any>,
                  let deviceKeyIdentifier = args["deviceKeyIdentifier"] as? String,
                  let faceScanEncryptionKey = args["publicFaceScanEncryptionKey"] as? String
            else {
                return result(FlutterError())
            }
            return initialize(deviceKey: deviceKeyIdentifier, publicFaceScanEncryptionKey: faceScanEncryptionKey, result: result)
        case "startLivenessCheck":
            return startLivenessCheck(result: result);
        case "createAPIUserAgentString":
            let data = FaceTec.sdk.getTestingAPIHeader()
            result(data)
        default:
            result(FlutterMethodNotImplemented)
            return
        }
    }

    private func receivedLivenessCheckProcessorCall(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void {
        // Used to handle calls received over "com.facetec.sdk/livenesscheck".
        // Currently there is only one method needed, but your processor code may require
        // more communication between dart and native code. If so, you may want to implement
        // any processor code and then receive the results and handle updating logic or run code on completion here.
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
            result(FlutterMethodNotImplemented);
            return;
        }
    }

    func initialize(deviceKey: String, publicFaceScanEncryptionKey: String, result: @escaping FlutterResult) {
        let ftCustomization = FaceTecCustomization()
        ftCustomization.overlayCustomization.brandingImage = UIImage(named: "flutter_logo")
        FaceTec.sdk.setCustomization(ftCustomization)
        
        // Initialize FaceTec SDK
        // By registering self as the completion FaceTecInitializeCallback,
        // You receive control over the UI in the event of successful initialization in onFaceTecSDKInitializeSuccess and
        // in the event of an error in onFaceTecSDKInitializeError
        self.flutterInitializeResultCallback = result
        FaceTec.sdk.initializeWithSessionRequest(deviceKeyIdentifier: deviceKey, sessionRequestProcessor: self, completion: self)
    }

    // FaceTecInitializeCallback required method
    func onFaceTecSDKInitializeSuccess(sdkInstance: FaceTecSDKInstance) {
        self.faceTecSDKInstance = sdkInstance
        self.flutterInitializeResultCallback!(true)
        self.flutterInitializeResultCallback = nil
        print("Initialized Successfully.")
    }
    
    // FaceTecInitializeCallback required method
    func onFaceTecSDKInitializeError(error: FaceTecInitializationError) {
        // Displays the FaceTec SDK Status to text field if init failed
        self.flutterInitializeResultCallback!(FlutterError(code: "InitError", message: "There was an issue initializing the FaceTec SDK", details: nil))
        self.flutterInitializeResultCallback = nil
        print("Error Initializing FaceTec SDK.")
        print(error)
    }
    
    // Initiate a 3D Liveness Check.
    private func startLivenessCheck(result: @escaping FlutterResult) {
        // This is where the FaceTec View Controller is actually called.
        // It will open the FaceTec interface and start the liveness check process. If you want to implement multiple processors,
        // you would need to keep track of which method was called to instantiate the session (in this case, startLivenessCheck)
        // and having branching logic in the implicitly called methods to handle multiple processors.
        let livenessCheckViewController = faceTecSDKInstance!.start3DLiveness(with: self)

        self.controller?.present(livenessCheckViewController, animated: true, completion: nil)
    }
    
    // When the FaceTec SDK is completely done, you receive control back here.
    // Since you have already handled all results in your Processor code, how you proceed here is up to you and how your App works.
    // In general, there was either a Success, or there was some other case where you cancelled out.
    func onComplete(_ status: FaceTecSessionStatus) {
        print("Session Status: " + AppDelegate.getSessionStatusString(status))
        
        print("See logs for more details.")
        
        let successful = status == FaceTecSessionStatus.sessionCompleted
        if (!successful) {
            // Reset the enrollment identifier.
            self.latestExternalDatabaseRefID = "";
        }
        
        print("FaceTecSDK completely done");
    }
    
    // FaceTecSessionRequestProcessor Implementation
    
    // This method gets called from inside the FaceTecSDK when some server side process is needed to continue processing
    func onSessionRequest(sessionRequestBlob: String, sessionRequestCallback: any FaceTecSessionRequestProcessorCallback) {
        // This callback will be called outside the scope of this method, when the scan is received via method channel from Flutter.
        self.requestCallback = sessionRequestCallback
        
        // Ready arguments to be sent from native code in iOS to Dart files accessed by Flutter.
        let args = [
            "sessionRequestBlob" : sessionRequestBlob,
            "externalDatabaseRefID" : self.latestExternalDatabaseRefID,
            "userAgentString" : FaceTec.sdk.getTestingAPIHeader()
        ] as [String : Any]

        // Send arguments across the com.facetec.sdk/livenesscheck method channel, to the Liveness Check Processor code.
        // New processors you add would invoke a different method or communicate across a different channel. Therefore
        // any processor decisions you make should be tracked and branching logic should occur here.
        DispatchQueue.main.async {
            self.processorChannel?.invokeMethod("processSession",
                                                arguments:args)
        }
    }
    
    func onFaceTecExit(sessionResult: FaceTecSessionResult) {
        DispatchQueue.main.async {
            self.onComplete(sessionResult.sessionStatus)
        }
    }
    
    // When the request blob has been received, send it back to the FaceTecSDK for continued processing
    func onResponseBlobReceived(responseBlob: String) {
        requestCallback.processResponse(responseBlob);
    }
    
    // Send the upload progress event to the FaceTec SDK
    func onUploadProgress(progress: Float) {
        requestCallback.updateProgress(progress);
    }
    
    // When an unrecoverable network event occurs call the FaceTec SDK abortOnCatastrophicError
     // This should never be called except when a hard server error occurs. For example the user loses network connectivity.
    func onCatastrophicNetworkError() {
        requestCallback.abortOnCatastrophicError();
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
