//
//  ThemeHelpers.swift
//  FaceTecSDK-Sample-App
//

import Foundation
import UIKit
import FaceTecSDK

class ThemeHelpers {
    public class func setAppTheme(theme: String) {
        Config.currentCustomization = getCustomizationForTheme(theme: theme)
        Config.currentLowLightCustomization = getLowLightCustomizationForTheme(theme: theme)
        Config.currentDynamicDimmingCustomization = getDynamicDimmingCustomizationForTheme(theme: theme)
        
        SampleAppUtilities.setVocalGuidanceSoundFiles()
        FaceTec.sdk.setCustomization(Config.currentCustomization)
        FaceTec.sdk.setLowLightCustomization(Config.currentLowLightCustomization)
        FaceTec.sdk.setDynamicDimmingCustomization(Config.currentDynamicDimmingCustomization)
    }
    
    class func getCustomizationForTheme(theme: String) -> FaceTecCustomization {
        var currentCustomization = FaceTecCustomization()
        
        let retryScreenSlideshowImages = [UIImage(named: "FaceTec_ideal_1")!, UIImage(named: "FaceTec_ideal_2")!, UIImage(named: "FaceTec_ideal_3")!, UIImage(named: "FaceTec_ideal_4")!, UIImage(named: "FaceTec_ideal_5")!]
        
        if theme == "FaceTec Theme" {
            // using default customizations -- do nothing
        }
        else if theme == "Config Wizard Theme" {
            currentCustomization = Config.retrieveConfigurationWizardCustomization()
        }
        else if theme == "Pseudo-Fullscreen" {
            let primaryColor = UIColor(red: 0.169, green: 0.169, blue: 0.169, alpha: 1) // black
            let primaryColorLight = UIColor(red: 0.337, green: 0.337, blue: 0.337, alpha: 1) // black
            let secondaryColor = UIColor(red: 0.235, green: 0.702, blue: 0.443, alpha: 1) // green
            let backgroundColor = UIColor(red: 0.933, green: 0.965, blue: 0.973, alpha: 1) // white
            let buttonBackgroundDisabledColor = UIColor(red: 0.678, green: 0.678, blue: 0.678, alpha: 1)
            
            let backgroundLayer = CAGradientLayer.init()
            backgroundLayer.colors = [secondaryColor.cgColor, secondaryColor.cgColor]
            backgroundLayer.locations = [0,1]
            backgroundLayer.startPoint = CGPoint.init(x: 0, y: 0)
            backgroundLayer.endPoint = CGPoint.init(x: 1, y: 0)
            
            var font = UIFont.init(name: "Futura-Medium", size: 26)
            if font == nil {
                font = UIFont.systemFont(ofSize: 26)
            }
            
            let feedbackShadow: FaceTecShadow? = nil
            let frameShadow: FaceTecShadow? = nil
            let scrollIndicatorShadow: FaceTecShadow? = nil
            
            //
            // NOTE: For this theme, the Result Screen's activity indicator and result animations are overriden by the use of the FaceTecCustomAnimationDelegate and its methods to specify a custom UIView to display for the individual animations.
            //
            
            // Overlay Customization
            currentCustomization.overlayCustomization.backgroundColor = backgroundColor
            currentCustomization.overlayCustomization.showBrandingImage = false
            currentCustomization.overlayCustomization.brandingImage = nil
            // Guidance Customization
            currentCustomization.guidanceCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.guidanceCustomization.foregroundColor = primaryColor
            currentCustomization.guidanceCustomization.headerFont = font!
            currentCustomization.guidanceCustomization.subtextFont = font!
            currentCustomization.guidanceCustomization.buttonFont = font!
            currentCustomization.guidanceCustomization.buttonTextNormalColor = backgroundColor
            currentCustomization.guidanceCustomization.buttonBackgroundNormalColor = primaryColor
            currentCustomization.guidanceCustomization.buttonTextHighlightColor = backgroundColor
            currentCustomization.guidanceCustomization.buttonBackgroundHighlightColor = primaryColorLight
            currentCustomization.guidanceCustomization.buttonTextDisabledColor = backgroundColor
            currentCustomization.guidanceCustomization.buttonBackgroundDisabledColor =  buttonBackgroundDisabledColor
            currentCustomization.guidanceCustomization.buttonBorderColor = UIColor.clear
            currentCustomization.guidanceCustomization.buttonBorderWidth = 0
            currentCustomization.guidanceCustomization.buttonCornerRadius = 25
            currentCustomization.guidanceCustomization.readyScreenOvalFillColor = UIColor.clear
            currentCustomization.guidanceCustomization.readyScreenTextBackgroundColor = backgroundColor
            currentCustomization.guidanceCustomization.readyScreenTextBackgroundCornerRadius = 5
            currentCustomization.guidanceCustomization.retryScreenImageBorderColor = primaryColor
            currentCustomization.guidanceCustomization.retryScreenImageBorderWidth = 2
            currentCustomization.guidanceCustomization.retryScreenImageCornerRadius = 10
            currentCustomization.guidanceCustomization.retryScreenOvalStrokeColor = backgroundColor
            currentCustomization.guidanceCustomization.retryScreenSlideshowImages = retryScreenSlideshowImages
            currentCustomization.guidanceCustomization.retryScreenSlideshowInterval = 2000
            currentCustomization.guidanceCustomization.enableRetryScreenSlideshowShuffle = true
            currentCustomization.guidanceCustomization.cameraPermissionsScreenImage = UIImage(named: "camera_shutter_offblack")
            // ID Scan Customization
            currentCustomization.idScanCustomization.showSelectionScreenDocumentImage = true
            currentCustomization.idScanCustomization.selectionScreenDocumentImage = UIImage(named: "document_offblack")
            currentCustomization.idScanCustomization.selectionScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.reviewScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.captureScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.reviewScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.selectionScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.captureScreenFocusMessageTextColor = primaryColorLight
            currentCustomization.idScanCustomization.headerFont = font!
            currentCustomization.idScanCustomization.subtextFont = font!
            currentCustomization.idScanCustomization.buttonFont = font!
            currentCustomization.idScanCustomization.buttonTextNormalColor = backgroundColor
            currentCustomization.idScanCustomization.buttonBackgroundNormalColor = primaryColor
            currentCustomization.idScanCustomization.buttonTextHighlightColor = backgroundColor
            currentCustomization.idScanCustomization.buttonBackgroundHighlightColor = primaryColorLight
            currentCustomization.idScanCustomization.buttonTextDisabledColor = backgroundColor
            currentCustomization.idScanCustomization.buttonBackgroundDisabledColor =  buttonBackgroundDisabledColor
            currentCustomization.idScanCustomization.buttonBorderColor = UIColor.clear
            currentCustomization.idScanCustomization.buttonBorderWidth = 0
            currentCustomization.idScanCustomization.buttonCornerRadius = 25
            currentCustomization.idScanCustomization.captureScreenTextBackgroundColor = backgroundColor
            currentCustomization.idScanCustomization.captureScreenTextBackgroundBorderColor = primaryColor
            currentCustomization.idScanCustomization.captureScreenTextBackgroundBorderWidth = 2
            currentCustomization.idScanCustomization.captureScreenTextBackgroundCornerRadius = 5
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundColor = backgroundColor
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundBorderColor = primaryColor
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundBorderWidth = 2
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundCornerRadius = 5
            currentCustomization.idScanCustomization.captureScreenBackgroundColor = backgroundColor
            currentCustomization.idScanCustomization.captureFrameStrokeColor = primaryColor
            currentCustomization.idScanCustomization.captureFrameStrokeWith = 2
            currentCustomization.idScanCustomization.captureFrameCornerRadius = 12
            currentCustomization.idScanCustomization.activeTorchButtonImage = UIImage(named: "torch_active_black")
            currentCustomization.idScanCustomization.inactiveTorchButtonImage = UIImage(named: "torch_inactive_black")
            currentCustomization.idScanCustomization.additionalReviewScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.additionalReviewScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.additionalReviewScreenImage = UIImage(named: "review_offblack")
            currentCustomization.idScanCustomization.idFeedbackScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.idFeedbackScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.idFeedbackScreenFlipIDFrontImage = nil
            currentCustomization.idScanCustomization.idFeedbackScreenFlipIDBackImage = nil
            currentCustomization.idScanCustomization.additionalReviewScreenAnimationDisplayTime = 2.0;
            currentCustomization.idScanCustomization.idFeedbackScreenAnimationDisplayTime = 2.0;
            currentCustomization.idScanCustomization.nfcScreenAnimationDisplayTime = 2.0;
            currentCustomization.idScanCustomization.enableAdditionalReviewTag = false
            currentCustomization.idScanCustomization.additionalReviewTagImage = nil
            currentCustomization.idScanCustomization.additionalReviewTagImageColor = primaryColor
            currentCustomization.idScanCustomization.additionalReviewTagTextColor = primaryColor
            // OCR Confirmation Screen Customization
            currentCustomization.ocrConfirmationCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.ocrConfirmationCustomization.mainHeaderDividerLineColor = secondaryColor
            currentCustomization.ocrConfirmationCustomization.mainHeaderDividerLineWidth = 2
            currentCustomization.ocrConfirmationCustomization.mainHeaderFont = font!
            currentCustomization.ocrConfirmationCustomization.sectionHeaderFont = font!
            currentCustomization.ocrConfirmationCustomization.fieldLabelFont = font!
            currentCustomization.ocrConfirmationCustomization.fieldValueFont = font!
            currentCustomization.ocrConfirmationCustomization.inputFieldFont = font!
            currentCustomization.ocrConfirmationCustomization.inputFieldPlaceholderFont = font!
            currentCustomization.ocrConfirmationCustomization.mainHeaderTextColor = secondaryColor
            currentCustomization.ocrConfirmationCustomization.sectionHeaderTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.fieldLabelTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.fieldValueTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.inputFieldTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.inputFieldPlaceholderTextColor = secondaryColor.withAlphaComponent(0.4)
            currentCustomization.ocrConfirmationCustomization.inputFieldBackgroundColor = UIColor.clear
            currentCustomization.ocrConfirmationCustomization.inputFieldBorderColor = secondaryColor
            currentCustomization.ocrConfirmationCustomization.inputFieldBorderWidth = 2
            currentCustomization.ocrConfirmationCustomization.inputFieldCornerRadius = 0
            currentCustomization.ocrConfirmationCustomization.showInputFieldBottomBorderOnly = true
            currentCustomization.ocrConfirmationCustomization.buttonFont = font!
            currentCustomization.ocrConfirmationCustomization.buttonTextNormalColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.buttonBackgroundNormalColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.buttonTextHighlightColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.buttonBackgroundHighlightColor = primaryColorLight
            currentCustomization.ocrConfirmationCustomization.buttonTextDisabledColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.buttonBackgroundDisabledColor =  buttonBackgroundDisabledColor
            currentCustomization.ocrConfirmationCustomization.buttonBorderColor = UIColor.clear
            currentCustomization.ocrConfirmationCustomization.buttonBorderWidth = 0
            currentCustomization.ocrConfirmationCustomization.buttonCornerRadius = 25
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundNormalColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundHighlightColor = primaryColorLight
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundNormalColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundHighlightColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBorderColor = UIColor.clear
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBorderWidth = 0
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorCornerRadius = -1
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorFont = font!
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorShadow = scrollIndicatorShadow
            currentCustomization.ocrConfirmationCustomization.enableScrollIndicator = true
            currentCustomization.ocrConfirmationCustomization.enableScrollIndicatorTextAnimation = true
            currentCustomization.ocrConfirmationCustomization.enableFixedConfirmButton = false
            currentCustomization.ocrConfirmationCustomization.showScrollIndicatorImage = true
            // Result Screen Customization
            currentCustomization.resultScreenCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.resultScreenCustomization.foregroundColor = primaryColor
            currentCustomization.resultScreenCustomization.messageFont = font!.withSize(20)
            currentCustomization.resultScreenCustomization.activityIndicatorColor = primaryColor
            currentCustomization.resultScreenCustomization.customActivityIndicatorImage = nil
            currentCustomization.resultScreenCustomization.customActivityIndicatorRotationInterval = 800
            currentCustomization.resultScreenCustomization.resultAnimationBackgroundColor = secondaryColor
            currentCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundColor = secondaryColor
            currentCustomization.resultScreenCustomization.resultAnimationForegroundColor = backgroundColor
            currentCustomization.resultScreenCustomization.resultAnimationUnsuccessForegroundColor = backgroundColor
            currentCustomization.resultScreenCustomization.resultAnimationIDScanSuccessForegroundColor = backgroundColor
            currentCustomization.resultScreenCustomization.resultAnimationNFCSuccessForegroundColor = backgroundColor
            currentCustomization.resultScreenCustomization.resultAnimationSuccessBackgroundImage = nil
            currentCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundImage = nil
            currentCustomization.resultScreenCustomization.showUploadProgressBar = true
            currentCustomization.resultScreenCustomization.uploadProgressTrackColor = primaryColor.withAlphaComponent(0.2)
            currentCustomization.resultScreenCustomization.uploadProgressFillColor = secondaryColor
            currentCustomization.resultScreenCustomization.animationRelativeScale = 1.0
            currentCustomization.resultScreenCustomization.resultAnimationDisplayTime = 2.0
            currentCustomization.resultScreenCustomization.faceScanStillUploadingMessageDelayTime = 6.0
            currentCustomization.resultScreenCustomization.idScanStillUploadingMessageDelayTime = 8.0
            // Feedback Customization
            currentCustomization.feedbackCustomization.backgroundColor = backgroundLayer
            currentCustomization.feedbackCustomization.textColor = backgroundColor
            currentCustomization.feedbackCustomization.textFont = font!.withSize(20)
            currentCustomization.feedbackCustomization.cornerRadius = 5
            currentCustomization.feedbackCustomization.shadow = feedbackShadow
            // Frame Customization
            currentCustomization.frameCustomization.backgroundColor = backgroundColor
            currentCustomization.frameCustomization.borderColor = primaryColor
            currentCustomization.frameCustomization.borderWidth = 0
            currentCustomization.frameCustomization.cornerRadius = 0
            currentCustomization.frameCustomization.shadow = frameShadow
            // Oval Customization
            currentCustomization.ovalCustomization.strokeColor = primaryColor
            currentCustomization.ovalCustomization.progressColor1 = secondaryColor.withAlphaComponent(0.7)
            currentCustomization.ovalCustomization.progressColor2 = secondaryColor.withAlphaComponent(0.7)
            // Cancel Button Customization
            currentCustomization.cancelButtonCustomization.customImage = UIImage(named: "single_chevron_left_offblack")
            currentCustomization.cancelButtonCustomization.location = FaceTecCancelButtonLocation.custom
            let topNotchOffset = UIDevice.current.userInterfaceIdiom == .phone && UIScreen.main.fixedCoordinateSpace.bounds.size.height >= 812 ? 30 : 0
            currentCustomization.cancelButtonCustomization.customLocation = CGRect(x: 10, y: 10 + topNotchOffset, width: 25, height: 25)
            currentCustomization.cancelButtonCustomization.hideForCameraPermissions = true
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentCustomization.initialLoadingAnimationCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.initialLoadingAnimationCustomization.foregroundColor = primaryColor
            currentCustomization.initialLoadingAnimationCustomization.defaultAnimationBackgroundColor = primaryColor.withAlphaComponent(0.2)
            currentCustomization.initialLoadingAnimationCustomization.defaultAnimationForegroundColor = primaryColor
            currentCustomization.initialLoadingAnimationCustomization.animationRelativeScale = 1.0
            currentCustomization.initialLoadingAnimationCustomization.messageFont = font!.withSize(20)
            // Orientation Screen Customization
            currentCustomization.orientationScreenCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.orientationScreenCustomization.foregroundColor = primaryColor
            currentCustomization.orientationScreenCustomization.iconImage = nil
            currentCustomization.orientationScreenCustomization.messageFont = font!.withSize(20)

            // Guidance Customization -- Text Style Overrides
            // Ready Screen Header
            currentCustomization.guidanceCustomization.readyScreenHeaderFont = font!
            currentCustomization.guidanceCustomization.readyScreenHeaderTextColor = primaryColor
            // Ready Screen Subtext
            currentCustomization.guidanceCustomization.readyScreenSubtextFont = font!
            currentCustomization.guidanceCustomization.readyScreenSubtextTextColor = primaryColorLight
            // Retry Screen Header
            currentCustomization.guidanceCustomization.retryScreenHeaderFont = font!
            currentCustomization.guidanceCustomization.retryScreenHeaderTextColor = primaryColor
            // Retry Screen Subtext
            currentCustomization.guidanceCustomization.retryScreenSubtextFont = font!
            currentCustomization.guidanceCustomization.retryScreenSubtextTextColor = primaryColorLight
        }
        else if theme == "Well-Rounded" {
            let primaryColor = UIColor(red: 0.035, green: 0.710, blue: 0.639, alpha: 1) // green
            let primaryColorLight = UIColor(red: 0.192, green: 0.867, blue: 0.796, alpha: 1) // lighter green
            let primaryColorDark = UIColor(red: 0, green: 0.553, blue: 0.482, alpha: 1) // darker green
            let backgroundColor = UIColor.white
            let backgroundLayer = CAGradientLayer.init()
            let buttonTextDisabledColor = UIColor(red: 0.843, green: 0.843, blue: 0.843, alpha: 1)

            backgroundLayer.colors = [primaryColor.cgColor, primaryColor.cgColor]
            backgroundLayer.locations = [0,1]
            backgroundLayer.startPoint = CGPoint.init(x: 0, y: 0)
            backgroundLayer.endPoint = CGPoint.init(x: 1, y: 0)
            
            let headerFont = UIFont.systemFont(ofSize: 26, weight: UIFont.Weight.init(0.3))
            let subtextFont = UIFont.systemFont(ofSize: 16, weight: .light)
            let buttonFont = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.init(0.4))
            
            let feedbackShadow: FaceTecShadow? = FaceTecShadow(color: UIColor.black, opacity: 0.5, radius: 2, offset: CGSize(width: 0, height: 0), insets: UIEdgeInsets(top: 1, left: -1, bottom: -1, right: -1))
            let frameShadow: FaceTecShadow? = FaceTecShadow(color: UIColor.black, opacity: 0.5, radius: 4, offset: CGSize(width: 0, height: 0), insets: UIEdgeInsets(top: 1, left: -1, bottom: -1, right: -1))
            let scrollIndicatorShadow: FaceTecShadow? = FaceTecShadow(color: UIColor.black, opacity: 0.5, radius: 2, offset: CGSize(width: 0, height: 0), insets: UIEdgeInsets(top: 1, left: -1, bottom: -1, right: -1))
            
            //
            // NOTE: For this theme, the Result Screen's activity indicator and result animations are overriden by the use of the FaceTecCustomAnimationDelegate and its methods to specify a custom UIView to display for the individual animations.
            //
            
            // Overlay Customization
            currentCustomization.overlayCustomization.backgroundColor = UIColor.clear
            currentCustomization.overlayCustomization.showBrandingImage = false
            currentCustomization.overlayCustomization.brandingImage = nil
            // Guidance Customization
            currentCustomization.guidanceCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.guidanceCustomization.foregroundColor = primaryColor
            currentCustomization.guidanceCustomization.headerFont = headerFont
            currentCustomization.guidanceCustomization.subtextFont = subtextFont
            currentCustomization.guidanceCustomization.buttonFont = buttonFont
            currentCustomization.guidanceCustomization.buttonTextNormalColor = backgroundColor
            currentCustomization.guidanceCustomization.buttonBackgroundNormalColor = primaryColor
            currentCustomization.guidanceCustomization.buttonTextHighlightColor = backgroundColor
            currentCustomization.guidanceCustomization.buttonBackgroundHighlightColor = primaryColorLight
            currentCustomization.guidanceCustomization.buttonTextDisabledColor = buttonTextDisabledColor
            currentCustomization.guidanceCustomization.buttonBackgroundDisabledColor =  primaryColorDark
            currentCustomization.guidanceCustomization.buttonBorderColor = UIColor.clear
            currentCustomization.guidanceCustomization.buttonBorderWidth = 0
            currentCustomization.guidanceCustomization.buttonCornerRadius = 25
            currentCustomization.guidanceCustomization.readyScreenOvalFillColor = UIColor.clear
            currentCustomization.guidanceCustomization.readyScreenTextBackgroundColor = backgroundColor
            currentCustomization.guidanceCustomization.readyScreenTextBackgroundCornerRadius = 5
            currentCustomization.guidanceCustomization.retryScreenImageBorderColor = primaryColor
            currentCustomization.guidanceCustomization.retryScreenImageBorderWidth = 2
            currentCustomization.guidanceCustomization.retryScreenImageCornerRadius = 10
            currentCustomization.guidanceCustomization.retryScreenOvalStrokeColor = backgroundColor
            currentCustomization.guidanceCustomization.retryScreenSlideshowImages = []
            currentCustomization.guidanceCustomization.retryScreenSlideshowInterval = 1500
            currentCustomization.guidanceCustomization.enableRetryScreenSlideshowShuffle = true
            currentCustomization.guidanceCustomization.cameraPermissionsScreenImage = UIImage(named: "camera_green")
            // ID Scan Customization
            currentCustomization.idScanCustomization.showSelectionScreenDocumentImage = true
            currentCustomization.idScanCustomization.selectionScreenDocumentImage = UIImage(named: "document_green")
            currentCustomization.idScanCustomization.selectionScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.reviewScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.captureScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.reviewScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.selectionScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.captureScreenFocusMessageTextColor = primaryColor
            currentCustomization.idScanCustomization.headerFont = headerFont
            currentCustomization.idScanCustomization.subtextFont = subtextFont
            currentCustomization.idScanCustomization.buttonFont = buttonFont
            currentCustomization.idScanCustomization.buttonTextNormalColor = backgroundColor
            currentCustomization.idScanCustomization.buttonBackgroundNormalColor = primaryColor
            currentCustomization.idScanCustomization.buttonTextHighlightColor = backgroundColor
            currentCustomization.idScanCustomization.buttonBackgroundHighlightColor = primaryColorLight
            currentCustomization.idScanCustomization.buttonTextDisabledColor = buttonTextDisabledColor
            currentCustomization.idScanCustomization.buttonBackgroundDisabledColor =  primaryColorDark
            currentCustomization.idScanCustomization.buttonBorderColor = UIColor.clear
            currentCustomization.idScanCustomization.buttonBorderWidth = 0
            currentCustomization.idScanCustomization.buttonCornerRadius = 25
            currentCustomization.idScanCustomization.captureScreenTextBackgroundColor = backgroundColor
            currentCustomization.idScanCustomization.captureScreenTextBackgroundBorderColor = primaryColor
            currentCustomization.idScanCustomization.captureScreenTextBackgroundBorderWidth = 2
            currentCustomization.idScanCustomization.captureScreenTextBackgroundCornerRadius = 5
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundColor = backgroundColor
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundBorderColor = primaryColor
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundBorderWidth = 2
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundCornerRadius = 5
            currentCustomization.idScanCustomization.captureScreenBackgroundColor = backgroundColor
            currentCustomization.idScanCustomization.captureFrameStrokeColor = primaryColor
            currentCustomization.idScanCustomization.captureFrameStrokeWith = 2
            currentCustomization.idScanCustomization.captureFrameCornerRadius = 12
            currentCustomization.idScanCustomization.activeTorchButtonImage = UIImage(named: "torch_active_black")
            currentCustomization.idScanCustomization.inactiveTorchButtonImage = UIImage(named: "torch_inactive_black")
            currentCustomization.idScanCustomization.additionalReviewScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.additionalReviewScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.additionalReviewScreenImage = nil
            currentCustomization.idScanCustomization.idFeedbackScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.idFeedbackScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.idFeedbackScreenFlipIDFrontImage = nil
            currentCustomization.idScanCustomization.idFeedbackScreenFlipIDBackImage = nil
            currentCustomization.idScanCustomization.additionalReviewScreenAnimationDisplayTime = 2.0;
            currentCustomization.idScanCustomization.idFeedbackScreenAnimationDisplayTime = 2.0;
            currentCustomization.idScanCustomization.nfcScreenAnimationDisplayTime = 2.0;
            currentCustomization.idScanCustomization.enableAdditionalReviewTag = true
            currentCustomization.idScanCustomization.additionalReviewTagImage = UIImage(named: "warning_greeen")
            currentCustomization.idScanCustomization.additionalReviewTagImageColor = primaryColor
            currentCustomization.idScanCustomization.additionalReviewTagTextColor = primaryColor
            // OCR Confirmation Screen Customization
            currentCustomization.ocrConfirmationCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.ocrConfirmationCustomization.mainHeaderDividerLineColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.mainHeaderDividerLineWidth = 2
            currentCustomization.ocrConfirmationCustomization.mainHeaderFont = headerFont
            currentCustomization.ocrConfirmationCustomization.sectionHeaderFont = headerFont
            currentCustomization.ocrConfirmationCustomization.fieldLabelFont = subtextFont
            currentCustomization.ocrConfirmationCustomization.fieldValueFont = subtextFont
            currentCustomization.ocrConfirmationCustomization.inputFieldFont = subtextFont
            currentCustomization.ocrConfirmationCustomization.inputFieldPlaceholderFont = subtextFont
            currentCustomization.ocrConfirmationCustomization.mainHeaderTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.sectionHeaderTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.fieldLabelTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.fieldValueTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.inputFieldTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.inputFieldPlaceholderTextColor = primaryColor.withAlphaComponent(0.4)
            currentCustomization.ocrConfirmationCustomization.inputFieldBackgroundColor = UIColor.clear
            currentCustomization.ocrConfirmationCustomization.inputFieldBorderColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.inputFieldBorderWidth = 1
            currentCustomization.ocrConfirmationCustomization.inputFieldCornerRadius = 15
            currentCustomization.ocrConfirmationCustomization.showInputFieldBottomBorderOnly = false
            currentCustomization.ocrConfirmationCustomization.buttonFont = buttonFont
            currentCustomization.ocrConfirmationCustomization.buttonTextNormalColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.buttonBackgroundNormalColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.buttonTextHighlightColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.buttonBackgroundHighlightColor = primaryColorLight
            currentCustomization.ocrConfirmationCustomization.buttonTextDisabledColor = buttonTextDisabledColor
            currentCustomization.ocrConfirmationCustomization.buttonBackgroundDisabledColor =  primaryColorDark
            currentCustomization.ocrConfirmationCustomization.buttonBorderColor = UIColor.clear
            currentCustomization.ocrConfirmationCustomization.buttonBorderWidth = 0
            currentCustomization.ocrConfirmationCustomization.buttonCornerRadius = 25
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundNormalColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundHighlightColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundNormalColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundHighlightColor = primaryColorLight
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBorderColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBorderWidth = 2
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorCornerRadius = -1
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorFont = buttonFont
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorShadow = scrollIndicatorShadow
            currentCustomization.ocrConfirmationCustomization.enableScrollIndicator = true
            currentCustomization.ocrConfirmationCustomization.enableScrollIndicatorTextAnimation = true
            currentCustomization.ocrConfirmationCustomization.enableFixedConfirmButton = false
            currentCustomization.ocrConfirmationCustomization.showScrollIndicatorImage = true
            // Result Screen Customization
            currentCustomization.resultScreenCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.resultScreenCustomization.foregroundColor = primaryColor
            currentCustomization.resultScreenCustomization.messageFont = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.init(0.3))
            currentCustomization.resultScreenCustomization.activityIndicatorColor = primaryColor
            currentCustomization.resultScreenCustomization.customActivityIndicatorImage = nil
            currentCustomization.resultScreenCustomization.customActivityIndicatorRotationInterval = 1000
            currentCustomization.resultScreenCustomization.resultAnimationBackgroundColor = UIColor.clear
            currentCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundColor = UIColor.clear
            currentCustomization.resultScreenCustomization.resultAnimationForegroundColor = backgroundColor
            currentCustomization.resultScreenCustomization.resultAnimationUnsuccessForegroundColor = backgroundColor
            currentCustomization.resultScreenCustomization.resultAnimationIDScanSuccessForegroundColor = backgroundColor
            currentCustomization.resultScreenCustomization.resultAnimationNFCSuccessForegroundColor = backgroundColor
            currentCustomization.resultScreenCustomization.resultAnimationSuccessBackgroundImage = nil
            currentCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundImage = nil
            currentCustomization.resultScreenCustomization.showUploadProgressBar = false
            currentCustomization.resultScreenCustomization.uploadProgressTrackColor = UIColor.black.withAlphaComponent(0.2)
            currentCustomization.resultScreenCustomization.uploadProgressFillColor = primaryColor
            currentCustomization.resultScreenCustomization.animationRelativeScale = 2.0
            currentCustomization.resultScreenCustomization.resultAnimationDisplayTime = 2.0
            currentCustomization.resultScreenCustomization.faceScanStillUploadingMessageDelayTime = 6.0
            currentCustomization.resultScreenCustomization.idScanStillUploadingMessageDelayTime = 8.0
            // Feedback Customization
            currentCustomization.feedbackCustomization.backgroundColor = backgroundLayer
            currentCustomization.feedbackCustomization.textColor = backgroundColor
            currentCustomization.feedbackCustomization.textFont = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.init(0.3))
            currentCustomization.feedbackCustomization.cornerRadius = 5
            currentCustomization.feedbackCustomization.shadow = feedbackShadow
            // Frame Customization
            currentCustomization.frameCustomization.backgroundColor = backgroundColor
            currentCustomization.frameCustomization.borderColor = primaryColor
            currentCustomization.frameCustomization.borderWidth = 2
            currentCustomization.frameCustomization.cornerRadius = 20
            currentCustomization.frameCustomization.shadow = frameShadow
            // Oval Customization
            currentCustomization.ovalCustomization.strokeColor = primaryColor
            currentCustomization.ovalCustomization.progressColor1 = primaryColor
            currentCustomization.ovalCustomization.progressColor2 = primaryColor
            // Cancel Button Customization
            currentCustomization.cancelButtonCustomization.customImage = UIImage(named: "cancel_round_green")
            currentCustomization.cancelButtonCustomization.location = FaceTecCancelButtonLocation.topLeft
            currentCustomization.cancelButtonCustomization.hideForCameraPermissions = true
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentCustomization.initialLoadingAnimationCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.initialLoadingAnimationCustomization.foregroundColor = primaryColor
            currentCustomization.initialLoadingAnimationCustomization.defaultAnimationBackgroundColor = primaryColor.withAlphaComponent(0.2)
            currentCustomization.initialLoadingAnimationCustomization.defaultAnimationForegroundColor = primaryColor
            currentCustomization.initialLoadingAnimationCustomization.animationRelativeScale = 2.0
            currentCustomization.initialLoadingAnimationCustomization.messageFont = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.init(0.3))
            // Orientation Screen Customization
            currentCustomization.orientationScreenCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.orientationScreenCustomization.foregroundColor = primaryColor
            currentCustomization.orientationScreenCustomization.iconImage = nil
            currentCustomization.orientationScreenCustomization.messageFont = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.init(0.3))
        }
        else if theme == "Bitcoin Exchange" {
            let primaryColor = UIColor(red: 0.969, green: 0.588, blue: 0.204, alpha: 1) // orange
            let primaryColorLight = UIColor(red: 0.976, green: 0.702, blue: 0.424, alpha: 1) // light orange
            let primaryColorDark = UIColor(red: 0.769, green: 0.4, blue: 0.031, alpha: 1) // dark orange
            let secondaryColor = UIColor(red: 1, green: 1, blue: 0.188, alpha: 1) // yellow
            let backgroundColor = UIColor(red: 0.259, green: 0.259, blue: 0.259, alpha: 1) // dark grey
            let backgroundColorLight = UIColor(red: 0.459, green: 0.459, blue: 0.459, alpha: 1) // grey

            let backgroundLayer = CAGradientLayer.init()
            backgroundLayer.colors = [primaryColor.cgColor, primaryColor.cgColor]
            backgroundLayer.locations = [0,1]
            backgroundLayer.startPoint = CGPoint.init(x: 0, y: 0)
            backgroundLayer.endPoint = CGPoint.init(x: 1, y: 0)
            
            let headerFont = UIFont.systemFont(ofSize: 26, weight: UIFont.Weight.init(0.3))
            let subtextFont = UIFont.systemFont(ofSize: 16, weight: .light)
            let buttonFont = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.init(0.4))
            
            let feedbackShadow: FaceTecShadow? = FaceTecShadow(color: backgroundColor, opacity: 1, radius: 3, offset: CGSize(width: 0, height: 2), insets: UIEdgeInsets(top: 1, left: -1, bottom: -1, right: -1))
            let frameShadow: FaceTecShadow? = FaceTecShadow(color: backgroundColor, opacity: 1, radius: 3, offset: CGSize(width: 0, height: 2), insets: UIEdgeInsets(top: 1, left: -1, bottom: -1, right: -1))
            let scrollIndicatorShadow: FaceTecShadow? = FaceTecShadow(color: backgroundColor, opacity: 1, radius: 3, offset: CGSize(width: 0, height: 2), insets: UIEdgeInsets(top: 1, left: -1, bottom: -1, right: -1))
            
            // Overlay Customization
            currentCustomization.overlayCustomization.backgroundColor = UIColor.clear
            currentCustomization.overlayCustomization.showBrandingImage = true
            currentCustomization.overlayCustomization.brandingImage = UIImage(named: "bitcoin_exchange_logo")
            // Guidance Customization
            currentCustomization.guidanceCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.guidanceCustomization.foregroundColor = primaryColor
            currentCustomization.guidanceCustomization.headerFont = headerFont
            currentCustomization.guidanceCustomization.subtextFont = subtextFont
            currentCustomization.guidanceCustomization.buttonFont = buttonFont
            currentCustomization.guidanceCustomization.buttonTextNormalColor = backgroundColor
            currentCustomization.guidanceCustomization.buttonBackgroundNormalColor = primaryColor
            currentCustomization.guidanceCustomization.buttonTextHighlightColor = backgroundColor
            currentCustomization.guidanceCustomization.buttonBackgroundHighlightColor = primaryColorDark
            currentCustomization.guidanceCustomization.buttonTextDisabledColor = backgroundColorLight
            currentCustomization.guidanceCustomization.buttonBackgroundDisabledColor = primaryColorLight
            currentCustomization.guidanceCustomization.buttonBorderColor = UIColor.clear
            currentCustomization.guidanceCustomization.buttonBorderWidth = 0
            currentCustomization.guidanceCustomization.buttonCornerRadius = 5
            currentCustomization.guidanceCustomization.readyScreenOvalFillColor = UIColor.clear
            currentCustomization.guidanceCustomization.readyScreenTextBackgroundColor = backgroundColor
            currentCustomization.guidanceCustomization.readyScreenTextBackgroundCornerRadius = 5
            currentCustomization.guidanceCustomization.retryScreenImageBorderColor = primaryColor
            currentCustomization.guidanceCustomization.retryScreenImageBorderWidth = 2
            currentCustomization.guidanceCustomization.retryScreenImageCornerRadius = 5
            currentCustomization.guidanceCustomization.retryScreenOvalStrokeColor = primaryColor
            currentCustomization.guidanceCustomization.retryScreenSlideshowImages = []
            currentCustomization.guidanceCustomization.retryScreenSlideshowInterval = 1500
            currentCustomization.guidanceCustomization.enableRetryScreenSlideshowShuffle = true
            currentCustomization.guidanceCustomization.cameraPermissionsScreenImage = UIImage(named: "camera_orange")
            // ID Scan Customization
            currentCustomization.idScanCustomization.showSelectionScreenDocumentImage = true
            currentCustomization.idScanCustomization.selectionScreenDocumentImage = UIImage(named: "document_orange")
            currentCustomization.idScanCustomization.selectionScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.reviewScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.captureScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.reviewScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.selectionScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.captureScreenFocusMessageTextColor = primaryColor
            currentCustomization.idScanCustomization.headerFont = headerFont
            currentCustomization.idScanCustomization.subtextFont = subtextFont
            currentCustomization.idScanCustomization.buttonFont = buttonFont
            currentCustomization.idScanCustomization.buttonTextNormalColor = backgroundColor
            currentCustomization.idScanCustomization.buttonBackgroundNormalColor = primaryColor
            currentCustomization.idScanCustomization.buttonTextHighlightColor = backgroundColor
            currentCustomization.idScanCustomization.buttonBackgroundHighlightColor = primaryColorDark
            currentCustomization.idScanCustomization.buttonTextDisabledColor = backgroundColorLight
            currentCustomization.idScanCustomization.buttonBackgroundDisabledColor = primaryColorLight
            currentCustomization.idScanCustomization.buttonBorderColor = UIColor.clear
            currentCustomization.idScanCustomization.buttonBorderWidth = 0
            currentCustomization.idScanCustomization.buttonCornerRadius = 5
            currentCustomization.idScanCustomization.captureScreenTextBackgroundColor = backgroundColor
            currentCustomization.idScanCustomization.captureScreenTextBackgroundBorderColor = primaryColor
            currentCustomization.idScanCustomization.captureScreenTextBackgroundBorderWidth = 0
            currentCustomization.idScanCustomization.captureScreenTextBackgroundCornerRadius = 8
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundColor = backgroundColor
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundBorderColor = primaryColor
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundBorderWidth = 0
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundCornerRadius = 8
            currentCustomization.idScanCustomization.captureScreenBackgroundColor = backgroundColor
            currentCustomization.idScanCustomization.captureFrameStrokeColor = primaryColor
            currentCustomization.idScanCustomization.captureFrameStrokeWith = 2
            currentCustomization.idScanCustomization.captureFrameCornerRadius = 12
            currentCustomization.idScanCustomization.activeTorchButtonImage = UIImage(named: "torch_active_orange")
            currentCustomization.idScanCustomization.inactiveTorchButtonImage = UIImage(named: "torch_inactive_orange")
            currentCustomization.idScanCustomization.additionalReviewScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.additionalReviewScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.additionalReviewScreenImage = nil
            currentCustomization.idScanCustomization.idFeedbackScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.idFeedbackScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.idFeedbackScreenFlipIDFrontImage = nil
            currentCustomization.idScanCustomization.idFeedbackScreenFlipIDBackImage = nil
            currentCustomization.idScanCustomization.additionalReviewScreenAnimationDisplayTime = 2.0;
            currentCustomization.idScanCustomization.idFeedbackScreenAnimationDisplayTime = 2.0;
            currentCustomization.idScanCustomization.nfcScreenAnimationDisplayTime = 2.0;
            currentCustomization.idScanCustomization.enableAdditionalReviewTag = true
            currentCustomization.idScanCustomization.additionalReviewTagImage = UIImage(named: "warning_orange")
            currentCustomization.idScanCustomization.additionalReviewTagImageColor = primaryColor
            currentCustomization.idScanCustomization.additionalReviewTagTextColor = primaryColor
            // OCR Confirmation Screen Customization
            currentCustomization.ocrConfirmationCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.ocrConfirmationCustomization.mainHeaderDividerLineColor = secondaryColor
            currentCustomization.ocrConfirmationCustomization.mainHeaderDividerLineWidth = 1
            currentCustomization.ocrConfirmationCustomization.mainHeaderFont = headerFont
            currentCustomization.ocrConfirmationCustomization.sectionHeaderFont = headerFont
            currentCustomization.ocrConfirmationCustomization.fieldLabelFont = subtextFont
            currentCustomization.ocrConfirmationCustomization.fieldValueFont = subtextFont
            currentCustomization.ocrConfirmationCustomization.inputFieldFont = subtextFont
            currentCustomization.ocrConfirmationCustomization.inputFieldPlaceholderFont = subtextFont
            currentCustomization.ocrConfirmationCustomization.mainHeaderTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.sectionHeaderTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.fieldLabelTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.fieldValueTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.inputFieldTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.inputFieldPlaceholderTextColor = primaryColor.withAlphaComponent(0.4)
            currentCustomization.ocrConfirmationCustomization.inputFieldBackgroundColor = UIColor.clear
            currentCustomization.ocrConfirmationCustomization.inputFieldBorderColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.inputFieldBorderWidth = 1
            currentCustomization.ocrConfirmationCustomization.inputFieldCornerRadius = 5
            currentCustomization.ocrConfirmationCustomization.showInputFieldBottomBorderOnly = false
            currentCustomization.ocrConfirmationCustomization.buttonFont = buttonFont
            currentCustomization.ocrConfirmationCustomization.buttonTextNormalColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.buttonBackgroundNormalColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.buttonTextHighlightColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.buttonBackgroundHighlightColor = primaryColorDark
            currentCustomization.ocrConfirmationCustomization.buttonTextDisabledColor = backgroundColorLight
            currentCustomization.ocrConfirmationCustomization.buttonBackgroundDisabledColor = primaryColorLight
            currentCustomization.ocrConfirmationCustomization.buttonBorderColor = UIColor.clear
            currentCustomization.ocrConfirmationCustomization.buttonBorderWidth = 0
            currentCustomization.ocrConfirmationCustomization.buttonCornerRadius = 5
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundNormalColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundHighlightColor = primaryColorDark
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundNormalColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundHighlightColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBorderColor = UIColor.clear
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBorderWidth = 0
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorCornerRadius = -1
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorFont = buttonFont
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorShadow = scrollIndicatorShadow
            currentCustomization.ocrConfirmationCustomization.enableScrollIndicator = true
            currentCustomization.ocrConfirmationCustomization.enableScrollIndicatorTextAnimation = true
            currentCustomization.ocrConfirmationCustomization.enableFixedConfirmButton = true
            currentCustomization.ocrConfirmationCustomization.showScrollIndicatorImage = false
            // Result Screen Customization
            currentCustomization.resultScreenCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.resultScreenCustomization.foregroundColor = primaryColor
            currentCustomization.resultScreenCustomization.messageFont = headerFont
            currentCustomization.resultScreenCustomization.activityIndicatorColor = primaryColor
            currentCustomization.resultScreenCustomization.customActivityIndicatorImage = UIImage(named: "activity_indicator_orange")
            currentCustomization.resultScreenCustomization.customActivityIndicatorRotationInterval = 1500
            currentCustomization.resultScreenCustomization.resultAnimationBackgroundColor = primaryColor
            currentCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundColor = primaryColor
            currentCustomization.resultScreenCustomization.resultAnimationForegroundColor = backgroundColor
            currentCustomization.resultScreenCustomization.resultAnimationUnsuccessForegroundColor = backgroundColor
            currentCustomization.resultScreenCustomization.resultAnimationIDScanSuccessForegroundColor = primaryColor
            currentCustomization.resultScreenCustomization.resultAnimationNFCSuccessForegroundColor = primaryColor
            currentCustomization.resultScreenCustomization.resultAnimationSuccessBackgroundImage = nil
            currentCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundImage = nil
            currentCustomization.resultScreenCustomization.showUploadProgressBar = true
            currentCustomization.resultScreenCustomization.uploadProgressTrackColor = UIColor.black.withAlphaComponent(0.2)
            currentCustomization.resultScreenCustomization.uploadProgressFillColor = primaryColor
            currentCustomization.resultScreenCustomization.animationRelativeScale = 1.0
            currentCustomization.resultScreenCustomization.resultAnimationDisplayTime = 2.5
            currentCustomization.resultScreenCustomization.faceScanStillUploadingMessageDelayTime = 6.0
            currentCustomization.resultScreenCustomization.idScanStillUploadingMessageDelayTime = 8.0
            // Feedback Customization
            currentCustomization.feedbackCustomization.backgroundColor = backgroundLayer
            currentCustomization.feedbackCustomization.textColor = backgroundColor
            currentCustomization.feedbackCustomization.textFont = headerFont
            currentCustomization.feedbackCustomization.cornerRadius = 5
            currentCustomization.feedbackCustomization.shadow = feedbackShadow
            // Frame Customization
            currentCustomization.frameCustomization.backgroundColor = backgroundColor
            currentCustomization.frameCustomization.borderColor = backgroundColor
            currentCustomization.frameCustomization.borderWidth = 2
            currentCustomization.frameCustomization.cornerRadius = 5
            currentCustomization.frameCustomization.shadow = frameShadow
            // Oval Customization
            currentCustomization.ovalCustomization.strokeColor = primaryColor
            currentCustomization.ovalCustomization.progressColor1 = secondaryColor
            currentCustomization.ovalCustomization.progressColor2 = secondaryColor
            // Cancel Button Customization
            currentCustomization.cancelButtonCustomization.customImage = UIImage(named: "single_chevron_left_orange")
            currentCustomization.cancelButtonCustomization.location = FaceTecCancelButtonLocation.topLeft
            currentCustomization.cancelButtonCustomization.hideForCameraPermissions = true
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentCustomization.initialLoadingAnimationCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.initialLoadingAnimationCustomization.foregroundColor = primaryColor
            currentCustomization.initialLoadingAnimationCustomization.defaultAnimationBackgroundColor = backgroundColorLight
            currentCustomization.initialLoadingAnimationCustomization.defaultAnimationForegroundColor = primaryColor
            currentCustomization.initialLoadingAnimationCustomization.animationRelativeScale = 1.0
            currentCustomization.initialLoadingAnimationCustomization.messageFont = headerFont
            // Orientation Screen Customization
            currentCustomization.orientationScreenCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.orientationScreenCustomization.foregroundColor = primaryColor
            currentCustomization.orientationScreenCustomization.iconImage = nil
            currentCustomization.orientationScreenCustomization.messageFont = headerFont
            
            // Guidance Customization -- Text Style Overrides
            // Ready Screen Header
            currentCustomization.guidanceCustomization.readyScreenHeaderFont = headerFont
            currentCustomization.guidanceCustomization.readyScreenHeaderTextColor = primaryColor
            // Ready Screen Subtext
            currentCustomization.guidanceCustomization.readyScreenSubtextFont = subtextFont
            currentCustomization.guidanceCustomization.readyScreenSubtextTextColor = secondaryColor
            // Retry Screen Header
            currentCustomization.guidanceCustomization.retryScreenHeaderFont = headerFont
            currentCustomization.guidanceCustomization.retryScreenHeaderTextColor = primaryColor
            // Retry Screen Subtext
            currentCustomization.guidanceCustomization.retryScreenSubtextFont = subtextFont
            currentCustomization.guidanceCustomization.retryScreenSubtextTextColor = secondaryColor
        }
        else if theme == "eKYC" {
            let primaryColor = UIColor(red: 0.929, green: 0.110, blue: 0.141, alpha: 1) // red
            let primaryColorLight = UIColor(red: 0.967, green: 0.580, blue: 0.596, alpha: 1) // lighter red
            let secondaryColor = UIColor.black
            let backgroundColor = UIColor.white
            
            let backgroundLayer = CAGradientLayer.init()
            backgroundLayer.colors = [secondaryColor.cgColor, secondaryColor.cgColor]
            backgroundLayer.locations = [0,1]
            backgroundLayer.startPoint = CGPoint.init(x: 0, y: 0)
            backgroundLayer.endPoint = CGPoint.init(x: 1, y: 0)
            
            let headerFont = UIFont.systemFont(ofSize: 26, weight: UIFont.Weight.init(0.3))
            let subtextFont = UIFont.systemFont(ofSize: 16, weight: .light)
            let buttonFont = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.init(0.4))
            
            let feedbackShadow: FaceTecShadow? = FaceTecShadow(color: primaryColor, opacity: 1, radius: 5, offset: CGSize(width: 0, height: 2), insets: UIEdgeInsets(top: 1, left: -1, bottom: -1, right: -1))
            let frameShadow: FaceTecShadow? = FaceTecShadow(color: primaryColor, opacity: 1, radius: 3, offset: CGSize(width: 0, height: 2), insets: UIEdgeInsets(top: 1, left: -1, bottom: -1, right: -1))
            let scrollIndicatorShadow: FaceTecShadow? = FaceTecShadow(color: primaryColor, opacity: 1, radius: 5, offset: CGSize(width: 0, height: 2), insets: UIEdgeInsets(top: 1, left: -1, bottom: -1, right: -1))
            
            // Overlay Customization
            currentCustomization.overlayCustomization.backgroundColor = UIColor.clear
            currentCustomization.overlayCustomization.showBrandingImage = true
            currentCustomization.overlayCustomization.brandingImage = UIImage(named: "ekyc_logo")
            // Guidance Customization
            currentCustomization.guidanceCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.guidanceCustomization.foregroundColor = secondaryColor
            currentCustomization.guidanceCustomization.headerFont = headerFont
            currentCustomization.guidanceCustomization.subtextFont = subtextFont
            currentCustomization.guidanceCustomization.buttonFont = buttonFont
            currentCustomization.guidanceCustomization.buttonTextNormalColor = primaryColor
            currentCustomization.guidanceCustomization.buttonBackgroundNormalColor = UIColor.clear
            currentCustomization.guidanceCustomization.buttonTextHighlightColor = backgroundColor
            currentCustomization.guidanceCustomization.buttonBackgroundHighlightColor = primaryColor
            currentCustomization.guidanceCustomization.buttonTextDisabledColor = primaryColor.withAlphaComponent(0.3)
            currentCustomization.guidanceCustomization.buttonBackgroundDisabledColor = backgroundColor
            currentCustomization.guidanceCustomization.buttonBorderColor = primaryColor
            currentCustomization.guidanceCustomization.buttonBorderWidth = 2
            currentCustomization.guidanceCustomization.buttonCornerRadius = 8
            currentCustomization.guidanceCustomization.readyScreenOvalFillColor = UIColor.clear
            currentCustomization.guidanceCustomization.readyScreenTextBackgroundColor = backgroundColor
            currentCustomization.guidanceCustomization.readyScreenTextBackgroundCornerRadius = 3
            currentCustomization.guidanceCustomization.retryScreenImageBorderColor = primaryColor
            currentCustomization.guidanceCustomization.retryScreenImageBorderWidth = 2
            currentCustomization.guidanceCustomization.retryScreenImageCornerRadius = 3
            currentCustomization.guidanceCustomization.retryScreenOvalStrokeColor = primaryColor
            currentCustomization.guidanceCustomization.retryScreenSlideshowImages = retryScreenSlideshowImages
            currentCustomization.guidanceCustomization.retryScreenSlideshowInterval = 1500
            currentCustomization.guidanceCustomization.enableRetryScreenSlideshowShuffle = true
            currentCustomization.guidanceCustomization.cameraPermissionsScreenImage = UIImage(named: "camera_red")
            // ID Scan Customization
            currentCustomization.idScanCustomization.showSelectionScreenDocumentImage = false
            currentCustomization.idScanCustomization.selectionScreenDocumentImage = nil
            currentCustomization.idScanCustomization.selectionScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.reviewScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.captureScreenForegroundColor = backgroundColor
            currentCustomization.idScanCustomization.reviewScreenForegroundColor = backgroundColor
            currentCustomization.idScanCustomization.selectionScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.captureScreenFocusMessageTextColor = secondaryColor
            currentCustomization.idScanCustomization.headerFont = headerFont
            currentCustomization.idScanCustomization.subtextFont = subtextFont
            currentCustomization.idScanCustomization.buttonFont = buttonFont
            currentCustomization.idScanCustomization.buttonTextNormalColor = primaryColor
            currentCustomization.idScanCustomization.buttonBackgroundNormalColor = UIColor.clear
            currentCustomization.idScanCustomization.buttonTextHighlightColor = backgroundColor
            currentCustomization.idScanCustomization.buttonBackgroundHighlightColor = primaryColor
            currentCustomization.idScanCustomization.buttonTextDisabledColor = primaryColor.withAlphaComponent(0.3)
            currentCustomization.idScanCustomization.buttonBackgroundDisabledColor = backgroundColor
            currentCustomization.idScanCustomization.buttonBorderColor = primaryColor
            currentCustomization.idScanCustomization.buttonBorderWidth = 2
            currentCustomization.idScanCustomization.buttonCornerRadius = 8
            currentCustomization.idScanCustomization.captureScreenTextBackgroundColor = primaryColor
            currentCustomization.idScanCustomization.captureScreenTextBackgroundBorderColor = primaryColor
            currentCustomization.idScanCustomization.captureScreenTextBackgroundBorderWidth = 0
            currentCustomization.idScanCustomization.captureScreenTextBackgroundCornerRadius = 2
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundColor = primaryColor
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundBorderColor = primaryColor
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundBorderWidth = 0
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundCornerRadius = 2
            currentCustomization.idScanCustomization.captureScreenBackgroundColor = backgroundColor
            currentCustomization.idScanCustomization.captureFrameStrokeColor = primaryColor
            currentCustomization.idScanCustomization.captureFrameStrokeWith = 2
            currentCustomization.idScanCustomization.captureFrameCornerRadius = 12
            currentCustomization.idScanCustomization.activeTorchButtonImage = UIImage(named: "torch_active_black")
            currentCustomization.idScanCustomization.inactiveTorchButtonImage = UIImage(named: "torch_inactive_black")
            currentCustomization.idScanCustomization.additionalReviewScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.additionalReviewScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.additionalReviewScreenImage = nil
            currentCustomization.idScanCustomization.idFeedbackScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.idFeedbackScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.idFeedbackScreenFlipIDFrontImage = nil
            currentCustomization.idScanCustomization.idFeedbackScreenFlipIDBackImage = nil
            currentCustomization.idScanCustomization.additionalReviewScreenAnimationDisplayTime = 2.0;
            currentCustomization.idScanCustomization.idFeedbackScreenAnimationDisplayTime = 2.0;
            currentCustomization.idScanCustomization.nfcScreenAnimationDisplayTime = 2.0;
            currentCustomization.idScanCustomization.enableAdditionalReviewTag = true
            currentCustomization.idScanCustomization.additionalReviewTagImage = nil
            currentCustomization.idScanCustomization.additionalReviewTagImageColor = primaryColor
            currentCustomization.idScanCustomization.additionalReviewTagTextColor = secondaryColor
            // OCR Confirmation Screen Customization
            currentCustomization.ocrConfirmationCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.ocrConfirmationCustomization.mainHeaderDividerLineColor = secondaryColor
            currentCustomization.ocrConfirmationCustomization.mainHeaderDividerLineWidth = 2
            currentCustomization.ocrConfirmationCustomization.mainHeaderFont = headerFont
            currentCustomization.ocrConfirmationCustomization.sectionHeaderFont = headerFont
            currentCustomization.ocrConfirmationCustomization.fieldLabelFont = subtextFont
            currentCustomization.ocrConfirmationCustomization.fieldValueFont = subtextFont
            currentCustomization.ocrConfirmationCustomization.inputFieldFont = subtextFont
            currentCustomization.ocrConfirmationCustomization.inputFieldPlaceholderFont = subtextFont
            currentCustomization.ocrConfirmationCustomization.mainHeaderTextColor = secondaryColor
            currentCustomization.ocrConfirmationCustomization.sectionHeaderTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.fieldLabelTextColor = secondaryColor
            currentCustomization.ocrConfirmationCustomization.fieldValueTextColor = secondaryColor
            currentCustomization.ocrConfirmationCustomization.inputFieldTextColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.inputFieldPlaceholderTextColor = backgroundColor.withAlphaComponent(0.4)
            currentCustomization.ocrConfirmationCustomization.inputFieldBackgroundColor = secondaryColor
            currentCustomization.ocrConfirmationCustomization.inputFieldBorderColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.inputFieldBorderWidth = 0
            currentCustomization.ocrConfirmationCustomization.inputFieldCornerRadius = 8
            currentCustomization.ocrConfirmationCustomization.showInputFieldBottomBorderOnly = false
            currentCustomization.ocrConfirmationCustomization.buttonFont = buttonFont
            currentCustomization.ocrConfirmationCustomization.buttonTextNormalColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.buttonBackgroundNormalColor = UIColor.clear
            currentCustomization.ocrConfirmationCustomization.buttonTextHighlightColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.buttonBackgroundHighlightColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.buttonTextDisabledColor = primaryColor.withAlphaComponent(0.3)
            currentCustomization.ocrConfirmationCustomization.buttonBackgroundDisabledColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.buttonBorderColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.buttonBorderWidth = 2
            currentCustomization.ocrConfirmationCustomization.buttonCornerRadius = 8
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundNormalColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundHighlightColor = primaryColorLight
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundNormalColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundHighlightColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBorderColor = UIColor.clear
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBorderWidth = 0
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorCornerRadius = 8
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorFont = buttonFont
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorShadow = scrollIndicatorShadow
            currentCustomization.ocrConfirmationCustomization.enableScrollIndicator = true
            currentCustomization.ocrConfirmationCustomization.enableScrollIndicatorTextAnimation = true
            currentCustomization.ocrConfirmationCustomization.enableFixedConfirmButton = false
            currentCustomization.ocrConfirmationCustomization.showScrollIndicatorImage = true
            // Result Screen Customization
            currentCustomization.resultScreenCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.resultScreenCustomization.foregroundColor = secondaryColor
            currentCustomization.resultScreenCustomization.messageFont = headerFont
            currentCustomization.resultScreenCustomization.activityIndicatorColor = primaryColor
            currentCustomization.resultScreenCustomization.customActivityIndicatorImage = UIImage(named: "activity_indicator_red")
            currentCustomization.resultScreenCustomization.customActivityIndicatorRotationInterval = 1500
            currentCustomization.resultScreenCustomization.resultAnimationBackgroundColor = UIColor.clear
            currentCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundColor = UIColor.clear
            currentCustomization.resultScreenCustomization.resultAnimationForegroundColor = UIColor.clear
            currentCustomization.resultScreenCustomization.resultAnimationUnsuccessForegroundColor = primaryColor
            currentCustomization.resultScreenCustomization.resultAnimationIDScanSuccessForegroundColor = UIColor.clear
            currentCustomization.resultScreenCustomization.resultAnimationNFCSuccessForegroundColor = UIColor.clear
            currentCustomization.resultScreenCustomization.resultAnimationSuccessBackgroundImage = nil
            currentCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundImage = nil
            currentCustomization.resultScreenCustomization.showUploadProgressBar = false
            currentCustomization.resultScreenCustomization.uploadProgressTrackColor = UIColor.black.withAlphaComponent(0.2)
            currentCustomization.resultScreenCustomization.uploadProgressFillColor = primaryColor
            currentCustomization.resultScreenCustomization.animationRelativeScale = 1.0
            currentCustomization.resultScreenCustomization.resultAnimationDisplayTime = 2.0
            currentCustomization.resultScreenCustomization.faceScanStillUploadingMessageDelayTime = 6.0
            currentCustomization.resultScreenCustomization.idScanStillUploadingMessageDelayTime = 8.0
            // Feedback Customization
            currentCustomization.feedbackCustomization.backgroundColor = backgroundLayer
            currentCustomization.feedbackCustomization.textColor = backgroundColor
            currentCustomization.feedbackCustomization.textFont = headerFont
            currentCustomization.feedbackCustomization.cornerRadius = 3
            currentCustomization.feedbackCustomization.shadow = feedbackShadow
            // Frame Customization
            currentCustomization.frameCustomization.backgroundColor = backgroundColor
            currentCustomization.frameCustomization.borderColor = primaryColor
            currentCustomization.frameCustomization.borderWidth = 2
            currentCustomization.frameCustomization.cornerRadius = 8
            currentCustomization.frameCustomization.shadow = frameShadow
            // Oval Customization
            currentCustomization.ovalCustomization.strokeColor = primaryColor
            currentCustomization.ovalCustomization.progressColor1 = primaryColor.withAlphaComponent(0.5)
            currentCustomization.ovalCustomization.progressColor2 = primaryColor.withAlphaComponent(0.5)
            // Cancel Button Customization
            currentCustomization.cancelButtonCustomization.customImage = UIImage(named: "cancel_box_red")
            currentCustomization.cancelButtonCustomization.location = FaceTecCancelButtonLocation.topRight
            currentCustomization.cancelButtonCustomization.hideForCameraPermissions = true
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentCustomization.initialLoadingAnimationCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.initialLoadingAnimationCustomization.foregroundColor = secondaryColor
            currentCustomization.initialLoadingAnimationCustomization.defaultAnimationBackgroundColor = backgroundColor
            currentCustomization.initialLoadingAnimationCustomization.defaultAnimationForegroundColor = primaryColor
            currentCustomization.initialLoadingAnimationCustomization.animationRelativeScale = 1.0
            currentCustomization.initialLoadingAnimationCustomization.messageFont = headerFont
            // Orientation Screen Customization
            currentCustomization.orientationScreenCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.orientationScreenCustomization.foregroundColor = secondaryColor
            currentCustomization.orientationScreenCustomization.iconImage = nil
            currentCustomization.orientationScreenCustomization.messageFont = headerFont
        }
        else if theme == "Sample Bank" {
            let primaryColor = UIColor.white
            let primaryColorLight = UIColor.white.withAlphaComponent(0.8)
            let backgroundColor = UIColor(red: 0.114, green: 0.090, blue: 0.310, alpha: 1) // navy

            let backgroundLayer = CAGradientLayer.init()
            backgroundLayer.colors = [primaryColor.cgColor, primaryColor.cgColor]
            backgroundLayer.locations = [0,1]
            backgroundLayer.startPoint = CGPoint.init(x: 0, y: 0)
            backgroundLayer.endPoint = CGPoint.init(x: 1, y: 0)
            
            let headerFont = UIFont.systemFont(ofSize: 26, weight: UIFont.Weight.init(0.3))
            let subtextFont = UIFont.systemFont(ofSize: 16, weight: .light)
            let buttonFont = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.init(0.4))
            
            let feedbackShadow: FaceTecShadow? = nil
            let frameShadow: FaceTecShadow? = nil
            let scrollIndicatorShadow: FaceTecShadow? = nil

            // Overlay Customization
            currentCustomization.overlayCustomization.backgroundColor = UIColor.clear
            currentCustomization.overlayCustomization.showBrandingImage = true
            currentCustomization.overlayCustomization.brandingImage = UIImage(named: "sample_bank_logo")
            // Guidance Customization
            currentCustomization.guidanceCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.guidanceCustomization.foregroundColor = primaryColor
            currentCustomization.guidanceCustomization.headerFont = headerFont
            currentCustomization.guidanceCustomization.subtextFont = subtextFont
            currentCustomization.guidanceCustomization.buttonFont = buttonFont
            currentCustomization.guidanceCustomization.buttonTextNormalColor = backgroundColor
            currentCustomization.guidanceCustomization.buttonBackgroundNormalColor = primaryColor
            currentCustomization.guidanceCustomization.buttonTextHighlightColor = backgroundColor
            currentCustomization.guidanceCustomization.buttonBackgroundHighlightColor = primaryColorLight
            currentCustomization.guidanceCustomization.buttonTextDisabledColor = backgroundColor.withAlphaComponent(0.3)
            currentCustomization.guidanceCustomization.buttonBackgroundDisabledColor = UIColor.white
            currentCustomization.guidanceCustomization.buttonBorderColor = primaryColor
            currentCustomization.guidanceCustomization.buttonBorderWidth = 2
            currentCustomization.guidanceCustomization.buttonCornerRadius = 2
            currentCustomization.guidanceCustomization.readyScreenOvalFillColor = UIColor.clear
            currentCustomization.guidanceCustomization.readyScreenTextBackgroundColor = backgroundColor
            currentCustomization.guidanceCustomization.readyScreenTextBackgroundCornerRadius = 2
            currentCustomization.guidanceCustomization.retryScreenImageBorderColor = primaryColor
            currentCustomization.guidanceCustomization.retryScreenImageBorderWidth = 2
            currentCustomization.guidanceCustomization.retryScreenImageCornerRadius = 2
            currentCustomization.guidanceCustomization.retryScreenOvalStrokeColor = primaryColor
            currentCustomization.guidanceCustomization.retryScreenSlideshowImages = retryScreenSlideshowImages
            currentCustomization.guidanceCustomization.retryScreenSlideshowInterval = 1500
            currentCustomization.guidanceCustomization.enableRetryScreenSlideshowShuffle = false
            currentCustomization.guidanceCustomization.cameraPermissionsScreenImage = UIImage(named: "camera_white_navy")
            // ID Scan Customization
            currentCustomization.idScanCustomization.showSelectionScreenDocumentImage = false
            currentCustomization.idScanCustomization.selectionScreenDocumentImage = nil
            currentCustomization.idScanCustomization.selectionScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.reviewScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.captureScreenForegroundColor = backgroundColor
            currentCustomization.idScanCustomization.reviewScreenForegroundColor = backgroundColor
            currentCustomization.idScanCustomization.selectionScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.captureScreenFocusMessageTextColor = primaryColor
            currentCustomization.idScanCustomization.headerFont = headerFont
            currentCustomization.idScanCustomization.subtextFont = subtextFont
            currentCustomization.idScanCustomization.buttonFont = buttonFont
            currentCustomization.idScanCustomization.buttonTextNormalColor = backgroundColor
            currentCustomization.idScanCustomization.buttonBackgroundNormalColor = primaryColor
            currentCustomization.idScanCustomization.buttonTextHighlightColor = backgroundColor
            currentCustomization.idScanCustomization.buttonBackgroundHighlightColor = primaryColorLight
            currentCustomization.idScanCustomization.buttonTextDisabledColor = backgroundColor.withAlphaComponent(0.3)
            currentCustomization.idScanCustomization.buttonBackgroundDisabledColor = UIColor.white
            currentCustomization.idScanCustomization.buttonBorderColor = primaryColor
            currentCustomization.idScanCustomization.buttonBorderWidth = 2
            currentCustomization.idScanCustomization.buttonCornerRadius = 2
            currentCustomization.idScanCustomization.captureScreenTextBackgroundColor = primaryColor
            currentCustomization.idScanCustomization.captureScreenTextBackgroundBorderColor = backgroundColor
            currentCustomization.idScanCustomization.captureScreenTextBackgroundBorderWidth = 2
            currentCustomization.idScanCustomization.captureScreenTextBackgroundCornerRadius = 2
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundColor = primaryColor
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundBorderColor = backgroundColor
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundBorderWidth = 2
            currentCustomization.idScanCustomization.reviewScreenTextBackgroundCornerRadius = 2
            currentCustomization.idScanCustomization.captureScreenBackgroundColor = backgroundColor
            currentCustomization.idScanCustomization.captureFrameStrokeColor = primaryColor
            currentCustomization.idScanCustomization.captureFrameStrokeWith = 2
            currentCustomization.idScanCustomization.captureFrameCornerRadius = 12
            currentCustomization.idScanCustomization.activeTorchButtonImage = UIImage(named: "torch_active_white")
            currentCustomization.idScanCustomization.inactiveTorchButtonImage = UIImage(named: "torch_inactive_white")
            currentCustomization.idScanCustomization.additionalReviewScreenBackgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.idScanCustomization.additionalReviewScreenForegroundColor = primaryColor
            currentCustomization.idScanCustomization.additionalReviewScreenImage = UIImage(named: "review_white")
            currentCustomization.idScanCustomization.additionalReviewScreenAnimationDisplayTime = 2.0;
            currentCustomization.idScanCustomization.idFeedbackScreenAnimationDisplayTime = 2.0;
            currentCustomization.idScanCustomization.nfcScreenAnimationDisplayTime = 2.0;
            currentCustomization.idScanCustomization.enableAdditionalReviewTag = true
            currentCustomization.idScanCustomization.additionalReviewTagImage = UIImage(named: "warning_white")
            currentCustomization.idScanCustomization.additionalReviewTagImageColor = primaryColor
            currentCustomization.idScanCustomization.additionalReviewTagTextColor = primaryColor
            // OCR Confirmation Screen Customization
            currentCustomization.ocrConfirmationCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.ocrConfirmationCustomization.mainHeaderDividerLineColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.mainHeaderDividerLineWidth = 2
            currentCustomization.ocrConfirmationCustomization.mainHeaderFont = headerFont
            currentCustomization.ocrConfirmationCustomization.sectionHeaderFont = headerFont
            currentCustomization.ocrConfirmationCustomization.fieldLabelFont = subtextFont
            currentCustomization.ocrConfirmationCustomization.fieldValueFont = subtextFont
            currentCustomization.ocrConfirmationCustomization.inputFieldFont = subtextFont
            currentCustomization.ocrConfirmationCustomization.inputFieldPlaceholderFont = subtextFont
            currentCustomization.ocrConfirmationCustomization.mainHeaderTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.sectionHeaderTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.fieldLabelTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.fieldValueTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.inputFieldTextColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.inputFieldPlaceholderTextColor = primaryColor.withAlphaComponent(0.4)
            currentCustomization.ocrConfirmationCustomization.inputFieldBackgroundColor = UIColor.clear
            currentCustomization.ocrConfirmationCustomization.inputFieldBorderColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.inputFieldBorderWidth = 2
            currentCustomization.ocrConfirmationCustomization.inputFieldCornerRadius = 0
            currentCustomization.ocrConfirmationCustomization.showInputFieldBottomBorderOnly = true
            currentCustomization.ocrConfirmationCustomization.buttonFont = buttonFont
            currentCustomization.ocrConfirmationCustomization.buttonTextNormalColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.buttonBackgroundNormalColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.buttonTextHighlightColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.buttonBackgroundHighlightColor = primaryColorLight
            currentCustomization.ocrConfirmationCustomization.buttonTextDisabledColor = backgroundColor.withAlphaComponent(0.3)
            currentCustomization.ocrConfirmationCustomization.buttonBackgroundDisabledColor = UIColor.white
            currentCustomization.ocrConfirmationCustomization.buttonBorderColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.buttonBorderWidth = 2
            currentCustomization.ocrConfirmationCustomization.buttonCornerRadius = 2
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundNormalColor = primaryColor
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundHighlightColor = primaryColorLight
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundNormalColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundHighlightColor = backgroundColor
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBorderColor = UIColor.clear
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorBorderWidth = 0
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorCornerRadius = 2
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorFont = buttonFont
            currentCustomization.ocrConfirmationCustomization.scrollIndicatorShadow = scrollIndicatorShadow
            currentCustomization.ocrConfirmationCustomization.enableScrollIndicator = true
            currentCustomization.ocrConfirmationCustomization.enableScrollIndicatorTextAnimation = true
            currentCustomization.ocrConfirmationCustomization.enableFixedConfirmButton = true
            currentCustomization.ocrConfirmationCustomization.showScrollIndicatorImage = false
            // Result Screen Customization
            currentCustomization.resultScreenCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.resultScreenCustomization.foregroundColor = primaryColor
            currentCustomization.resultScreenCustomization.messageFont = headerFont
            currentCustomization.resultScreenCustomization.activityIndicatorColor = primaryColor
            currentCustomization.resultScreenCustomization.customActivityIndicatorImage = UIImage(named: "activity_indicator_white")
            currentCustomization.resultScreenCustomization.customActivityIndicatorRotationInterval = 1000
            currentCustomization.resultScreenCustomization.resultAnimationBackgroundColor = UIColor.clear
            currentCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundColor = UIColor.clear
            currentCustomization.resultScreenCustomization.resultAnimationForegroundColor = primaryColor
            currentCustomization.resultScreenCustomization.resultAnimationUnsuccessForegroundColor = primaryColor
            currentCustomization.resultScreenCustomization.resultAnimationIDScanSuccessForegroundColor = primaryColor
            currentCustomization.resultScreenCustomization.resultAnimationNFCSuccessForegroundColor = primaryColor
            currentCustomization.resultScreenCustomization.resultAnimationSuccessBackgroundImage = UIImage(named: "reticle_white")
            currentCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundImage = UIImage(named: "reticle_white")
            currentCustomization.resultScreenCustomization.showUploadProgressBar = true
            currentCustomization.resultScreenCustomization.uploadProgressTrackColor = UIColor.white.withAlphaComponent(0.2)
            currentCustomization.resultScreenCustomization.uploadProgressFillColor = primaryColor
            currentCustomization.resultScreenCustomization.animationRelativeScale = 1.0
            currentCustomization.resultScreenCustomization.resultAnimationDisplayTime = 2.0
            currentCustomization.resultScreenCustomization.faceScanStillUploadingMessageDelayTime = 6.0
            currentCustomization.resultScreenCustomization.idScanStillUploadingMessageDelayTime = 8.0
            // Feedback Customization
            currentCustomization.feedbackCustomization.backgroundColor = backgroundLayer
            currentCustomization.feedbackCustomization.textColor = backgroundColor
            currentCustomization.feedbackCustomization.textFont = headerFont
            currentCustomization.feedbackCustomization.cornerRadius = 2
            currentCustomization.feedbackCustomization.shadow = feedbackShadow
            // Frame Customization
            currentCustomization.frameCustomization.backgroundColor = backgroundColor
            currentCustomization.frameCustomization.borderColor = primaryColor
            currentCustomization.frameCustomization.borderWidth = 2
            currentCustomization.frameCustomization.cornerRadius = 2
            currentCustomization.frameCustomization.shadow = frameShadow
            // Oval Customization
            currentCustomization.ovalCustomization.strokeColor = primaryColor
            currentCustomization.ovalCustomization.progressColor1 = primaryColor.withAlphaComponent(0.5)
            currentCustomization.ovalCustomization.progressColor2 = primaryColor.withAlphaComponent(0.5)
            // Cancel Button Customization
            currentCustomization.cancelButtonCustomization.customImage = UIImage(named: "cancel_white")
            currentCustomization.cancelButtonCustomization.location = FaceTecCancelButtonLocation.topLeft
            currentCustomization.cancelButtonCustomization.hideForCameraPermissions = false
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentCustomization.initialLoadingAnimationCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.initialLoadingAnimationCustomization.foregroundColor = primaryColor
            currentCustomization.initialLoadingAnimationCustomization.defaultAnimationBackgroundColor = primaryColor.withAlphaComponent(0.2)
            currentCustomization.initialLoadingAnimationCustomization.defaultAnimationForegroundColor = primaryColor
            currentCustomization.initialLoadingAnimationCustomization.animationRelativeScale = 1.0
            currentCustomization.initialLoadingAnimationCustomization.messageFont = headerFont
            // Orientation Screen Customization
            currentCustomization.orientationScreenCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentCustomization.orientationScreenCustomization.foregroundColor = primaryColor
            currentCustomization.orientationScreenCustomization.iconImage = nil
            currentCustomization.orientationScreenCustomization.messageFont = headerFont
        }
        
        return currentCustomization
    }
    
    // Configure UX Color Scheme For Low Light Mode
    class func getLowLightCustomizationForTheme(theme: String) -> FaceTecCustomization {
        var currentLowLightCustomization: FaceTecCustomization = getCustomizationForTheme(theme: theme)
        
        let retryScreenSlideshowImages = [UIImage(named: "FaceTec_ideal_1")!, UIImage(named: "FaceTec_ideal_2")!, UIImage(named: "FaceTec_ideal_3")!, UIImage(named: "FaceTec_ideal_4")!, UIImage(named: "FaceTec_ideal_5")!]

        
        if theme == "Config Wizard Theme" {
            currentLowLightCustomization = Config.retrieveLowLightConfigurationWizardCustomization()
        }
        else if theme == "Bitcoin Exchange" {
            let primaryColor = UIColor(red: 0.969, green: 0.588, blue: 0.204, alpha: 1) // orange
            let primaryColorLight = UIColor(red: 0.976, green: 0.702, blue: 0.424, alpha: 1) // light orange
            let primaryColorDark = UIColor(red: 0.769, green: 0.4, blue: 0.031, alpha: 1) // dark orange
            let secondaryColor = UIColor(red: 1, green: 1, blue: 0.188, alpha: 1) // yellow
            let backgroundColor = UIColor(red: 0.259, green: 0.259, blue: 0.259, alpha: 1) // dark grey
            let backgroundLayer = CAGradientLayer.init()
            backgroundLayer.colors = [backgroundColor.cgColor, backgroundColor.cgColor]
            backgroundLayer.locations = [0,1]
            backgroundLayer.startPoint = CGPoint.init(x: 0, y: 0)
            backgroundLayer.endPoint = CGPoint.init(x: 1, y: 0)
            
            // Overlay Customization
            currentLowLightCustomization.overlayCustomization.brandingImage = UIImage(named: "bitcoin_exchange_logo")
            // Guidance Customization
            currentLowLightCustomization.guidanceCustomization.foregroundColor = backgroundColor
            currentLowLightCustomization.guidanceCustomization.buttonTextNormalColor = UIColor.white
            currentLowLightCustomization.guidanceCustomization.buttonBackgroundNormalColor = primaryColor
            currentLowLightCustomization.guidanceCustomization.buttonTextHighlightColor = UIColor.white
            currentLowLightCustomization.guidanceCustomization.buttonBackgroundHighlightColor = primaryColorDark
            currentLowLightCustomization.guidanceCustomization.buttonTextDisabledColor = UIColor.white
            currentLowLightCustomization.guidanceCustomization.buttonBackgroundDisabledColor = primaryColorLight
            currentLowLightCustomization.guidanceCustomization.buttonBorderColor = UIColor.clear
            currentLowLightCustomization.guidanceCustomization.readyScreenOvalFillColor = UIColor.clear
            currentLowLightCustomization.guidanceCustomization.readyScreenTextBackgroundColor = primaryColor
            currentLowLightCustomization.guidanceCustomization.retryScreenImageBorderColor = primaryColor
            currentLowLightCustomization.guidanceCustomization.retryScreenOvalStrokeColor = primaryColor
            currentLowLightCustomization.guidanceCustomization.retryScreenSlideshowImages = []
            // ID Scan Customization
            currentLowLightCustomization.idScanCustomization.selectionScreenDocumentImage = UIImage(named: "document_grey")
            currentLowLightCustomization.idScanCustomization.captureScreenForegroundColor = UIColor.white
            currentLowLightCustomization.idScanCustomization.reviewScreenForegroundColor = UIColor.white
            currentLowLightCustomization.idScanCustomization.selectionScreenForegroundColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.captureScreenFocusMessageTextColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.buttonTextNormalColor = UIColor.white
            currentLowLightCustomization.idScanCustomization.buttonBackgroundNormalColor = primaryColor
            currentLowLightCustomization.idScanCustomization.buttonTextHighlightColor = UIColor.white
            currentLowLightCustomization.idScanCustomization.buttonBackgroundHighlightColor = primaryColorDark
            currentLowLightCustomization.idScanCustomization.buttonTextDisabledColor = UIColor.white
            currentLowLightCustomization.idScanCustomization.buttonBackgroundDisabledColor = primaryColorLight
            currentLowLightCustomization.idScanCustomization.buttonBorderColor = UIColor.clear
            currentLowLightCustomization.idScanCustomization.captureScreenTextBackgroundColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.captureScreenTextBackgroundBorderColor = UIColor.clear
            currentLowLightCustomization.idScanCustomization.reviewScreenTextBackgroundColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.reviewScreenTextBackgroundBorderColor = UIColor.clear
            currentLowLightCustomization.idScanCustomization.captureFrameStrokeColor = primaryColor
            currentLowLightCustomization.idScanCustomization.activeTorchButtonImage = UIImage(named: "torch_active_orange")
            currentLowLightCustomization.idScanCustomization.inactiveTorchButtonImage = UIImage(named: "torch_inactive_orange")
            currentLowLightCustomization.idScanCustomization.additionalReviewScreenForegroundColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.additionalReviewScreenImage = nil
            currentLowLightCustomization.idScanCustomization.idFeedbackScreenForegroundColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.idFeedbackScreenFlipIDFrontImage = nil
            currentLowLightCustomization.idScanCustomization.idFeedbackScreenFlipIDBackImage = nil
            currentLowLightCustomization.idScanCustomization.additionalReviewTagImage = UIImage(named: "warning_orange")
            currentLowLightCustomization.idScanCustomization.additionalReviewTagImageColor = primaryColor
            currentLowLightCustomization.idScanCustomization.additionalReviewTagTextColor = primaryColor
            // OCR Confirmation Screen Customization
            currentLowLightCustomization.ocrConfirmationCustomization.mainHeaderDividerLineColor = secondaryColor
            currentLowLightCustomization.ocrConfirmationCustomization.mainHeaderTextColor = primaryColor
            currentLowLightCustomization.ocrConfirmationCustomization.sectionHeaderTextColor = primaryColor
            currentLowLightCustomization.ocrConfirmationCustomization.fieldLabelTextColor = primaryColor
            currentLowLightCustomization.ocrConfirmationCustomization.fieldValueTextColor = primaryColor
            currentLowLightCustomization.ocrConfirmationCustomization.inputFieldTextColor = primaryColor
            currentLowLightCustomization.ocrConfirmationCustomization.inputFieldPlaceholderTextColor = primaryColor.withAlphaComponent(0.4)
            currentLowLightCustomization.ocrConfirmationCustomization.inputFieldBackgroundColor = UIColor.clear
            currentLowLightCustomization.ocrConfirmationCustomization.inputFieldBorderColor = primaryColor
            currentLowLightCustomization.ocrConfirmationCustomization.buttonTextNormalColor = backgroundColor
            currentLowLightCustomization.ocrConfirmationCustomization.buttonBackgroundNormalColor = primaryColor
            currentLowLightCustomization.ocrConfirmationCustomization.buttonTextHighlightColor = backgroundColor
            currentLowLightCustomization.ocrConfirmationCustomization.buttonBackgroundHighlightColor = primaryColorDark
            currentLowLightCustomization.ocrConfirmationCustomization.buttonTextDisabledColor = UIColor.white
            currentLowLightCustomization.ocrConfirmationCustomization.buttonBackgroundDisabledColor = primaryColorLight
            currentLowLightCustomization.ocrConfirmationCustomization.buttonBorderColor = UIColor.clear
            currentLowLightCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundNormalColor = primaryColor
            currentLowLightCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundHighlightColor = primaryColorLight
            currentLowLightCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundNormalColor = backgroundColor
            currentLowLightCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundHighlightColor = backgroundColor
            currentLowLightCustomization.ocrConfirmationCustomization.scrollIndicatorBorderColor = UIColor.clear
            // Result Screen Customization
            currentLowLightCustomization.resultScreenCustomization.foregroundColor = backgroundColor
            currentLowLightCustomization.resultScreenCustomization.activityIndicatorColor = primaryColor
            currentLowLightCustomization.resultScreenCustomization.customActivityIndicatorImage = UIImage(named: "activity_indicator_orange")
            currentLowLightCustomization.resultScreenCustomization.resultAnimationBackgroundColor = primaryColor
            currentLowLightCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundColor = primaryColor
            currentLowLightCustomization.resultScreenCustomization.resultAnimationForegroundColor = UIColor.white
            currentLowLightCustomization.resultScreenCustomization.resultAnimationUnsuccessForegroundColor = UIColor.white
            currentLowLightCustomization.resultScreenCustomization.resultAnimationIDScanSuccessForegroundColor = primaryColor
            currentLowLightCustomization.resultScreenCustomization.resultAnimationNFCSuccessForegroundColor = primaryColor
            currentLowLightCustomization.resultScreenCustomization.resultAnimationSuccessBackgroundImage = nil
            currentLowLightCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundImage = nil
            currentLowLightCustomization.resultScreenCustomization.uploadProgressTrackColor = UIColor.black.withAlphaComponent(0.2)
            currentLowLightCustomization.resultScreenCustomization.uploadProgressFillColor = primaryColor
            // Feedback Customization
            currentLowLightCustomization.feedbackCustomization.backgroundColor = backgroundLayer
            currentLowLightCustomization.feedbackCustomization.textColor = UIColor.white
            // Frame Customization
            currentLowLightCustomization.frameCustomization.borderColor = backgroundColor
            // Oval Customization
            currentLowLightCustomization.ovalCustomization.strokeColor = primaryColor
            currentLowLightCustomization.ovalCustomization.progressColor1 = secondaryColor
            currentLowLightCustomization.ovalCustomization.progressColor2 = secondaryColor
            // Cancel Button Customization
            currentLowLightCustomization.cancelButtonCustomization.customImage = UIImage(named: "single_chevron_left_orange")
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentLowLightCustomization.initialLoadingAnimationCustomization.foregroundColor = backgroundColor
            currentLowLightCustomization.initialLoadingAnimationCustomization.defaultAnimationBackgroundColor = primaryColorLight
            currentLowLightCustomization.initialLoadingAnimationCustomization.defaultAnimationForegroundColor = primaryColor
            // Orientation Screen Customization
            currentLowLightCustomization.orientationScreenCustomization.foregroundColor = backgroundColor
            currentLowLightCustomization.orientationScreenCustomization.iconImage = nil
            
            // Guidance Customization -- Text Style Overrides
            // Ready Screen Header
            currentLowLightCustomization.guidanceCustomization.readyScreenHeaderTextColor = primaryColor
            // Ready Screen Subtext
            currentLowLightCustomization.guidanceCustomization.readyScreenSubtextTextColor = UIColor(red: 0.337, green: 0.337, blue: 0.337, alpha: 1)
            // Retry Screen Header
            currentLowLightCustomization.guidanceCustomization.retryScreenHeaderTextColor = primaryColor
            // Retry Screen Subtext
            currentLowLightCustomization.guidanceCustomization.retryScreenSubtextTextColor = UIColor(red: 0.337, green: 0.337, blue: 0.337, alpha: 1)
        }
        else if theme == "Sample Bank" {
            let primaryColor = UIColor.white
            let backgroundColor = UIColor(red: 0.114, green: 0.090, blue: 0.310, alpha: 1) // navy
            let backgroundColorLight = backgroundColor.withAlphaComponent(0.8)// lighter navy
            let backgroundLayer = CAGradientLayer.init()
            backgroundLayer.colors = [backgroundColor.cgColor, backgroundColor.cgColor]
            backgroundLayer.locations = [0,1]
            backgroundLayer.startPoint = CGPoint.init(x: 0, y: 0)
            backgroundLayer.endPoint = CGPoint.init(x: 1, y: 0)

            // Overlay Customization
            currentLowLightCustomization.overlayCustomization.brandingImage = UIImage(named: "sample_bank_logo")
            // Guidance Customization
            currentLowLightCustomization.guidanceCustomization.foregroundColor = backgroundColor
            currentLowLightCustomization.guidanceCustomization.buttonTextNormalColor = primaryColor
            currentLowLightCustomization.guidanceCustomization.buttonBackgroundNormalColor = backgroundColor
            currentLowLightCustomization.guidanceCustomization.buttonTextHighlightColor = primaryColor
            currentLowLightCustomization.guidanceCustomization.buttonBackgroundHighlightColor = backgroundColorLight
            currentLowLightCustomization.guidanceCustomization.buttonTextDisabledColor = primaryColor.withAlphaComponent(0.3)
            currentLowLightCustomization.guidanceCustomization.buttonBackgroundDisabledColor = backgroundColor
            currentLowLightCustomization.guidanceCustomization.buttonBorderColor = backgroundColor
            currentLowLightCustomization.guidanceCustomization.readyScreenOvalFillColor = UIColor.clear
            currentLowLightCustomization.guidanceCustomization.readyScreenTextBackgroundColor = primaryColor
            currentLowLightCustomization.guidanceCustomization.retryScreenImageBorderColor = backgroundColor
            currentLowLightCustomization.guidanceCustomization.retryScreenOvalStrokeColor = primaryColor
            currentLowLightCustomization.guidanceCustomization.retryScreenSlideshowImages = retryScreenSlideshowImages
            // ID Scan Customization
            currentLowLightCustomization.idScanCustomization.selectionScreenDocumentImage = nil
            currentLowLightCustomization.idScanCustomization.captureScreenForegroundColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.reviewScreenForegroundColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.selectionScreenForegroundColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.captureScreenFocusMessageTextColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.buttonTextNormalColor = primaryColor
            currentLowLightCustomization.idScanCustomization.buttonBackgroundNormalColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.buttonTextHighlightColor = primaryColor
            currentLowLightCustomization.idScanCustomization.buttonBackgroundHighlightColor = backgroundColorLight
            currentLowLightCustomization.idScanCustomization.buttonTextDisabledColor = primaryColor.withAlphaComponent(0.3)
            currentLowLightCustomization.idScanCustomization.buttonBackgroundDisabledColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.buttonBorderColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.captureScreenTextBackgroundColor = primaryColor
            currentLowLightCustomization.idScanCustomization.captureScreenTextBackgroundBorderColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.reviewScreenTextBackgroundColor = primaryColor
            currentLowLightCustomization.idScanCustomization.reviewScreenTextBackgroundBorderColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.captureFrameStrokeColor = primaryColor
            currentLowLightCustomization.idScanCustomization.activeTorchButtonImage = UIImage(named: "torch_active_navy")
            currentLowLightCustomization.idScanCustomization.inactiveTorchButtonImage = UIImage(named: "torch_inactive_navy")
            currentLowLightCustomization.idScanCustomization.additionalReviewScreenForegroundColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.additionalReviewScreenImage = UIImage(named: "review_navy")
            currentLowLightCustomization.idScanCustomization.additionalReviewTagImage = UIImage(named: "warning_navy")
            currentLowLightCustomization.idScanCustomization.additionalReviewTagImageColor = backgroundColor
            currentLowLightCustomization.idScanCustomization.additionalReviewTagTextColor = backgroundColor
            // OCR Confirmation Screen Customization
            currentLowLightCustomization.ocrConfirmationCustomization.mainHeaderDividerLineColor = backgroundColor
            currentLowLightCustomization.ocrConfirmationCustomization.mainHeaderTextColor = backgroundColor
            currentLowLightCustomization.ocrConfirmationCustomization.sectionHeaderTextColor = backgroundColor
            currentLowLightCustomization.ocrConfirmationCustomization.fieldLabelTextColor = backgroundColor
            currentLowLightCustomization.ocrConfirmationCustomization.fieldValueTextColor = backgroundColor
            currentLowLightCustomization.ocrConfirmationCustomization.inputFieldTextColor = backgroundColor
            currentLowLightCustomization.ocrConfirmationCustomization.inputFieldPlaceholderTextColor = backgroundColor.withAlphaComponent(0.4)
            currentLowLightCustomization.ocrConfirmationCustomization.inputFieldBackgroundColor = UIColor.clear
            currentLowLightCustomization.ocrConfirmationCustomization.inputFieldBorderColor = backgroundColor
            currentLowLightCustomization.ocrConfirmationCustomization.buttonTextNormalColor = primaryColor
            currentLowLightCustomization.ocrConfirmationCustomization.buttonBackgroundNormalColor = backgroundColor
            currentLowLightCustomization.ocrConfirmationCustomization.buttonTextHighlightColor = primaryColor
            currentLowLightCustomization.ocrConfirmationCustomization.buttonBackgroundHighlightColor = backgroundColorLight
            currentLowLightCustomization.ocrConfirmationCustomization.buttonTextDisabledColor = primaryColor.withAlphaComponent(0.3)
            currentLowLightCustomization.ocrConfirmationCustomization.buttonBackgroundDisabledColor = backgroundColor
            currentLowLightCustomization.ocrConfirmationCustomization.buttonBorderColor = backgroundColor
            currentLowLightCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundNormalColor = backgroundColor
            currentLowLightCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundHighlightColor = backgroundColorLight
            currentLowLightCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundNormalColor = primaryColor
            currentLowLightCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundHighlightColor = primaryColor
            currentLowLightCustomization.ocrConfirmationCustomization.scrollIndicatorBorderColor = UIColor.clear
            // Result Screen Customization
            currentLowLightCustomization.resultScreenCustomization.foregroundColor = backgroundColor
            currentLowLightCustomization.resultScreenCustomization.activityIndicatorColor = backgroundColor
            currentLowLightCustomization.resultScreenCustomization.customActivityIndicatorImage = UIImage(named: "activity_indicator_navy")
            currentLowLightCustomization.resultScreenCustomization.resultAnimationBackgroundColor = UIColor.clear
            currentLowLightCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundColor = UIColor.clear
            currentLowLightCustomization.resultScreenCustomization.resultAnimationForegroundColor = backgroundColor
            currentLowLightCustomization.resultScreenCustomization.resultAnimationUnsuccessForegroundColor = backgroundColor
            currentLowLightCustomization.resultScreenCustomization.resultAnimationIDScanSuccessForegroundColor = backgroundColor
            currentLowLightCustomization.resultScreenCustomization.resultAnimationNFCSuccessForegroundColor = backgroundColor
            currentLowLightCustomization.resultScreenCustomization.resultAnimationSuccessBackgroundImage = UIImage(named: "reticle_navy")
            currentLowLightCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundImage = UIImage(named: "reticle_navy")
            currentLowLightCustomization.resultScreenCustomization.uploadProgressTrackColor = UIColor.black.withAlphaComponent(0.2)
            currentLowLightCustomization.resultScreenCustomization.uploadProgressFillColor = backgroundColor
            // Feedback Customization
            currentLowLightCustomization.feedbackCustomization.backgroundColor = backgroundLayer
            currentLowLightCustomization.feedbackCustomization.textColor = primaryColor
            // Frame Customization
            currentLowLightCustomization.frameCustomization.borderColor = backgroundColor
            // Oval Customization
            currentLowLightCustomization.ovalCustomization.strokeColor = backgroundColor
            currentLowLightCustomization.ovalCustomization.progressColor1 = backgroundColor.withAlphaComponent(0.5)
            currentLowLightCustomization.ovalCustomization.progressColor2 = backgroundColor.withAlphaComponent(0.5)
            // Cancel Button Customization
            currentLowLightCustomization.cancelButtonCustomization.customImage = UIImage(named: "cancel_navy")
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentLowLightCustomization.initialLoadingAnimationCustomization.foregroundColor = backgroundColor
            currentLowLightCustomization.initialLoadingAnimationCustomization.defaultAnimationBackgroundColor = backgroundColor.withAlphaComponent(0.5)
            currentLowLightCustomization.initialLoadingAnimationCustomization.defaultAnimationForegroundColor = backgroundColor
            // Orientation Screen Customization
            currentLowLightCustomization.orientationScreenCustomization.foregroundColor = backgroundColor
            currentLowLightCustomization.orientationScreenCustomization.iconImage = nil
        }
        
        return currentLowLightCustomization
    }
    
    // Configure UX Color Scheme For Low Light Mode
    class func getDynamicDimmingCustomizationForTheme(theme: String) -> FaceTecCustomization {
        var currentDynamicDimmingCustomization: FaceTecCustomization = getCustomizationForTheme(theme: theme)
        
        let retryScreenSlideshowImages = [UIImage(named: "FaceTec_ideal_1")!, UIImage(named: "FaceTec_ideal_2")!, UIImage(named: "FaceTec_ideal_3")!, UIImage(named: "FaceTec_ideal_4")!, UIImage(named: "FaceTec_ideal_5")!]

        if theme == "FaceTec Theme" {
            // ID Scan Customization
            currentDynamicDimmingCustomization.idScanCustomization.captureScreenFocusMessageTextColor = UIColor.white
            // OCR Confirmation Screen Customization
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.sectionHeaderTextColor = UIColor.white
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.fieldLabelTextColor = UIColor.white
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.fieldValueTextColor = UIColor.white
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.inputFieldTextColor = UIColor.white
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.inputFieldPlaceholderTextColor = UIColor.white.withAlphaComponent(0.4)
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.inputFieldBorderColor = UIColor.white
        }
        else if theme == "Config Wizard Theme" {
            currentDynamicDimmingCustomization = Config.retrieveDynamicDimmingConfigurationWizardCustomization()
        }
        else if theme == "Pseudo-Fullscreen" {
            let primaryColor = UIColor(red: 0.933, green: 0.965, blue: 0.973, alpha: 1) // off-white
            let primaryColorLight = UIColor.white // white
            let secondaryColor = UIColor(red: 0.235, green: 0.702, blue: 0.443, alpha: 1) // green
            let backgroundColor = UIColor.black
            let backgroundLayer = CAGradientLayer.init()
            backgroundLayer.colors = [secondaryColor.cgColor, secondaryColor.cgColor]
            backgroundLayer.locations = [0,1]
            backgroundLayer.startPoint = CGPoint.init(x: 0, y: 0)
            backgroundLayer.endPoint = CGPoint.init(x: 1, y: 0)
            
            let feedbackShadow: FaceTecShadow? = nil
            let frameShadow: FaceTecShadow? = nil
            
            //
            // NOTE: For this theme, the Result Screen's activity indicator and result animations are overriden by the use of the FaceTecCustomAnimationDelegate and its methods to specify a custom UIView to display for the individual animations.
            //
            
            // Overlay Customization
            currentDynamicDimmingCustomization.overlayCustomization.brandingImage = nil
            // Guidance Customization
            currentDynamicDimmingCustomization.guidanceCustomization.foregroundColor = primaryColor
            currentDynamicDimmingCustomization.guidanceCustomization.buttonTextNormalColor = backgroundColor
            currentDynamicDimmingCustomization.guidanceCustomization.buttonBackgroundNormalColor = primaryColor
            currentDynamicDimmingCustomization.guidanceCustomization.buttonTextHighlightColor = backgroundColor
            currentDynamicDimmingCustomization.guidanceCustomization.buttonBackgroundHighlightColor = UIColor.white
            currentDynamicDimmingCustomization.guidanceCustomization.buttonTextDisabledColor = backgroundColor
            currentDynamicDimmingCustomization.guidanceCustomization.buttonBackgroundDisabledColor = primaryColor.withAlphaComponent(0.3)
            currentDynamicDimmingCustomization.guidanceCustomization.buttonBorderColor = UIColor.clear
            currentDynamicDimmingCustomization.guidanceCustomization.readyScreenOvalFillColor = UIColor.clear
            currentDynamicDimmingCustomization.guidanceCustomization.readyScreenTextBackgroundColor = backgroundColor
            currentDynamicDimmingCustomization.guidanceCustomization.retryScreenImageBorderColor = primaryColor
            currentDynamicDimmingCustomization.guidanceCustomization.retryScreenOvalStrokeColor = backgroundColor
            currentDynamicDimmingCustomization.guidanceCustomization.retryScreenSlideshowImages = retryScreenSlideshowImages
            // ID Scan Customization
            currentDynamicDimmingCustomization.idScanCustomization.selectionScreenDocumentImage = UIImage(named: "document_offwhite")
            currentDynamicDimmingCustomization.idScanCustomization.selectionScreenDocumentImage = nil
            currentDynamicDimmingCustomization.idScanCustomization.captureScreenForegroundColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.reviewScreenForegroundColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.selectionScreenForegroundColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.captureScreenFocusMessageTextColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.buttonTextNormalColor = backgroundColor
            currentDynamicDimmingCustomization.idScanCustomization.buttonBackgroundNormalColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.buttonTextHighlightColor = backgroundColor
            currentDynamicDimmingCustomization.idScanCustomization.buttonBackgroundHighlightColor = UIColor.white
            currentDynamicDimmingCustomization.idScanCustomization.buttonTextDisabledColor = backgroundColor
            currentDynamicDimmingCustomization.idScanCustomization.buttonBackgroundDisabledColor =  primaryColor.withAlphaComponent(0.3)
            currentDynamicDimmingCustomization.idScanCustomization.buttonBorderColor = UIColor.clear
            currentDynamicDimmingCustomization.idScanCustomization.captureScreenTextBackgroundColor = backgroundColor
            currentDynamicDimmingCustomization.idScanCustomization.captureScreenTextBackgroundBorderColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.reviewScreenTextBackgroundColor = backgroundColor
            currentDynamicDimmingCustomization.idScanCustomization.reviewScreenTextBackgroundBorderColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.captureFrameStrokeColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.activeTorchButtonImage = UIImage(named: "torch_active_offwhite")
            currentDynamicDimmingCustomization.idScanCustomization.inactiveTorchButtonImage = UIImage(named: "torch_inactive_offwhite")
            currentDynamicDimmingCustomization.idScanCustomization.additionalReviewScreenForegroundColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.additionalReviewScreenImage = UIImage(named: "review_offwhite")
            currentDynamicDimmingCustomization.idScanCustomization.idFeedbackScreenForegroundColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.idFeedbackScreenFlipIDFrontImage = nil
            currentDynamicDimmingCustomization.idScanCustomization.idFeedbackScreenFlipIDBackImage = nil
            // OCR Confirmation Screen Customization
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.mainHeaderDividerLineColor = secondaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.mainHeaderTextColor = secondaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.sectionHeaderTextColor = primaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.fieldLabelTextColor = primaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.fieldValueTextColor = primaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.inputFieldTextColor = primaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.inputFieldPlaceholderTextColor = secondaryColor.withAlphaComponent(0.4)
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.inputFieldBackgroundColor = UIColor.clear
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.inputFieldBorderColor = secondaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.buttonTextNormalColor = backgroundColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.buttonBackgroundNormalColor = primaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.buttonTextHighlightColor = backgroundColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.buttonBackgroundHighlightColor = UIColor.white
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.buttonTextDisabledColor = backgroundColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.buttonBackgroundDisabledColor =  primaryColor.withAlphaComponent(0.3)
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.buttonBorderColor = UIColor.clear
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundNormalColor = primaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundHighlightColor = primaryColorLight
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundNormalColor = backgroundColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundHighlightColor = backgroundColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorBorderColor = UIColor.clear
            // Result Screen Customization
            currentDynamicDimmingCustomization.resultScreenCustomization.backgroundColors = [backgroundColor, backgroundColor]
            currentDynamicDimmingCustomization.resultScreenCustomization.foregroundColor = primaryColor
            currentDynamicDimmingCustomization.resultScreenCustomization.activityIndicatorColor = primaryColor
            currentDynamicDimmingCustomization.resultScreenCustomization.customActivityIndicatorImage = nil
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationBackgroundColor = secondaryColor
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundColor = secondaryColor
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationForegroundColor = backgroundColor
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationUnsuccessForegroundColor = backgroundColor
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationIDScanSuccessForegroundColor = primaryColor
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationNFCSuccessForegroundColor = primaryColor
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationSuccessBackgroundImage = nil
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundImage = nil
            currentDynamicDimmingCustomization.resultScreenCustomization.uploadProgressTrackColor = primaryColor.withAlphaComponent(0.2)
            currentDynamicDimmingCustomization.resultScreenCustomization.uploadProgressFillColor = secondaryColor
            // Feedback Customization
            currentDynamicDimmingCustomization.feedbackCustomization.backgroundColor = backgroundLayer
            currentDynamicDimmingCustomization.feedbackCustomization.textColor = backgroundColor
            currentDynamicDimmingCustomization.feedbackCustomization.shadow = feedbackShadow
            // Frame Customization
            currentDynamicDimmingCustomization.frameCustomization.borderColor = primaryColor
            currentDynamicDimmingCustomization.frameCustomization.shadow = frameShadow
            // Oval Customization
            currentDynamicDimmingCustomization.ovalCustomization.strokeColor = primaryColor
            currentDynamicDimmingCustomization.ovalCustomization.progressColor1 = secondaryColor.withAlphaComponent(0.7)
            currentDynamicDimmingCustomization.ovalCustomization.progressColor2 = secondaryColor.withAlphaComponent(0.7)
            // Cancel Button Customization
            currentDynamicDimmingCustomization.cancelButtonCustomization.customImage = UIImage(named: "single_chevron_left_offwhite")
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentDynamicDimmingCustomization.initialLoadingAnimationCustomization.foregroundColor = primaryColor
            currentDynamicDimmingCustomization.initialLoadingAnimationCustomization.defaultAnimationBackgroundColor = primaryColor.withAlphaComponent(0.2)
            currentDynamicDimmingCustomization.initialLoadingAnimationCustomization.defaultAnimationForegroundColor = secondaryColor
            // Orientation Screen Customization
            currentDynamicDimmingCustomization.orientationScreenCustomization.foregroundColor = primaryColor
            currentDynamicDimmingCustomization.orientationScreenCustomization.iconImage = nil
            
            // Guidance Customization -- Text Style Overrides
            // Ready Screen Header
            currentDynamicDimmingCustomization.guidanceCustomization.readyScreenHeaderTextColor = primaryColor
            // Ready Screen Subtext
            currentDynamicDimmingCustomization.guidanceCustomization.readyScreenSubtextTextColor = primaryColor
            // Retry Screen Header
            currentDynamicDimmingCustomization.guidanceCustomization.retryScreenHeaderTextColor = primaryColor
            // Retry Screen Subtext
            currentDynamicDimmingCustomization.guidanceCustomization.retryScreenSubtextTextColor = primaryColor
        }
        else if theme == "Well-Rounded" {
            let backgroundColor = UIColor.black
            
            // OCR Confirmation Screen Customization
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundNormalColor = backgroundColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundHighlightColor = backgroundColor
        }
        else if theme == "Bitcoin Exchange" {
            let primaryColor = UIColor(red: 0.969, green: 0.588, blue: 0.204, alpha: 1) // orange
            let backgroundColor = UIColor(red: 0.259, green: 0.259, blue: 0.259, alpha: 1) // dark grey
            
            // Overlay Customization
            currentDynamicDimmingCustomization.overlayCustomization.brandingImage = UIImage(named: "bitcoin_exchange_logo_white")
            // Result Screen Customization
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationBackgroundColor = primaryColor
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundColor = primaryColor
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationForegroundColor = UIColor.black
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationUnsuccessForegroundColor = UIColor.black
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationIDScanSuccessForegroundColor = primaryColor
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationNFCSuccessForegroundColor = primaryColor
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentDynamicDimmingCustomization.initialLoadingAnimationCustomization.foregroundColor = primaryColor
            currentDynamicDimmingCustomization.initialLoadingAnimationCustomization.defaultAnimationBackgroundColor = backgroundColor
            currentDynamicDimmingCustomization.initialLoadingAnimationCustomization.defaultAnimationForegroundColor = primaryColor
        }
        else if theme == "eKYC" {
            let primaryColor = UIColor(red: 0.929, green: 0.110, blue: 0.141, alpha: 1) // red
            let primaryColorLight = UIColor(red: 0.929, green: 0.110, blue: 0.141, alpha: 0.8) // red
            let secondaryColor = UIColor.white
            let backgroundColor = UIColor.black
            let backgroundLayer = CAGradientLayer.init()
            backgroundLayer.colors = [secondaryColor.cgColor, secondaryColor.cgColor]
            backgroundLayer.locations = [0,1]
            backgroundLayer.startPoint = CGPoint.init(x: 0, y: 0)
            backgroundLayer.endPoint = CGPoint.init(x: 1, y: 0)
            
            let feedbackShadow: FaceTecShadow? = FaceTecShadow(color: primaryColor, opacity: 1, radius: 5, offset: CGSize(width: 0, height: 2), insets: UIEdgeInsets(top: 1, left: -1, bottom: -1, right: -1))
            let frameShadow: FaceTecShadow? = FaceTecShadow(color: primaryColor, opacity: 1, radius: 3, offset: CGSize(width: 0, height: 2), insets: UIEdgeInsets(top: 1, left: -1, bottom: -1, right: -1))
            
            // Overlay Customization
            currentDynamicDimmingCustomization.overlayCustomization.brandingImage = UIImage(named: "ekyc_logo_white")
            // Guidance Customization
            currentDynamicDimmingCustomization.guidanceCustomization.foregroundColor = secondaryColor
            currentDynamicDimmingCustomization.guidanceCustomization.buttonTextNormalColor = primaryColor
            currentDynamicDimmingCustomization.guidanceCustomization.buttonBackgroundNormalColor = UIColor.clear
            currentDynamicDimmingCustomization.guidanceCustomization.buttonTextHighlightColor = backgroundColor
            currentDynamicDimmingCustomization.guidanceCustomization.buttonBackgroundHighlightColor = primaryColor
            currentDynamicDimmingCustomization.guidanceCustomization.buttonTextDisabledColor = primaryColor.withAlphaComponent(0.3)
            currentDynamicDimmingCustomization.guidanceCustomization.buttonBackgroundDisabledColor = UIColor.clear
            currentDynamicDimmingCustomization.guidanceCustomization.buttonBorderColor = primaryColor
            currentDynamicDimmingCustomization.guidanceCustomization.readyScreenOvalFillColor = UIColor.clear
            currentDynamicDimmingCustomization.guidanceCustomization.readyScreenTextBackgroundColor = backgroundColor
            currentDynamicDimmingCustomization.guidanceCustomization.retryScreenImageBorderColor = primaryColor
            currentDynamicDimmingCustomization.guidanceCustomization.retryScreenOvalStrokeColor = primaryColor
            currentDynamicDimmingCustomization.guidanceCustomization.retryScreenSlideshowImages = retryScreenSlideshowImages
            // ID Scan Customization
            currentDynamicDimmingCustomization.idScanCustomization.selectionScreenDocumentImage = nil
            currentDynamicDimmingCustomization.idScanCustomization.captureScreenForegroundColor = backgroundColor
            currentDynamicDimmingCustomization.idScanCustomization.reviewScreenForegroundColor = backgroundColor
            currentDynamicDimmingCustomization.idScanCustomization.selectionScreenForegroundColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.captureScreenFocusMessageTextColor = secondaryColor
            currentDynamicDimmingCustomization.idScanCustomization.buttonTextNormalColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.buttonBackgroundNormalColor = UIColor.clear
            currentDynamicDimmingCustomization.idScanCustomization.buttonTextHighlightColor = backgroundColor
            currentDynamicDimmingCustomization.idScanCustomization.buttonBackgroundHighlightColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.buttonTextDisabledColor = primaryColor.withAlphaComponent(0.3)
            currentDynamicDimmingCustomization.idScanCustomization.buttonBackgroundDisabledColor = UIColor.clear
            currentDynamicDimmingCustomization.idScanCustomization.buttonBorderColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.captureScreenTextBackgroundColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.captureScreenTextBackgroundBorderColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.reviewScreenTextBackgroundColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.reviewScreenTextBackgroundBorderColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.captureFrameStrokeColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.activeTorchButtonImage = UIImage(named: "torch_active_offwhite")
            currentDynamicDimmingCustomization.idScanCustomization.inactiveTorchButtonImage = UIImage(named: "torch_inactive_offwhite")
            currentDynamicDimmingCustomization.idScanCustomization.additionalReviewScreenForegroundColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.additionalReviewScreenImage = nil
            currentDynamicDimmingCustomization.idScanCustomization.idFeedbackScreenForegroundColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.idFeedbackScreenFlipIDFrontImage = nil
            currentDynamicDimmingCustomization.idScanCustomization.idFeedbackScreenFlipIDBackImage = nil
            currentDynamicDimmingCustomization.idScanCustomization.additionalReviewTagImage = nil
            currentDynamicDimmingCustomization.idScanCustomization.additionalReviewTagImageColor = primaryColor
            currentDynamicDimmingCustomization.idScanCustomization.additionalReviewTagTextColor = secondaryColor
            // OCR Confirmation Screen Customization
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.mainHeaderDividerLineColor = secondaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.mainHeaderTextColor = secondaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.sectionHeaderTextColor = primaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.fieldLabelTextColor = secondaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.fieldValueTextColor = secondaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.inputFieldTextColor = backgroundColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.inputFieldPlaceholderTextColor = backgroundColor.withAlphaComponent(0.4)
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.inputFieldBackgroundColor = secondaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.inputFieldBorderColor = primaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.buttonTextNormalColor = primaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.buttonBackgroundNormalColor = UIColor.clear
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.buttonTextHighlightColor = backgroundColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.buttonBackgroundHighlightColor = primaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.buttonTextDisabledColor = primaryColor.withAlphaComponent(0.3)
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.buttonBackgroundDisabledColor = UIColor.clear
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.buttonBorderColor = primaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundNormalColor = primaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundHighlightColor = primaryColorLight
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundNormalColor = backgroundColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundHighlightColor = backgroundColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorBorderColor = UIColor.clear
            // Result Screen Customization
            currentDynamicDimmingCustomization.resultScreenCustomization.foregroundColor = secondaryColor
            currentDynamicDimmingCustomization.resultScreenCustomization.activityIndicatorColor = primaryColor
            currentDynamicDimmingCustomization.resultScreenCustomization.customActivityIndicatorImage = UIImage(named: "activity_indicator_red")
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationBackgroundColor = UIColor.clear
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundColor = UIColor.clear
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationForegroundColor = UIColor.clear
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationUnsuccessForegroundColor = primaryColor
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationIDScanSuccessForegroundColor = UIColor.clear
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationNFCSuccessForegroundColor = UIColor.clear
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationSuccessBackgroundImage = nil
            currentDynamicDimmingCustomization.resultScreenCustomization.resultAnimationUnsuccessBackgroundImage = nil
            currentDynamicDimmingCustomization.resultScreenCustomization.uploadProgressTrackColor = UIColor.white.withAlphaComponent(0.2)
            currentDynamicDimmingCustomization.resultScreenCustomization.uploadProgressFillColor = primaryColor
            // Feedback Customization
            currentDynamicDimmingCustomization.feedbackCustomization.backgroundColor = backgroundLayer
            currentDynamicDimmingCustomization.feedbackCustomization.textColor = backgroundColor
            currentDynamicDimmingCustomization.feedbackCustomization.shadow = feedbackShadow
            // Frame Customization
            currentDynamicDimmingCustomization.frameCustomization.borderColor = primaryColor
            currentDynamicDimmingCustomization.frameCustomization.shadow = frameShadow
            // Oval Customization
            currentDynamicDimmingCustomization.ovalCustomization.strokeColor = primaryColor
            currentDynamicDimmingCustomization.ovalCustomization.progressColor1 = primaryColor.withAlphaComponent(0.5)
            currentDynamicDimmingCustomization.ovalCustomization.progressColor2 = primaryColor.withAlphaComponent(0.5)
            // Cancel Button Customization
            currentDynamicDimmingCustomization.cancelButtonCustomization.customImage = UIImage(named: "cancel_box_red")
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentDynamicDimmingCustomization.initialLoadingAnimationCustomization.foregroundColor = secondaryColor
            currentDynamicDimmingCustomization.initialLoadingAnimationCustomization.defaultAnimationBackgroundColor = primaryColor.withAlphaComponent(0.2)
            currentDynamicDimmingCustomization.initialLoadingAnimationCustomization.defaultAnimationForegroundColor = primaryColor
            // Orientation Screen Customization
            currentDynamicDimmingCustomization.orientationScreenCustomization.foregroundColor = secondaryColor
            currentDynamicDimmingCustomization.orientationScreenCustomization.iconImage = nil
        }
        else if theme == "Sample Bank" {
            let primaryColor = UIColor.black
            let backgroundColor = UIColor(red: 0.114, green: 0.090, blue: 0.310, alpha: 1) // navy
            let backgroundColorLight = backgroundColor.withAlphaComponent(0.8)// lighter navy
            
            // OCR Confirmation Screen Customization
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundNormalColor = backgroundColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorBackgroundHighlightColor = backgroundColorLight
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundNormalColor = primaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorForegroundHighlightColor = primaryColor
            currentDynamicDimmingCustomization.ocrConfirmationCustomization.scrollIndicatorBorderColor = UIColor.clear
        }
        
        return currentDynamicDimmingCustomization
    }
}

extension UIColor {
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}
