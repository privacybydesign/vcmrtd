import Foundation
import UIKit
import FaceTecSDK
import AVFoundation

class SampleAppUtilities: NSObject, FaceTecCustomAnimationDelegate {
    enum SampleAppVocalGuidanceMode {
        case OFF
        case MINIMAL
        case FULL
    }
    
    var vocalGuidanceOnPlayer: AVAudioPlayer!
    var vocalGuidanceOffPlayer: AVAudioPlayer!
    static var sampleAppVocalGuidanceMode: SampleAppVocalGuidanceMode!
    
    // Reference to app's main view controller
    let sampleAppVC: SampleAppViewController!
    
    var currentTheme = "Config Wizard Theme"
    var themeTransitionTextTimer: Timer!
    
    var networkIssueDetected = false
    
    init(vc: SampleAppViewController) {        
        sampleAppVC = vc

        if #available(iOS 13.0, *) {
            // For iOS 13+, use the rounded system font for displayed text
            if let roundedDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body).withDesign(.rounded) {
                let roundedMessageFont = UIFont(descriptor: roundedDescriptor, size: sampleAppVC.statusLabel.font.pointSize)
                sampleAppVC.statusLabel.font = roundedMessageFont
            }
        }
    }
    
    func fadeOutMainUIAndPrepareForFaceTecSDK(runnable: (() -> ())? = nil) {
        enableButtons(shouldEnable: false) {
            if(self.networkIssueDetected) {
                self.networkIssueDetected = false
                return
            }
            
            UIView.animate(withDuration: 0.3) {
                self.sampleAppVC.vocalGuidanceSettingButton.alpha = 0
                self.sampleAppVC.mainInterfaceStackView.alpha = 0
                self.sampleAppVC.themeTransitionImageView.alpha = 1
            } completion: { _ in
                if runnable != nil {
                    runnable!()
                }
            }
        }
    }
    
    func fadeInMainUI() {
        UIView.animate(withDuration: 0.6) {
            self.sampleAppVC.vocalGuidanceSettingButton.alpha = 1
            self.sampleAppVC.mainInterfaceStackView.alpha = 1
            self.sampleAppVC.statusLabel.alpha = 1
            self.sampleAppVC.themeTransitionImageView.alpha = 0
        } completion: { _ in
            self.enableButtons(shouldEnable: true)
            SampleAppOfficialIDPhotoView.dismissSampleAppOfficialIDPhotoView()
        };
    }
    
    func displayStatus(statusString: String, shouldLog: Bool = false) {
        DispatchQueue.main.async {
            self.sampleAppVC.statusLabel.text = statusString
            
            if(shouldLog) {
                print(statusString)
            }
        }
    }
    
    func showThemeSelectionMenu() {
        let themeSelectionMenu = UIAlertController(title: nil, message: "Select a Theme", preferredStyle: .actionSheet)
        
        let selectDevConfigThemeAction = UIAlertAction(title: "Config Wizard Theme", style: .default) {
            (_) -> Void in self.handleThemeSelection(theme: "Config Wizard Theme")
        }
        let selectFaceTecThemeAction = UIAlertAction(title: "FaceTec Theme", style: .default) {
            (_) -> Void in self.handleThemeSelection(theme: "FaceTec Theme")
        }
        let selectPseudoFullscreenThemeAction = UIAlertAction(title: "Pseudo-Fullscreen", style: .default) {
            (_) -> Void in self.handleThemeSelection(theme: "Pseudo-Fullscreen")
        }
        let selectWellRoundedThemeAction = UIAlertAction(title: "Well-Rounded", style: .default) {
            (_) -> Void in self.handleThemeSelection(theme: "Well-Rounded")
        }
        let selectBitcoinExchangeThemeAction = UIAlertAction(title: "Bitcoin Exchange", style: .default) {
            (_) -> Void in self.handleThemeSelection(theme: "Bitcoin Exchange")
        }
        let selectEKYCThemeAction = UIAlertAction(title: "eKYC", style: .default) {
            (_) -> Void in self.handleThemeSelection(theme: "eKYC")
        }
        let selectSampleBankThemeAction = UIAlertAction(title: "Sample Bank", style: .default) {
            (_) -> Void in self.handleThemeSelection(theme: "Sample Bank")
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        themeSelectionMenu.addAction(selectDevConfigThemeAction)
        themeSelectionMenu.addAction(selectFaceTecThemeAction)
        themeSelectionMenu.addAction(selectPseudoFullscreenThemeAction)
        themeSelectionMenu.addAction(selectWellRoundedThemeAction)
        themeSelectionMenu.addAction(selectBitcoinExchangeThemeAction)
        themeSelectionMenu.addAction(selectEKYCThemeAction)
        themeSelectionMenu.addAction(selectSampleBankThemeAction)
        themeSelectionMenu.addAction(cancelAction)
        
        // Must use popover controller for iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            if let popoverController = themeSelectionMenu.popoverPresentationController {
                popoverController.sourceView = sampleAppVC.view
                popoverController.sourceRect = CGRect(x: sampleAppVC.view.bounds.midX, y: sampleAppVC.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
        }
        
        // Remove negative width constraint that causes layout conflict warning -- non-critical unfixed Apple bug
        for subview in themeSelectionMenu.view.subviews {
            for constraint in subview.constraints where constraint.debugDescription.contains("width == - 16") {
                subview.removeConstraint(constraint)
            }
        }
        
        sampleAppVC.present(themeSelectionMenu, animated: true, completion: nil)
    }
    
    @objc func dismissImageView(tap: UITapGestureRecognizer){
        let tappedImage = tap.view!
        tappedImage.removeFromSuperview()
    }
    
    // Place a UIImage onto the main interface in a stack that can be popped by tapping on the image
    func addDismissableImageToInterface(image: UIImage) {
        let imageView = UIImageView(image: image)
        imageView.frame = UIScreen.main.bounds
        
        // Resize image to better fit device's display
        // Remove this option to view image full screen
        let screenSize = UIScreen.main.bounds
        let ratio = screenSize.width / image.size.width
        let size = (image.size).applying(CGAffineTransform(scaleX: 0.5 * ratio, y: 0.5 * ratio))
        let hasAlpha = false
        let scale: CGFloat = 0.0
        UIGraphicsBeginImageContextWithOptions(size, hasAlpha, scale)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        imageView.image = scaledImage
        imageView.contentMode = .center
        
        // Tap on image to dismiss view
        imageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissImageView(tap:)))
        imageView.addGestureRecognizer(tap)
        
        sampleAppVC.view.addSubview(imageView)
    }
    
    func handleThemeSelection(theme: String) {
        currentTheme = theme
        ThemeHelpers.setAppTheme(theme: theme)
        updateThemeTransitionView()

        // Set this class as the delegate to handle the FaceTecCustomAnimationDelegate methods. This delegate needs to be applied to the current FaceTecCustomization object before starting a new Session in order to use FaceTecCustomAnimationDelegate methods to provide a new instance of a custom UIView that will be displayed for the method-specified animation.
        if(Config.currentCustomization.customAnimationDelegate == nil) {
            Config.currentCustomization.customAnimationDelegate = self
            SampleAppUtilities.setVocalGuidanceSoundFiles()
            FaceTec.sdk.setCustomization(Config.currentCustomization)
        }
    }
    
    func updateThemeTransitionView() {
        var transitionViewImage: UIImage? = nil
        var transitionTextColor = Config.currentCustomization.guidanceCustomization.foregroundColor
        switch currentTheme {
            case "FaceTec Theme":
                break
            case "Config Wizard Theme":
                break
            case "Pseudo-Fullscreen":
                break
            case "Well-Rounded":
                transitionViewImage = UIImage(named: "well_rounded_bg")
                transitionTextColor = Config.currentCustomization.frameCustomization.backgroundColor
                break
            case "Bitcoin Exchange":
                transitionViewImage = UIImage(named: "bitcoin_exchange_bg")
                transitionTextColor = Config.currentCustomization.frameCustomization.backgroundColor
                break
            case "eKYC":
                transitionViewImage = UIImage(named: "ekyc_bg")
                break
            case "Sample Bank":
                transitionViewImage = UIImage(named: "sample_bank_bg")
                transitionTextColor = Config.currentCustomization.frameCustomization.backgroundColor
                break
            default:
                break
        }
        
        self.sampleAppVC.themeTransitionImageView.image = transitionViewImage != nil ? transitionViewImage : UIImage()
        self.sampleAppVC.themeTransitionText.textColor = transitionTextColor
    }
    
    func enableButtons(shouldEnable: Bool, completion: (() -> ())? = nil) {
        DispatchQueue.main.async {
            self.sampleAppVC.livenessButton.isEnabled = shouldEnable
            self.sampleAppVC.enrollUserButton.isEnabled = shouldEnable
            self.sampleAppVC.verifyUserButton.isEnabled = shouldEnable
            self.sampleAppVC.photoIDMatchButton.isEnabled = shouldEnable
            self.sampleAppVC.photoIDScanButton.isEnabled = shouldEnable
            self.sampleAppVC.officialIDPhotoButton.isEnabled = shouldEnable
            self.sampleAppVC.themesButton.isEnabled = shouldEnable
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
                if completion != nil {
                    completion!()
                }
            }
        }
    }
    
    func onCreateNewResultScreenActivityIndicatorView() -> UIView? {
        var activityIndicatorView: UIView? = nil
        switch currentTheme {
            case "FaceTec Theme":
                break
            case "Config Wizard Theme":
                break
            case "Pseudo-Fullscreen":
                activityIndicatorView = PseudoFullscreenActivityIndicatorView()
                break
            case "Well-Rounded":
                activityIndicatorView = WellRoundedActivityIndicatorView()
                break
            case "Bitcoin Exchange":
                break
            case "eKYC":
                activityIndicatorView = EKYCActvityIndicatorView()
                break
            case "Sample Bank":
                break
            default:
                break
        }
        return activityIndicatorView
    }
    
    func onCreateNFCStartingAnimationView() -> UIView? {
        return NFCStartingAnimationView()
    }
    
    func onCreateNFCCardStartingAnimationView() -> UIView? {
        return NFCCardStartingAnimationView()
    }
    
    func onCreateNFCCardScanningAnimationView() -> UIView? {
        return NFCCardScanningAnimationView()
    }
    
    func onCreateNFCScanningAnimationView() -> UIView? {
        var scanningAnimationView: UIView? = nil
        switch currentTheme {
            case "FaceTec Theme":
                break
            case "Config Wizard Theme":
                break
            case "Pseudo-Fullscreen":
                scanningAnimationView = NFCScanningAnimationViewBlack()
                break
            case "Well-Rounded":
                scanningAnimationView = NFCScanningAnimationViewGreen()
                break
            case "Bitcoin Exchange":
                break
            case "eKYC":
                scanningAnimationView = NFCScanningAnimationViewRed()
                break
            case "Sample Bank":
                break
            default:
                break
        }
        
        if scanningAnimationView == nil {
            scanningAnimationView = NFCScanningAnimationView()
        }
        
        return scanningAnimationView
    }
    
    func onCreateNFCSkipOrErrorAnimationView() -> UIView? {
        var skipOrErrorAnimationView: UIView? = nil
        switch currentTheme {
            case "FaceTec Theme":
                break
            case "Config Wizard Theme":
                break
            case "Pseudo-Fullscreen":
                skipOrErrorAnimationView = PseudoFullscreenUnsuccessView()
                break
            case "Well-Rounded":
                skipOrErrorAnimationView = UIImageView(image: UIImage(named: "warning_green"))
                break
            case "Bitcoin Exchange":
                break
            case "eKYC":
                skipOrErrorAnimationView = EKYCUnsuccessView()
                break
            case "Sample Bank":
                skipOrErrorAnimationView = UIImageView(image: UIImage(named: "warning_white"))
                break
            default:
                break
        }
        
        return skipOrErrorAnimationView
    }
    
    func onCreateNewResultScreenSuccessAnimationView() -> UIView? {
        var successAnimationView: UIView? = nil
        switch currentTheme {
            case "FaceTec Theme":
                break
            case "Config Wizard Theme":
                break
            case "Pseudo-Fullscreen":
                successAnimationView = PseudoFullscreenSuccessView()
                break
            case "Well-Rounded":
                successAnimationView = WellRoundedSuccessView()
                break
            case "Bitcoin Exchange":
                break
            case "eKYC":
                successAnimationView = EKYCSuccessView()
                break
            case "Sample Bank":
                break
            default:
                break
        }
        return successAnimationView
    }
    
    func onCreateNewResultScreenIDScanSuccessAnimationView() -> UIView? {
        var successAnimationView: UIView? = nil
        switch currentTheme {
            case "FaceTec Theme":
                break
            case "Config Wizard Theme":
                break
            case "Pseudo-Fullscreen":
                successAnimationView = PseudoFullscreenSuccessView()
                break
            case "Well-Rounded":
                successAnimationView = WellRoundedSuccessView()
                break
            case "Bitcoin Exchange":
                break
            case "eKYC":
                successAnimationView = EKYCSuccessView()
                break
            case "Sample Bank":
                break
            default:
                break
        }
        return successAnimationView
    }
    
    func onCreateNewResultScreenNFCSuccessAnimationView() -> UIView? {
        var successAnimationView: UIView? = nil
        switch currentTheme {
            case "FaceTec Theme":
                break
            case "Config Wizard Theme":
                break
            case "Pseudo-Fullscreen":
                successAnimationView = PseudoFullscreenSuccessView()
                break
            case "Well-Rounded":
                successAnimationView = WellRoundedSuccessView()
                break
            case "Bitcoin Exchange":
                break
            case "eKYC":
                successAnimationView = EKYCSuccessView()
                break
            case "Sample Bank":
                break
            default:
                break
        }
        return successAnimationView
    }
    
    func onCreateNewResultScreenUnsuccessAnimationView() -> UIView? {
        var unsuccessAnimationView: UIView? = nil
        switch currentTheme {
            case "FaceTec Theme":
                break
            case "Config Wizard Theme":
                break
            case "Pseudo-Fullscreen":
                unsuccessAnimationView = PseudoFullscreenUnsuccessView()
                break
            case "Well-Rounded":
                unsuccessAnimationView = WellRoundedUnsuccessView()
                break
            case "Bitcoin Exchange":
                break
            case "eKYC":
                unsuccessAnimationView = EKYCUnsuccessView()
                break
            case "Sample Bank":
                break
            default:
                break
        }
        return unsuccessAnimationView
    }
    
    func onCreateCustomSessionAbortAnimation() -> UIView? {
        let animationView: UIView? = nil
        switch currentTheme {
            case "FaceTec Theme":
                break
            case "Config Wizard Theme":
                break
            case "Pseudo-Fullscreen":
                break
            case "Well-Rounded":
                break
            case "Bitcoin Exchange":
                break
            case "eKYC":
                break
            case "Sample Bank":
                break
            default:
                break
        }
        return animationView
    }
    
    func onCreateIDFeedbackScreenFlipIDToBackAnimationView() -> UIView? {
        let animationView: UIView? = nil
        switch currentTheme {
            case "FaceTec Theme":
                break
            case "Config Wizard Theme":
                break
            case "Pseudo-Fullscreen":
                break
            case "Well-Rounded":
                break
            case "Bitcoin Exchange":
                break
            case "eKYC":
                break
            case "Sample Bank":
                break
            default:
                break
        }
        return animationView
    }
    
    func onCreateIDFeedbackScreenFlipIDToFrontAnimationView() -> UIView? {
        let animationView: UIView? = nil
        switch currentTheme {
            case "FaceTec Theme":
                break
            case "Config Wizard Theme":
                break
            case "Pseudo-Fullscreen":
                break
            case "Well-Rounded":
                break
            case "Bitcoin Exchange":
                break
            case "eKYC":
                break
            case "Sample Bank":
                break
            default:
                break
        }
        return animationView
    }
    
    func onCreateAdditionalReviewScreenAnimationView() -> UIView? {
        var animationView: UIView? = nil
        switch currentTheme {
            case "FaceTec Theme":
                break
            case "Config Wizard Theme":
                break
            case "Pseudo-Fullscreen":
                break
            case "Well-Rounded":
                animationView = AdditionalReviewAnimationViewGreen()
                break
            case "Bitcoin Exchange":
                break
            case "eKYC":
                break
            case "Sample Bank":
                break
            default:
                break
        }
        return animationView
    }
    
    func onCreateInitialLoadingAnimationView() -> UIView? {
        var animationView: UIView? = nil
        switch currentTheme {
            case "FaceTec Theme":
                break
            case "Config Wizard Theme":
                break
            case "Pseudo-Fullscreen":
                animationView = PseudoFullscreenActivityIndicatorView()
                break
            case "Well-Rounded":
                animationView = WellRoundedActivityIndicatorView()
                break
            case "Bitcoin Exchange":
                break
            case "eKYC":
                animationView = EKYCActvityIndicatorView()
                break
            case "Sample Bank":
                break
            default:
                break
        }
        return animationView
    }
    
    func onCreateOCRConfirmationScrollIndicatorAnimationView() -> UIView? {
        var animationView: UIView? = nil
        switch currentTheme {
            case "FaceTec Theme":
                break
            case "Config Wizard Theme":
                break
            case "Pseudo-Fullscreen":
                break
            case "Well-Rounded":
                break
            case "Bitcoin Exchange":
                break
            case "eKYC":
                animationView = EKYCScrollIndicatorAnimationView()
                break
            case "Sample Bank":
                break
            default:
                break
        }
        return animationView
    }
    
    func setUpVocalGuidancePlayers() {
        SampleAppUtilities.sampleAppVocalGuidanceMode = .MINIMAL

        guard let vocalGuidanceOnUrl = Bundle.main.url(forResource: "vocal_guidance_on", withExtension: "mp3") else { return }
        guard let vocalGuidanceOffUrl = Bundle.main.url(forResource: "vocal_guidance_off", withExtension: "mp3") else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            vocalGuidanceOnPlayer = try AVAudioPlayer(contentsOf: vocalGuidanceOnUrl)
            vocalGuidanceOffPlayer = try AVAudioPlayer(contentsOf: vocalGuidanceOffUrl)
        }
        catch let error {
            print(error.localizedDescription)
        }
    }
    
    func setVocalGuidanceMode() {
        if !(AVAudioSession.sharedInstance().outputVolume > 0) {
            let alert = UIAlertController(title: nil, message: "Vocal Guidance is disabled when the device is muted", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
            self.sampleAppVC.present(alert, animated: true, completion: nil)
            return
        }
        
        if vocalGuidanceOnPlayer == nil || vocalGuidanceOffPlayer == nil || vocalGuidanceOnPlayer.isPlaying || vocalGuidanceOffPlayer.isPlaying {
            return
        }

        DispatchQueue.main.async {
            switch(SampleAppUtilities.sampleAppVocalGuidanceMode) {
            case .OFF:
                SampleAppUtilities.sampleAppVocalGuidanceMode = .MINIMAL
                self.sampleAppVC.vocalGuidanceSettingButton.setImage(UIImage(named: "vocal_minimal.png"), for: .normal)
                self.vocalGuidanceOnPlayer.play()
                Config.currentCustomization.vocalGuidanceCustomization.mode = FaceTecVocalGuidanceMode.minimalVocalGuidance
            case .MINIMAL:
                SampleAppUtilities.sampleAppVocalGuidanceMode = .FULL;
                self.sampleAppVC.vocalGuidanceSettingButton.setImage(UIImage(named: "vocal_full.png"), for: .normal)
                self.vocalGuidanceOnPlayer.play()
                Config.currentCustomization.vocalGuidanceCustomization.mode = FaceTecVocalGuidanceMode.fullVocalGuidance
            case .FULL:
                SampleAppUtilities.sampleAppVocalGuidanceMode = .OFF;
                self.sampleAppVC.vocalGuidanceSettingButton.setImage(UIImage(named: "vocal_off.png"), for: .normal)
                self.vocalGuidanceOffPlayer.play()
                Config.currentCustomization.vocalGuidanceCustomization.mode = FaceTecVocalGuidanceMode.noVocalGuidance
            default: break
            }
            SampleAppUtilities.setVocalGuidanceSoundFiles()
            FaceTec.sdk.setCustomization(Config.currentCustomization)
        }
    }
    
    public static func setVocalGuidanceSoundFiles() {
        Config.currentCustomization.vocalGuidanceCustomization.pleaseFrameYourFaceInTheOvalSoundFile = Bundle.main.path(forResource: "please_frame_your_face_sound_file", ofType: "mp3") ?? ""
        Config.currentCustomization.vocalGuidanceCustomization.pleaseMoveCloserSoundFile = Bundle.main.path(forResource: "please_move_closer_sound_file", ofType: "mp3") ?? ""
        Config.currentCustomization.vocalGuidanceCustomization.pleaseRetrySoundFile = Bundle.main.path(forResource: "please_retry_sound_file", ofType: "mp3") ?? ""
        Config.currentCustomization.vocalGuidanceCustomization.uploadingSoundFile = Bundle.main.path(forResource: "uploading_sound_file", ofType: "mp3") ?? ""
        Config.currentCustomization.vocalGuidanceCustomization.facescanSuccessfulSoundFile = Bundle.main.path(forResource: "facescan_successful_sound_file", ofType: "mp3") ?? ""
        Config.currentCustomization.vocalGuidanceCustomization.pleasePressTheButtonToStartSoundFile = Bundle.main.path(forResource: "please_press_button_sound_file", ofType: "mp3") ?? ""
        
        switch(SampleAppUtilities.sampleAppVocalGuidanceMode) {
        case .OFF:
            Config.currentCustomization.vocalGuidanceCustomization.mode = FaceTecVocalGuidanceMode.noVocalGuidance
        case .MINIMAL:
            Config.currentCustomization.vocalGuidanceCustomization.mode = FaceTecVocalGuidanceMode.minimalVocalGuidance
        case .FULL:
            Config.currentCustomization.vocalGuidanceCustomization.mode = FaceTecVocalGuidanceMode.fullVocalGuidance
        default: break
        }
    }
    
    public static func setOCRLocalization() {
        // Set the strings to be used for group names, field names, and placeholder texts for the FaceTec ID Scan User OCR Confirmation Screen.
        // DEVELOPER NOTE: For this demo, we are using the template json file, 'FaceTec_OCR_Customization.json,' as the parameter in calling this API.
        // For the configureOCRLocalization API parameter, you may use any dictionary object that follows the same structure and key naming as the template json file, 'FaceTec_OCR_Customization.json'.
        if let path = Bundle.main.path(forResource: "FaceTec_OCR_Customization", ofType: "json") {
            do {
                let jsonData = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: .mutableLeaves)
                if let jsonDictionary = jsonObject as? Dictionary<String, AnyObject> {
                    FaceTec.sdk.configureOCRLocalization(dictionary: jsonDictionary)
                }
            } catch {
                print("Error loading JSON for OCR Localization")
            }
        }
    }
    
    public static func getSessionStatusString(_ status: FaceTecSessionStatus) -> String {
        switch(status) {
        case .sessionCompleted:
            return "Session was completed."
        case .requestAborted:
            return "Session was cancelled because abortOnCatastrophicError() was called."
        case .cameraPermissionsDenied:
            return "FaceTec SDK was unable to access the Camera due to the User’s Settings or an Administrator Policy"
        case .userCancelledFaceScan:
            return "The user cancelled before performing enough Scans to Succeed."
        case .userCancelledIDScan:
            return "The User cancelled before completing all of the steps in the ID Scan Process."
        case .lockedOut:
            return "FaceTec SDK is in a lockout state."
        case .cameraError:
            return "Session cancelled due to a camera error."
        case .unknownInternalError:
            return "Session failed because an unknown or unexpected error occurred."
        }
    }
}
