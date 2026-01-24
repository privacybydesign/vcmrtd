// Welcome to the FaceTec Sample App
// This sample demonstrates how to integrate the FaceTec Device SDK.
//
// This sample demonstrates:
// - Initialization
// - 3D Liveness Checks
// - 3D Enrollment
// - 3D Liveness Check Then 3D Face Match
// - 3D Liveness Check Then 3D:2D Photo ID Match
// - Standalone ID Scanning
// - Using FaceTec Device SDK Customization APIs to change the FaceTec UI
//
// Please use our technical support form to submit questions and issue reports:  https://dev.facetec.com/

import UIKit
import FaceTecSDK
import LocalAuthentication

class SampleAppViewController: UIViewController, FaceTecInitializeCallback, URLSessionDelegate {    
    static var utils: SampleAppUtilities!
    static var sampleAppOfficialIDPhotoView: SampleAppOfficialIDPhotoView!
    var sdkInstance: FaceTecSDKInstance?

    // IMPORTANT NOTE:  In Your Production Application, DO NOT set or handle externalDatabaseRefID in your client-side code.
    //
    // The externalDatabaseRefID is used in the following calls for the following reasons:
    // - 3D Enrollment - Your internal identifier for the 3D Enrollment.
    // - 3D:3D Re-Verification - Your internal identifier for the 3D Enrollment that will be used to perform 3D:3D Matching against for the 3D FaceScan that will be created.
    // - Photo ID Match - Your internal identifier for the 3D Enrollment that will be used to to perform 3D:2D Matching of the ID Images to the 3D Enrollment.
    //
    // The FaceTec Sample App demonstrates generating the externalDatabaseRefID on the client-side *FOR DEMONSTRATION PURPOSES ONLY*.
    // In Production, you need to generate and manage the externalDatabaseRefIDs in your server-side code.
    // * If you expose externalDatabaseRefIDs in your front-end code, you will allow for attacks where externalDatabaseRefIDs can be
    // exposed by to attackers by hooking into device code or inspecting network transactions.
    public static var demonstrationExternalDatabaseRefID: String = "";

    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var mainInterfaceStackView: UIStackView!
    @IBOutlet weak var livenessButton: SampleAppActionButton!
    @IBOutlet weak var enrollUserButton: SampleAppActionButton!
    @IBOutlet weak var verifyUserButton: SampleAppActionButton!
    @IBOutlet weak var photoIDMatchButton: SampleAppActionButton!
    @IBOutlet weak var photoIDScanButton: SampleAppActionButton!
    @IBOutlet weak var officialIDPhotoButton: SampleAppActionButton!
    @IBOutlet weak var themesButton: SampleAppActionButton!
    @IBOutlet weak var themeTransitionImageView: UIImageView!
    @IBOutlet weak var themeTransitionText: UILabel!
    @IBOutlet weak var vocalGuidanceSettingButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure initial look and feel of the Sample App
        SampleAppViewController.utils = SampleAppUtilities(vc: self)
        SampleAppViewController.utils.displayStatus(statusString: "Initializing...")
        

        // Required Parameters:
        // - deviceKeyIdentifier: The public Device Key Identifier associated with your Application
        // - sessionRequestProcessor: A SessionRequestProcessor class. Please see the implementation of SessionRequestProcessor in this Sample App
        // - completion: A FaceTecInitializeCallback.
        //      - The onFaceTecSDKInitializeSuccess callback is called with a FaceTecSDKInstance when successful.
        //      - The onFaceTecSDKInitializeError callback is called when your SessionRequestProcessor cannot make a connection to your Server, or an invalid Device Key Identifier was used.
        FaceTec.sdk.initializeWithSessionRequest(deviceKeyIdentifier: Config.DeviceKeyIdentifier, sessionRequestProcessor: SessionRequestProcessor(), completion: self)
    }

    // Finish setup after initialization success
    func onFaceTecSDKInitializeSuccess(sdkInstance: FaceTecSDKInstance) {
        self.sdkInstance = sdkInstance
        SampleAppViewController.utils.enableButtons(shouldEnable: true)
                
        // Set the Sound Files that will be used for Vocal Guidance.
        SampleAppUtilities.setVocalGuidanceSoundFiles()
        SampleAppViewController.utils.setUpVocalGuidancePlayers()
        
        // Set the strings that will be used for Group Names, Field Names, and Placeholder Texts in the FaceTec ID Scan User OCR Confirmation Screen.
        SampleAppUtilities.setOCRLocalization()
        
        // Set Your FaceTec Device SDK Customizations.
        SampleAppViewController.utils.handleThemeSelection(theme: SampleAppViewController.utils.currentTheme)
        SampleAppViewController.utils.displayStatus(statusString: "Initialized Successfully.")
    }
    
    // Displays the FaceTec SDK Init Status as a Text Prompt.”
    func onFaceTecSDKInitializeError(error: FaceTecInitializationError) {
        let errorMessage = "\(FaceTec.sdk.description(for: error))"
        SampleAppViewController.utils.displayStatus(statusString: errorMessage)
    }
    
    // Initiate a 3D Liveness Check.
    @IBAction func onLivenessCheckPressed(_ sender: Any) {
        SampleAppViewController.demonstrationExternalDatabaseRefID = ""
        SampleAppViewController.utils.fadeOutMainUIAndPrepareForFaceTecSDK()
        
        // Create and launch the View Controller for a 3D Liveness Check.
        let faceTecVC = sdkInstance!.start3DLiveness(with: SessionRequestProcessor())
        self.present(faceTecVC, animated: true, completion: nil)
    }
    
    // Initiate a 3D Liveness Check, then storing the 3D FaceMap in the Database, also known as "Enrollment". A random externalDatabaseRefID is generated each time to guarantee uniqueness.
    @IBAction func onEnrollUserPressed(_ sender: Any) {
        SampleAppViewController.demonstrationExternalDatabaseRefID = "ios_sample_app_" + UUID().uuidString
        SampleAppViewController.utils.fadeOutMainUIAndPrepareForFaceTecSDK()
        
        // Create and launch the View Controller for a 3D Liveness Check.
        let faceTecVC = sdkInstance!.start3DLiveness(with: SessionRequestProcessor())
        self.present(faceTecVC, animated: true, completion: nil)
    }
    
    // Initiate a 3D to 3D Verification against the Enrollment previously performed.
    @IBAction func onVerifyUserPressed(_ sender: Any) {
        // For demonstration purposes, verify that we have an externalDatabaseRefID to Verify against.
        if SampleAppViewController.demonstrationExternalDatabaseRefID.isEmpty {
            SampleAppViewController.utils.displayStatus(statusString: "Please enroll first before trying verification.")
            return
        }
        
        SampleAppViewController.utils.fadeOutMainUIAndPrepareForFaceTecSDK()
        
        // Create and launch the View Controller for a 3D to 3D Reverification
        let faceTecVC = sdkInstance!.start3DLivenessThen3DFaceMatch(with: SessionRequestProcessor())
        self.present(faceTecVC, animated: true, completion: nil)
    }
    
    // Initiate a 3D Liveness Check, then an ID Scan, then Match the 3D FaceMap to the ID Scan.
    @IBAction func onPhotoIDMatchPressed(_ sender: Any) {
        SampleAppViewController.demonstrationExternalDatabaseRefID = "ios_sample_app_" + UUID().uuidString
        SampleAppViewController.utils.fadeOutMainUIAndPrepareForFaceTecSDK()
        
        // Create and launch the View Controller for 3D:2D Photo ID Matching.
        let faceTecVC = sdkInstance!.start3DLivenessThen3D2DPhotoIDMatch(with: SessionRequestProcessor())
        self.present(faceTecVC, animated: true, completion: nil)
    }
    
    // Initiate a Photo ID Scan.
    @IBAction func onPhotoIDScanPressed(_ sender: Any) {
        SampleAppViewController.utils.fadeOutMainUIAndPrepareForFaceTecSDK()
        
        // Create and launch the View Controller for Standalone ID Scanning.
        let faceTecVC = sdkInstance!.startIDScanOnly(with: SessionRequestProcessor())
        self.present(faceTecVC, animated: true, completion: nil)
    }
    
    // Initiate a 3D Liveness Check and generate a 2D Image that can be used for Official ID Photo Documentation.
    @IBAction func onOfficialIDPhotoButtonPressed(_ sender: UIButton) {
        let alert = UIAlertController(title: "", message: "This is a Paid Extra-Feature, please contact FaceTec before use.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
        
        // Uncomment this code to use Official ID Photo
//        SampleAppViewController.demonstrationExternalDatabaseRefID = ""
//        
//        SampleAppViewController.utils.fadeOutMainUIAndPrepareForFaceTecSDK(runnable: {
//            SampleAppOfficialIDPhotoView.launchSampleAppOfficialIDPhotoView(sampleAppViewController: self, sampleAppView: self.view)
//        })
    }
    
    // When the FaceTec SDK is completely done, you receive control back here.
    // Since you have already handled all results in your Processor code, how you proceed here is up to you and how your App works.
    // In general, there was either a Success, or there was some other case where you cancelled out.
    static func demonstrateHandlingFaceTecExit(_ status: FaceTecSessionStatus) {
        print("Session Status: " + SampleAppUtilities.getSessionStatusString(status))
        
        let successful = status == .sessionCompleted
        if !successful {
            // Reset demonstrationExternalDatabaseRefID
            SampleAppViewController.demonstrationExternalDatabaseRefID = "";
        }
        
        if successful && sampleAppOfficialIDPhotoView != nil {
            SampleAppOfficialIDPhotoView.handleSampleAppOfficialIDPhotoResult()
            return
        }
        
        SampleAppViewController.utils.displayStatus(statusString: "See logs for more details.")
        SampleAppViewController.utils.fadeInMainUI()
    }
    
    // Present settings action sheet, allowing user to select a new app theme (pre-made FaceTecCustomization configuration).
    @IBAction func onThemesPressed(_ sender: Any) {
        SampleAppViewController.utils.showThemeSelectionMenu()
    }

    // Set the Vocal Guidance Customizations for FaceTec.
    @IBAction func onVocalGuidanceSettingButtonPressed(_ sender: Any) {
        SampleAppViewController.utils.setVocalGuidanceMode()
    }
}
