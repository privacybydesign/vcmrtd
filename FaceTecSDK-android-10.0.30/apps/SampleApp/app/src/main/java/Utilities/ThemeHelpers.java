package Utilities;

import android.content.Context;
import android.graphics.Color;
import android.graphics.Rect;
import android.graphics.Typeface;

import com.facetec.sampleapp.Config;
import com.facetec.sampleapp.R;
import com.facetec.sdk.FaceTecCancelButtonCustomization;
import com.facetec.sdk.FaceTecCustomization;
import com.facetec.sdk.FaceTecSDK;

public class ThemeHelpers {
    public static void setAppTheme(Context context, String theme) {
        Config.currentCustomization = getCustomizationForTheme(context, theme);
        Config.currentLowLightCustomization = getLowLightCustomizationForTheme(context, theme);
        Config.currentDynamicDimmingCustomization = getDynamicDimmingCustomizationForTheme(context, theme);

        SampleAppUtilities.setVocalGuidanceSoundFiles();

        FaceTecSDK.setCustomization(Config.currentCustomization);
        FaceTecSDK.setLowLightCustomization(Config.currentLowLightCustomization);
        FaceTecSDK.setDynamicDimmingCustomization(Config.currentDynamicDimmingCustomization);
    }

    public static FaceTecCustomization getCustomizationForTheme(Context context, String theme) {
        FaceTecCustomization currentCustomization = new FaceTecCustomization();

        int[] retryScreenSlideshowImages = new int[]{R.drawable.ideal_image_1, R.drawable.ideal_image_2, R.drawable.ideal_image_3, R.drawable.ideal_image_4, R.drawable.ideal_image_5};

        if (theme.equals("FaceTec Theme")) {
            currentCustomization.getIdScanCustomization().customNFCStartingAnimation = R.drawable.facetec_nfc_starting_animation;
            currentCustomization.getIdScanCustomization().customNFCScanningAnimation = R.drawable.facetec_nfc_scanning_animation;
            currentCustomization.getIdScanCustomization().customNFCCardStartingAnimation = R.drawable.facetec_nfc_card_starting_animation;
            currentCustomization.getIdScanCustomization().customNFCCardScanningAnimation = R.drawable.facetec_nfc_card_scanning_animation;
        }
        else if (theme.equals("Config Wizard Theme")) {
            currentCustomization = Config.retrieveConfigurationWizardCustomization();
            currentCustomization.getIdScanCustomization().customNFCStartingAnimation = R.drawable.facetec_nfc_starting_animation;
            currentCustomization.getIdScanCustomization().customNFCScanningAnimation = R.drawable.facetec_nfc_scanning_animation;
            currentCustomization.getIdScanCustomization().customNFCCardStartingAnimation = R.drawable.facetec_nfc_card_starting_animation;
            currentCustomization.getIdScanCustomization().customNFCCardScanningAnimation = R.drawable.facetec_nfc_card_scanning_animation;
        }
        else if (theme.equals("Pseudo-Fullscreen")) {
            int primaryColor = Color.parseColor("#2B2B2B"); // black
            int primaryColorLight = Color.parseColor("#565656"); // lighter black
            int secondaryColor = Color.parseColor("#3BC371"); // green
            int backgroundColor = Color.parseColor("#EEF6F8"); // white
            int buttonBackgroundDisabledColor = Color.parseColor("#adadad");
            int readyScreenOvalFillColor = Color.parseColor("#002B2B2B"); // transparent black

            Typeface boldTypeface = Typeface.create("sans-serif", Typeface.BOLD);
            Typeface normalTypeface = Typeface.create("sans-serif", Typeface.NORMAL);

            // Overlay Customization
            currentCustomization.getOverlayCustomization().backgroundColor = backgroundColor;
            currentCustomization.getOverlayCustomization().showBrandingImage = false;
            currentCustomization.getOverlayCustomization().brandingImage = 0;
            // Guidance Customization
            currentCustomization.getGuidanceCustomization().backgroundColors = backgroundColor;
            currentCustomization.getGuidanceCustomization().foregroundColor = primaryColor;
            currentCustomization.getGuidanceCustomization().headerFont = boldTypeface;
            currentCustomization.getGuidanceCustomization().subtextFont = normalTypeface;
            currentCustomization.getGuidanceCustomization().buttonFont = boldTypeface;
            currentCustomization.getGuidanceCustomization().buttonTextNormalColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().buttonBackgroundNormalColor = primaryColor;
            currentCustomization.getGuidanceCustomization().buttonTextHighlightColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().buttonBackgroundHighlightColor = Color.parseColor("#565656");
            currentCustomization.getGuidanceCustomization().buttonTextDisabledColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().buttonBackgroundDisabledColor = buttonBackgroundDisabledColor;
            currentCustomization.getGuidanceCustomization().buttonBorderColor = Color.TRANSPARENT;
            currentCustomization.getGuidanceCustomization().buttonBorderWidth = 0;
            currentCustomization.getGuidanceCustomization().buttonCornerRadius = 30;
            currentCustomization.getGuidanceCustomization().readyScreenOvalFillColor = readyScreenOvalFillColor;
            currentCustomization.getGuidanceCustomization().readyScreenTextBackgroundColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().readyScreenTextBackgroundCornerRadius = 5;
            currentCustomization.getGuidanceCustomization().retryScreenImageBorderColor = primaryColor;
            currentCustomization.getGuidanceCustomization().retryScreenImageBorderWidth = 2;
            currentCustomization.getGuidanceCustomization().retryScreenImageCornerRadius = 10;
            currentCustomization.getGuidanceCustomization().retryScreenOvalStrokeColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().retryScreenSlideshowImages = retryScreenSlideshowImages;
            currentCustomization.getGuidanceCustomization().retryScreenSlideshowInterval = 2000;
            currentCustomization.getGuidanceCustomization().enableRetryScreenSlideshowShuffle = true;
            currentCustomization.getGuidanceCustomization().cameraPermissionsScreenImage = R.drawable.camera_shutter_offblack;
            // ID Scan Customization
            currentCustomization.getIdScanCustomization().showSelectionScreenDocumentImage = true;
            currentCustomization.getIdScanCustomization().selectionScreenDocumentImage = R.drawable.document_offblack;
            currentCustomization.getIdScanCustomization().selectionScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().reviewScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().captureScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().reviewScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().selectionScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureScreenFocusMessageTextColor = Color.parseColor("#565656");
            currentCustomization.getIdScanCustomization().captureScreenFocusMessageFont = normalTypeface;
            currentCustomization.getIdScanCustomization().headerFont = boldTypeface;
            currentCustomization.getIdScanCustomization().subtextFont = normalTypeface;
            currentCustomization.getIdScanCustomization().buttonFont = boldTypeface;
            currentCustomization.getIdScanCustomization().buttonTextNormalColor = backgroundColor;
            currentCustomization.getIdScanCustomization().buttonBackgroundNormalColor = primaryColor;
            currentCustomization.getIdScanCustomization().buttonTextHighlightColor = backgroundColor;
            currentCustomization.getIdScanCustomization().buttonBackgroundHighlightColor = primaryColorLight;
            currentCustomization.getIdScanCustomization().buttonTextDisabledColor = backgroundColor;
            currentCustomization.getIdScanCustomization().buttonBackgroundDisabledColor = buttonBackgroundDisabledColor;
            currentCustomization.getIdScanCustomization().buttonBorderColor = Color.TRANSPARENT;
            currentCustomization.getIdScanCustomization().buttonBorderWidth = 0;
            currentCustomization.getIdScanCustomization().buttonCornerRadius = 30;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundColor = backgroundColor;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundBorderColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundBorderWidth = 2;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundCornerRadius = 5;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundColor = backgroundColor;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundBorderColor = primaryColor;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundBorderWidth = 2;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundCornerRadius = 5;
            currentCustomization.getIdScanCustomization().captureScreenBackgroundColor = backgroundColor;
            currentCustomization.getIdScanCustomization().captureFrameStrokeColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureFrameStrokeWidth = 2;
            currentCustomization.getIdScanCustomization().captureFrameCornerRadius = 12;
            currentCustomization.getIdScanCustomization().activeTorchButtonImage = R.drawable.torch_active_black;
            currentCustomization.getIdScanCustomization().inactiveTorchButtonImage = R.drawable.torch_inactive_black;
            currentCustomization.getIdScanCustomization().customNFCStartingAnimation = R.drawable.facetec_nfc_starting_animation_black;
            currentCustomization.getIdScanCustomization().customNFCScanningAnimation = R.drawable.facetec_nfc_scanning_animation;
            currentCustomization.getIdScanCustomization().customNFCSkipOrErrorAnimation = R.drawable.pseudo_fullscreen_animated_unsuccess;
            currentCustomization.getIdScanCustomization().additionalReviewScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().additionalReviewScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().additionalReviewScreenImage = R.drawable.review_offblack;
            currentCustomization.getIdScanCustomization().additionalReviewScreenAnimation = 0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().idFeedbackScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().idFeedbackScreenFlipIDFrontImage = 0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenFlipIDBackImage = 0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenFlipIDToBackAnimation = 0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenFlipIDToFrontAnimation = 0;
            currentCustomization.getIdScanCustomization().additionalReviewScreenAnimationDisplayTime = 2.0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenAnimationDisplayTime = 2.0;
            currentCustomization.getIdScanCustomization().nfcScreenAnimationDisplayTime = 2.0;
            currentCustomization.getIdScanCustomization().enableAdditionalReviewTag = false;
            currentCustomization.getIdScanCustomization().additionalReviewTagImage = 0;
            currentCustomization.getIdScanCustomization().additionalReviewTagImageColor = primaryColor;
            currentCustomization.getIdScanCustomization().additionalReviewTagTextColor = primaryColor;
            // OCR Confirmation Screen Customization
            currentCustomization.getOcrConfirmationCustomization().backgroundColors = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderDividerLineColor = secondaryColor;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderDividerLineWidth = 2;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderFont = boldTypeface;
            currentCustomization.getOcrConfirmationCustomization().sectionHeaderFont = boldTypeface;
            currentCustomization.getOcrConfirmationCustomization().fieldLabelFont = normalTypeface;
            currentCustomization.getOcrConfirmationCustomization().fieldValueFont = normalTypeface;
            currentCustomization.getOcrConfirmationCustomization().inputFieldFont = normalTypeface;
            currentCustomization.getOcrConfirmationCustomization().inputFieldPlaceholderFont = normalTypeface;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderTextColor = secondaryColor;
            currentCustomization.getOcrConfirmationCustomization().sectionHeaderTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().fieldLabelTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().fieldValueTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().inputFieldTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().inputFieldPlaceholderTextColor = Color.parseColor("#663BC371");
            currentCustomization.getOcrConfirmationCustomization().inputFieldBackgroundColor = Color.TRANSPARENT;
            currentCustomization.getOcrConfirmationCustomization().inputFieldBorderColor = secondaryColor;
            currentCustomization.getOcrConfirmationCustomization().inputFieldBorderWidth = 2;
            currentCustomization.getOcrConfirmationCustomization().inputFieldCornerRadius = 0;
            currentCustomization.getOcrConfirmationCustomization().showInputFieldBottomBorderOnly = true;
            currentCustomization.getOcrConfirmationCustomization().buttonFont = boldTypeface;
            currentCustomization.getOcrConfirmationCustomization().buttonTextNormalColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBackgroundNormalColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().buttonTextHighlightColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBackgroundHighlightColor = Color.parseColor("#565656");
            currentCustomization.getOcrConfirmationCustomization().buttonTextDisabledColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBackgroundDisabledColor = buttonBackgroundDisabledColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBorderColor = Color.TRANSPARENT;
            currentCustomization.getOcrConfirmationCustomization().buttonBorderWidth = 0;
            currentCustomization.getOcrConfirmationCustomization().buttonCornerRadius = 30;
            currentCustomization.getOcrConfirmationCustomization().customScrollIndicatorAnimation = 0;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundNormalColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundHighlightColor = primaryColorLight;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundNormalColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundHighlightColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBorderColor = Color.TRANSPARENT;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBorderWidth = 0;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorCornerRadius = -1;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorFont = boldTypeface;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorElevation = 10;
            currentCustomization.getOcrConfirmationCustomization().enableScrollIndicator = true;
            currentCustomization.getOcrConfirmationCustomization().enableScrollIndicatorTextAnimation = false;
            currentCustomization.getOcrConfirmationCustomization().enableFixedConfirmButton = false;
            currentCustomization.getOcrConfirmationCustomization().showScrollIndicatorImage = true;
            // Result Screen Customization
            currentCustomization.getResultScreenCustomization().backgroundColors = backgroundColor;
            currentCustomization.getResultScreenCustomization().foregroundColor = primaryColor;
            currentCustomization.getResultScreenCustomization().messageFont  = boldTypeface;
            currentCustomization.getResultScreenCustomization().activityIndicatorColor = primaryColor;
            currentCustomization.getResultScreenCustomization().customActivityIndicatorImage = 0;
            currentCustomization.getResultScreenCustomization().customActivityIndicatorRotationInterval = 800;
            currentCustomization.getResultScreenCustomization().customActivityIndicatorAnimation = R.drawable.pseudo_fullscreen_animated_activity_indicator;
            currentCustomization.getResultScreenCustomization().resultAnimationBackgroundColor = secondaryColor;
            currentCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundColor = secondaryColor;
            currentCustomization.getResultScreenCustomization().resultAnimationForegroundColor = backgroundColor;
            currentCustomization.getResultScreenCustomization().resultAnimationUnsuccessForegroundColor = backgroundColor;
            currentCustomization.getResultScreenCustomization().resultAnimationIDScanSuccessForegroundColor = backgroundColor;
            currentCustomization.getResultScreenCustomization().resultAnimationNFCSuccessForegroundColor = backgroundColor;
            currentCustomization.getResultScreenCustomization().resultAnimationSuccessBackgroundImage = 0;
            currentCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundImage = 0;
            currentCustomization.getResultScreenCustomization().customResultAnimationIDScanSuccess = R.drawable.pseudo_fullscreen_animated_success;
            currentCustomization.getResultScreenCustomization().customResultAnimationNFCSuccess = R.drawable.pseudo_fullscreen_animated_success;
            currentCustomization.getResultScreenCustomization().customResultAnimationSuccess = R.drawable.pseudo_fullscreen_animated_success;
            currentCustomization.getResultScreenCustomization().customResultAnimationUnsuccess = R.drawable.pseudo_fullscreen_animated_unsuccess;
            currentCustomization.getResultScreenCustomization().showUploadProgressBar = true;
            currentCustomization.getResultScreenCustomization().uploadProgressTrackColor = Color.parseColor("#332B2B2B");
            currentCustomization.getResultScreenCustomization().uploadProgressFillColor = secondaryColor;
            currentCustomization.getResultScreenCustomization().animationRelativeScale = 1.0f;
            currentCustomization.getResultScreenCustomization().resultAnimationDisplayTime = 2.0;
            currentCustomization.getResultScreenCustomization().faceScanStillUploadingMessageDelayTime = 6.0;
            currentCustomization.getResultScreenCustomization().idScanStillUploadingMessageDelayTime = 8.0;
            // Feedback Customization
            currentCustomization.getFeedbackCustomization().backgroundColors = secondaryColor;
            currentCustomization.getFeedbackCustomization().textColor = backgroundColor;
            currentCustomization.getFeedbackCustomization().textFont = boldTypeface;
            currentCustomization.getFeedbackCustomization().cornerRadius = 5;
            currentCustomization.getFeedbackCustomization().elevation = 10;
            // Frame Customization
            currentCustomization.getFrameCustomization().backgroundColor = backgroundColor;
            currentCustomization.getFrameCustomization().borderColor = primaryColor;
            currentCustomization.getFrameCustomization().borderWidth = 0;
            currentCustomization.getFrameCustomization().cornerRadius = 0;
            currentCustomization.getFrameCustomization().elevation = 0;
            // Oval Customization
            currentCustomization.getOvalCustomization().strokeColor = primaryColor;
            currentCustomization.getOvalCustomization().progressColor1 = Color.parseColor("#BF3BC371");
            currentCustomization.getOvalCustomization().progressColor2 = Color.parseColor("#BF3BC371");
            // Cancel Button Customization
            currentCustomization.getCancelButtonCustomization().customImage = R.drawable.single_chevron_left_offblack;
            currentCustomization.getCancelButtonCustomization().setLocation(FaceTecCancelButtonCustomization.ButtonLocation.CUSTOM);
            currentCustomization.getCancelButtonCustomization().setCustomLocation(new Rect(10, 10, 25, 25));
            currentCustomization.getCancelButtonCustomization().hideForCameraPermissions = false;
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentCustomization.getInitialLoadingAnimationCustomization().backgroundColors = backgroundColor;
            currentCustomization.getInitialLoadingAnimationCustomization().foregroundColor = primaryColor;
            currentCustomization.getInitialLoadingAnimationCustomization().customAnimation = R.drawable.pseudo_fullscreen_animated_activity_indicator;
            currentCustomization.getInitialLoadingAnimationCustomization().customAnimationImage = 0;
            currentCustomization.getInitialLoadingAnimationCustomization().customAnimationImageRotationInterval = 800;
            currentCustomization.getInitialLoadingAnimationCustomization().animationRelativeScale = 1.0f;
            currentCustomization.getInitialLoadingAnimationCustomization().defaultAnimationBackgroundColor = Color.parseColor("#E6E6E6");
            currentCustomization.getInitialLoadingAnimationCustomization().defaultAnimationForegroundColor = primaryColor;
            currentCustomization.getInitialLoadingAnimationCustomization().messageFont = boldTypeface;
            // Orientation Screen Customization
            currentCustomization.getOrientationScreenCustomization().backgroundColors = backgroundColor;
            currentCustomization.getOrientationScreenCustomization().foregroundColor = primaryColor;
            currentCustomization.getOrientationScreenCustomization().messageFont = boldTypeface;
            currentCustomization.getOrientationScreenCustomization().iconImage = 0;

            // Guidance Customization -- Text Style Overrides
            // Ready Screen Header
            currentCustomization.getGuidanceCustomization().readyScreenHeaderFont = boldTypeface;
            currentCustomization.getGuidanceCustomization().readyScreenHeaderTextColor = primaryColor;
            // Ready Screen Subtext
            currentCustomization.getGuidanceCustomization().readyScreenSubtextFont = normalTypeface;
            currentCustomization.getGuidanceCustomization().readyScreenSubtextTextColor = Color.parseColor("#565656");
            // Ready Screen Header
            currentCustomization.getGuidanceCustomization().retryScreenHeaderFont = boldTypeface;
            currentCustomization.getGuidanceCustomization().retryScreenHeaderTextColor = primaryColor;
            // Retry Screen Subtext
            currentCustomization.getGuidanceCustomization().retryScreenSubtextFont = normalTypeface;
            currentCustomization.getGuidanceCustomization().retryScreenSubtextTextColor = Color.parseColor("#565656");
        }
        else if (theme.equals("Well-Rounded")) {
            int primaryColor = Color.parseColor("#09B5A3"); // green
            int primaryColorLight = Color.parseColor("#31DDCC"); // lighter green
            int primaryColorDark = Color.parseColor("#94b8b4"); // darker green
            int backgroundColor = Color.WHITE;
            int backgroundColorDark = Color.parseColor("#d7d7d7"); // grey
            int readyScreenOvalFillColor = Color.parseColor("#0009B5A3"); // transparent green

            Typeface boldTypeface = Typeface.create("sans-serif", Typeface.BOLD);
            Typeface normalTypeface = Typeface.create("sans-serif", Typeface.NORMAL);

            // Overlay Customization
            currentCustomization.getOverlayCustomization().backgroundColor = Color.TRANSPARENT;
            currentCustomization.getOverlayCustomization().showBrandingImage = false;
            currentCustomization.getOverlayCustomization().brandingImage = 0;
            // Guidance Customization
            currentCustomization.getGuidanceCustomization().backgroundColors = backgroundColor;
            currentCustomization.getGuidanceCustomization().foregroundColor = primaryColor;
            currentCustomization.getGuidanceCustomization().headerFont = boldTypeface;
            currentCustomization.getGuidanceCustomization().subtextFont = normalTypeface;
            currentCustomization.getGuidanceCustomization().buttonFont = boldTypeface;
            currentCustomization.getGuidanceCustomization().buttonTextNormalColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().buttonBackgroundNormalColor = primaryColor;
            currentCustomization.getGuidanceCustomization().buttonTextHighlightColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().buttonBackgroundHighlightColor = primaryColorLight;
            currentCustomization.getGuidanceCustomization().buttonTextDisabledColor = backgroundColorDark;
            currentCustomization.getGuidanceCustomization().buttonBackgroundDisabledColor = primaryColorDark;
            currentCustomization.getGuidanceCustomization().buttonBorderColor = Color.TRANSPARENT;
            currentCustomization.getGuidanceCustomization().buttonBorderWidth = 0;
            currentCustomization.getGuidanceCustomization().buttonCornerRadius = 30;
            currentCustomization.getGuidanceCustomization().readyScreenOvalFillColor = readyScreenOvalFillColor;
            currentCustomization.getGuidanceCustomization().readyScreenTextBackgroundColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().readyScreenTextBackgroundCornerRadius = 5;
            currentCustomization.getGuidanceCustomization().retryScreenImageBorderColor = primaryColor;
            currentCustomization.getGuidanceCustomization().retryScreenImageBorderWidth = 2;
            currentCustomization.getGuidanceCustomization().retryScreenImageCornerRadius = 10;
            currentCustomization.getGuidanceCustomization().retryScreenOvalStrokeColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().retryScreenSlideshowImages = new int[0];
            currentCustomization.getGuidanceCustomization().retryScreenSlideshowInterval = 1500;
            currentCustomization.getGuidanceCustomization().enableRetryScreenSlideshowShuffle = true;
            currentCustomization.getGuidanceCustomization().cameraPermissionsScreenImage = R.drawable.camera_green;
            // ID Scan Customization
            currentCustomization.getIdScanCustomization().showSelectionScreenDocumentImage = true;
            currentCustomization.getIdScanCustomization().selectionScreenDocumentImage = R.drawable.document_green;
            currentCustomization.getIdScanCustomization().selectionScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().reviewScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().captureScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().reviewScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().selectionScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureScreenFocusMessageTextColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureScreenFocusMessageFont = normalTypeface;
            currentCustomization.getIdScanCustomization().headerFont = boldTypeface;
            currentCustomization.getIdScanCustomization().subtextFont = normalTypeface;
            currentCustomization.getIdScanCustomization().buttonFont = boldTypeface;
            currentCustomization.getIdScanCustomization().buttonTextNormalColor = backgroundColor;
            currentCustomization.getIdScanCustomization().buttonBackgroundNormalColor = primaryColor;
            currentCustomization.getIdScanCustomization().buttonTextHighlightColor = backgroundColor;
            currentCustomization.getIdScanCustomization().buttonBackgroundHighlightColor = primaryColorLight;
            currentCustomization.getIdScanCustomization().buttonTextDisabledColor = backgroundColorDark;
            currentCustomization.getIdScanCustomization().buttonBackgroundDisabledColor = primaryColorDark;
            currentCustomization.getIdScanCustomization().buttonBorderColor = Color.TRANSPARENT;
            currentCustomization.getIdScanCustomization().buttonBorderWidth = 0;
            currentCustomization.getIdScanCustomization().buttonCornerRadius = 30;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundColor = backgroundColor;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundBorderColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundBorderWidth = 2;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundCornerRadius = 5;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundColor = backgroundColor;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundBorderColor = primaryColor;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundBorderWidth = 2;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundCornerRadius = 5;
            currentCustomization.getIdScanCustomization().captureScreenBackgroundColor = backgroundColor;
            currentCustomization.getIdScanCustomization().captureFrameStrokeColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureFrameStrokeWidth = 2;
            currentCustomization.getIdScanCustomization().captureFrameCornerRadius = 12;
            currentCustomization.getIdScanCustomization().activeTorchButtonImage = R.drawable.torch_active_black;
            currentCustomization.getIdScanCustomization().inactiveTorchButtonImage = R.drawable.torch_inactive_black;
            currentCustomization.getIdScanCustomization().customNFCStartingAnimation = R.drawable.facetec_nfc_starting_animation_green;
            currentCustomization.getIdScanCustomization().customNFCScanningAnimation = R.drawable.facetec_nfc_scanning_animation;
            currentCustomization.getIdScanCustomization().customNFCSkipOrErrorAnimation = R.drawable.warning_green;
            currentCustomization.getIdScanCustomization().additionalReviewScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().additionalReviewScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().additionalReviewScreenImage = 0;
            currentCustomization.getIdScanCustomization().additionalReviewScreenAnimation = R.drawable.facetec_additional_review_animation_green;
            currentCustomization.getIdScanCustomization().idFeedbackScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().idFeedbackScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().idFeedbackScreenFlipIDFrontImage = 0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenFlipIDBackImage = 0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenFlipIDToBackAnimation = 0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenFlipIDToFrontAnimation = 0;
            currentCustomization.getIdScanCustomization().additionalReviewScreenAnimationDisplayTime = 2.0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenAnimationDisplayTime = 2.0;
            currentCustomization.getIdScanCustomization().nfcScreenAnimationDisplayTime = 2.0;
            currentCustomization.getIdScanCustomization().enableAdditionalReviewTag = true;
            currentCustomization.getIdScanCustomization().additionalReviewTagImage = R.drawable.warning_green;
            currentCustomization.getIdScanCustomization().additionalReviewTagImageColor = primaryColor;
            currentCustomization.getIdScanCustomization().additionalReviewTagTextColor = primaryColor;
            // OCR Confirmation Screen Customization
            currentCustomization.getOcrConfirmationCustomization().backgroundColors = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderDividerLineColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderDividerLineWidth = 2;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderFont = boldTypeface;
            currentCustomization.getOcrConfirmationCustomization().sectionHeaderFont = boldTypeface;
            currentCustomization.getOcrConfirmationCustomization().fieldLabelFont = normalTypeface;
            currentCustomization.getOcrConfirmationCustomization().fieldValueFont = normalTypeface;
            currentCustomization.getOcrConfirmationCustomization().inputFieldFont = normalTypeface;
            currentCustomization.getOcrConfirmationCustomization().inputFieldPlaceholderFont = normalTypeface;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().sectionHeaderTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().fieldLabelTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().fieldValueTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().inputFieldTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().inputFieldPlaceholderTextColor = Color.parseColor("#6609B5A3");
            currentCustomization.getOcrConfirmationCustomization().inputFieldBackgroundColor = Color.TRANSPARENT;
            currentCustomization.getOcrConfirmationCustomization().inputFieldBorderColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().inputFieldBorderWidth = 1;
            currentCustomization.getOcrConfirmationCustomization().inputFieldCornerRadius = 15;
            currentCustomization.getOcrConfirmationCustomization().showInputFieldBottomBorderOnly = false;
            currentCustomization.getOcrConfirmationCustomization().buttonFont = boldTypeface;
            currentCustomization.getOcrConfirmationCustomization().buttonTextNormalColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBackgroundNormalColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().buttonTextHighlightColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBackgroundHighlightColor = Color.parseColor("#31DDCC");
            currentCustomization.getOcrConfirmationCustomization().buttonTextDisabledColor = backgroundColorDark;
            currentCustomization.getOcrConfirmationCustomization().buttonBackgroundDisabledColor = primaryColorDark;
            currentCustomization.getOcrConfirmationCustomization().buttonBorderColor = Color.TRANSPARENT;
            currentCustomization.getOcrConfirmationCustomization().buttonBorderWidth = 0;
            currentCustomization.getOcrConfirmationCustomization().buttonCornerRadius = 30;
            currentCustomization.getOcrConfirmationCustomization().customScrollIndicatorAnimation = 0;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundNormalColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundHighlightColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundNormalColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundHighlightColor = primaryColorLight;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBorderColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBorderWidth = 2;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorCornerRadius = -1;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorFont = boldTypeface;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorElevation = 5;
            currentCustomization.getOcrConfirmationCustomization().enableScrollIndicator = true;
            currentCustomization.getOcrConfirmationCustomization().enableScrollIndicatorTextAnimation = true;
            currentCustomization.getOcrConfirmationCustomization().enableFixedConfirmButton = false;
            currentCustomization.getOcrConfirmationCustomization().showScrollIndicatorImage = true;
            // Result Screen Customization
            currentCustomization.getResultScreenCustomization().backgroundColors = backgroundColor;
            currentCustomization.getResultScreenCustomization().foregroundColor = primaryColor;
            currentCustomization.getResultScreenCustomization().messageFont  = boldTypeface;
            currentCustomization.getResultScreenCustomization().activityIndicatorColor = primaryColor;
            currentCustomization.getResultScreenCustomization().customActivityIndicatorImage = 0;
            currentCustomization.getResultScreenCustomization().customActivityIndicatorRotationInterval = 1000;
            currentCustomization.getResultScreenCustomization().customActivityIndicatorAnimation = R.drawable.well_rounded_animated_activity_indicator;
            currentCustomization.getResultScreenCustomization().resultAnimationBackgroundColor = Color.TRANSPARENT;
            currentCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundColor = Color.TRANSPARENT;
            currentCustomization.getResultScreenCustomization().resultAnimationForegroundColor = backgroundColor;
            currentCustomization.getResultScreenCustomization().resultAnimationUnsuccessForegroundColor = backgroundColor;
            currentCustomization.getResultScreenCustomization().resultAnimationIDScanSuccessForegroundColor = backgroundColor;
            currentCustomization.getResultScreenCustomization().resultAnimationNFCSuccessForegroundColor = backgroundColor;
            currentCustomization.getResultScreenCustomization().resultAnimationSuccessBackgroundImage = 0;
            currentCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundImage = 0;
            currentCustomization.getResultScreenCustomization().customResultAnimationIDScanSuccess = R.drawable.well_rounded_animated_success;
            currentCustomization.getResultScreenCustomization().customResultAnimationNFCSuccess = R.drawable.well_rounded_animated_success;
            currentCustomization.getResultScreenCustomization().customResultAnimationSuccess = R.drawable.well_rounded_animated_success;
            currentCustomization.getResultScreenCustomization().customResultAnimationUnsuccess = R.drawable.well_rounded_animated_unsuccess;
            currentCustomization.getResultScreenCustomization().showUploadProgressBar = false;
            currentCustomization.getResultScreenCustomization().uploadProgressTrackColor = Color.parseColor("#33000000");
            currentCustomization.getResultScreenCustomization().uploadProgressFillColor = primaryColor;
            currentCustomization.getResultScreenCustomization().animationRelativeScale = 2.0f;
            currentCustomization.getResultScreenCustomization().resultAnimationDisplayTime = 2.0;
            currentCustomization.getResultScreenCustomization().faceScanStillUploadingMessageDelayTime = 6.0;
            currentCustomization.getResultScreenCustomization().idScanStillUploadingMessageDelayTime = 8.0;
            // Feedback Customization
            currentCustomization.getFeedbackCustomization().backgroundColors = primaryColor;
            currentCustomization.getFeedbackCustomization().textColor = backgroundColor;
            currentCustomization.getFeedbackCustomization().textFont = boldTypeface;
            currentCustomization.getFeedbackCustomization().cornerRadius = 5;
            currentCustomization.getFeedbackCustomization().elevation = 5;
            // Frame Customization
            currentCustomization.getFrameCustomization().backgroundColor = backgroundColor;
            currentCustomization.getFrameCustomization().borderColor = primaryColor;
            currentCustomization.getFrameCustomization().borderWidth = 2;
            currentCustomization.getFrameCustomization().cornerRadius = 20;
            currentCustomization.getFrameCustomization().elevation = 10;
            // Oval Customization
            currentCustomization.getOvalCustomization().strokeColor = primaryColor;
            currentCustomization.getOvalCustomization().progressColor1 = primaryColor;
            currentCustomization.getOvalCustomization().progressColor2 = primaryColor;
            // Cancel Button Customization
            currentCustomization.getCancelButtonCustomization().customImage = R.drawable.cancel_round_green;
            currentCustomization.getCancelButtonCustomization().setLocation(FaceTecCancelButtonCustomization.ButtonLocation.TOP_LEFT);
            currentCustomization.getCancelButtonCustomization().hideForCameraPermissions = false;
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentCustomization.getInitialLoadingAnimationCustomization().backgroundColors = backgroundColor;
            currentCustomization.getInitialLoadingAnimationCustomization().foregroundColor = primaryColor;
            currentCustomization.getInitialLoadingAnimationCustomization().customAnimation = R.drawable.well_rounded_animated_activity_indicator;
            currentCustomization.getInitialLoadingAnimationCustomization().customAnimationImage = 0;
            currentCustomization.getInitialLoadingAnimationCustomization().customAnimationImageRotationInterval = 1000;
            currentCustomization.getInitialLoadingAnimationCustomization().animationRelativeScale = 2.0f;
            currentCustomization.getInitialLoadingAnimationCustomization().defaultAnimationBackgroundColor = Color.parseColor("#E6E6E6");
            currentCustomization.getInitialLoadingAnimationCustomization().defaultAnimationForegroundColor = primaryColor;
            currentCustomization.getInitialLoadingAnimationCustomization().messageFont = boldTypeface;
            // Orientation Screen Customization
            currentCustomization.getOrientationScreenCustomization().backgroundColors = backgroundColor;
            currentCustomization.getOrientationScreenCustomization().foregroundColor = primaryColor;
            currentCustomization.getOrientationScreenCustomization().messageFont = boldTypeface;
            currentCustomization.getOrientationScreenCustomization().iconImage = 0;
        }
        else if (theme.equals("Bitcoin Exchange")) {
            int primaryColor = Color.parseColor("#F79634"); // orange
            int primaryColorLight = Color.parseColor("#F9B36C"); // light orange
            int primaryColorDark = Color.parseColor("#C46608"); // dark orange
            int secondaryColor = Color.parseColor("#FFFF1E"); // yellow
            int backgroundColor = Color.parseColor("#424242"); // dark grey
            int backgroundColorLight = Color.parseColor("#757575"); // grey
            int readyScreenOvalFillColor = Color.parseColor("#00424242"); // transparent dark grey

            Typeface boldTypeface = Typeface.create("sans-serif", Typeface.BOLD);
            Typeface normalTypeface = Typeface.create("sans-serif", Typeface.NORMAL);

            // Overlay Customization
            currentCustomization.getOverlayCustomization().backgroundColor = Color.TRANSPARENT;
            currentCustomization.getOverlayCustomization().showBrandingImage = true;
            currentCustomization.getOverlayCustomization().brandingImage = R.drawable.bitcoin_exchange_logo;
            // Guidance Customization
            currentCustomization.getGuidanceCustomization().backgroundColors = backgroundColor;
            currentCustomization.getGuidanceCustomization().foregroundColor = primaryColor;
            currentCustomization.getGuidanceCustomization().headerFont = boldTypeface;
            currentCustomization.getGuidanceCustomization().subtextFont = normalTypeface;
            currentCustomization.getGuidanceCustomization().buttonFont = boldTypeface;
            currentCustomization.getGuidanceCustomization().buttonTextNormalColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().buttonBackgroundNormalColor = primaryColor;
            currentCustomization.getGuidanceCustomization().buttonTextHighlightColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().buttonBackgroundHighlightColor = primaryColorDark;
            currentCustomization.getGuidanceCustomization().buttonTextDisabledColor = backgroundColorLight;
            currentCustomization.getGuidanceCustomization().buttonBackgroundDisabledColor = primaryColorLight;
            currentCustomization.getGuidanceCustomization().buttonBorderColor = Color.TRANSPARENT;
            currentCustomization.getGuidanceCustomization().buttonBorderWidth = 0;
            currentCustomization.getGuidanceCustomization().buttonCornerRadius = 5;
            currentCustomization.getGuidanceCustomization().readyScreenOvalFillColor = readyScreenOvalFillColor;
            currentCustomization.getGuidanceCustomization().readyScreenTextBackgroundColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().readyScreenTextBackgroundCornerRadius = 5;
            currentCustomization.getGuidanceCustomization().retryScreenImageBorderColor = primaryColor;
            currentCustomization.getGuidanceCustomization().retryScreenImageBorderWidth = 2;
            currentCustomization.getGuidanceCustomization().retryScreenImageCornerRadius = 5;
            currentCustomization.getGuidanceCustomization().retryScreenOvalStrokeColor = primaryColor;
            currentCustomization.getGuidanceCustomization().retryScreenSlideshowImages = new int[0];
            currentCustomization.getGuidanceCustomization().retryScreenSlideshowInterval = 1500;
            currentCustomization.getGuidanceCustomization().enableRetryScreenSlideshowShuffle = true;
            currentCustomization.getGuidanceCustomization().cameraPermissionsScreenImage = R.drawable.camera_orange;
            // ID Scan Customization
            currentCustomization.getIdScanCustomization().showSelectionScreenDocumentImage = true;
            currentCustomization.getIdScanCustomization().selectionScreenDocumentImage = R.drawable.document_orange;
            currentCustomization.getIdScanCustomization().selectionScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().reviewScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().captureScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().reviewScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().selectionScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureScreenFocusMessageTextColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureScreenFocusMessageFont = normalTypeface;
            currentCustomization.getIdScanCustomization().headerFont = boldTypeface;
            currentCustomization.getIdScanCustomization().subtextFont = normalTypeface;
            currentCustomization.getIdScanCustomization().buttonFont = boldTypeface;
            currentCustomization.getIdScanCustomization().buttonTextNormalColor = backgroundColor;
            currentCustomization.getIdScanCustomization().buttonBackgroundNormalColor = primaryColor;
            currentCustomization.getIdScanCustomization().buttonTextHighlightColor = backgroundColor;
            currentCustomization.getIdScanCustomization().buttonBackgroundHighlightColor = primaryColorDark;
            currentCustomization.getIdScanCustomization().buttonTextDisabledColor = backgroundColorLight;
            currentCustomization.getIdScanCustomization().buttonBackgroundDisabledColor = primaryColorLight;
            currentCustomization.getIdScanCustomization().buttonBorderColor = Color.TRANSPARENT;
            currentCustomization.getIdScanCustomization().buttonBorderWidth = 0;
            currentCustomization.getIdScanCustomization().buttonCornerRadius = 5;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundColor = backgroundColor;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundBorderColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundBorderWidth = 0;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundCornerRadius = 8;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundColor = backgroundColor;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundBorderColor = primaryColor;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundBorderWidth = 0;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundCornerRadius = 8;
            currentCustomization.getIdScanCustomization().captureScreenBackgroundColor = backgroundColor;
            currentCustomization.getIdScanCustomization().captureFrameStrokeColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureFrameStrokeWidth = 2;
            currentCustomization.getIdScanCustomization().captureFrameCornerRadius = 12;
            currentCustomization.getIdScanCustomization().activeTorchButtonImage = R.drawable.torch_active_orange;
            currentCustomization.getIdScanCustomization().inactiveTorchButtonImage = R.drawable.torch_inactive_orange;
            currentCustomization.getIdScanCustomization().customNFCStartingAnimation = R.drawable.facetec_nfc_starting_animation;
            currentCustomization.getIdScanCustomization().customNFCScanningAnimation = R.drawable.facetec_nfc_scanning_animation;
            currentCustomization.getIdScanCustomization().customNFCSkipOrErrorAnimation = 0;
            currentCustomization.getIdScanCustomization().additionalReviewScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().additionalReviewScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().additionalReviewScreenImage = 0;
            currentCustomization.getIdScanCustomization().additionalReviewScreenAnimation = 0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().idFeedbackScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().idFeedbackScreenFlipIDFrontImage = 0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenFlipIDBackImage = 0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenFlipIDToBackAnimation = 0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenFlipIDToFrontAnimation = 0;
            currentCustomization.getIdScanCustomization().additionalReviewScreenAnimationDisplayTime = 2.0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenAnimationDisplayTime = 2.0;
            currentCustomization.getIdScanCustomization().nfcScreenAnimationDisplayTime = 2.0;
            currentCustomization.getIdScanCustomization().enableAdditionalReviewTag = true;
            currentCustomization.getIdScanCustomization().additionalReviewTagImage = R.drawable.warning_orange;
            currentCustomization.getIdScanCustomization().additionalReviewTagImageColor = primaryColor;
            currentCustomization.getIdScanCustomization().additionalReviewTagTextColor = primaryColor;
            // OCR Confirmation Screen Customization
            currentCustomization.getOcrConfirmationCustomization().backgroundColors = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderDividerLineColor = secondaryColor;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderDividerLineWidth = 1;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderFont = boldTypeface;
            currentCustomization.getOcrConfirmationCustomization().sectionHeaderFont = boldTypeface;
            currentCustomization.getOcrConfirmationCustomization().fieldLabelFont = normalTypeface;
            currentCustomization.getOcrConfirmationCustomization().fieldValueFont = normalTypeface;
            currentCustomization.getOcrConfirmationCustomization().inputFieldFont = normalTypeface;
            currentCustomization.getOcrConfirmationCustomization().inputFieldPlaceholderFont = normalTypeface;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().sectionHeaderTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().fieldLabelTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().fieldValueTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().inputFieldTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().inputFieldPlaceholderTextColor = Color.parseColor("#66F79634");
            currentCustomization.getOcrConfirmationCustomization().inputFieldBackgroundColor = Color.TRANSPARENT;
            currentCustomization.getOcrConfirmationCustomization().inputFieldBorderColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().inputFieldBorderWidth = 1;
            currentCustomization.getOcrConfirmationCustomization().inputFieldCornerRadius = 5;
            currentCustomization.getOcrConfirmationCustomization().showInputFieldBottomBorderOnly = false;
            currentCustomization.getOcrConfirmationCustomization().buttonFont = boldTypeface;
            currentCustomization.getOcrConfirmationCustomization().buttonTextNormalColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBackgroundNormalColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().buttonTextHighlightColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBackgroundHighlightColor = primaryColorDark;
            currentCustomization.getOcrConfirmationCustomization().buttonTextDisabledColor = backgroundColorLight;
            currentCustomization.getOcrConfirmationCustomization().buttonBackgroundDisabledColor = primaryColorLight;
            currentCustomization.getOcrConfirmationCustomization().buttonBorderColor = Color.TRANSPARENT;
            currentCustomization.getOcrConfirmationCustomization().buttonBorderWidth = 0;
            currentCustomization.getOcrConfirmationCustomization().buttonCornerRadius = 5;
            currentCustomization.getOcrConfirmationCustomization().customScrollIndicatorAnimation = 0;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundNormalColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundHighlightColor = primaryColorDark;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundNormalColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundHighlightColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBorderColor = Color.TRANSPARENT;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBorderWidth = 0;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorCornerRadius = -1;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorFont = boldTypeface;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorElevation = 10;
            currentCustomization.getOcrConfirmationCustomization().enableScrollIndicator = true;
            currentCustomization.getOcrConfirmationCustomization().enableScrollIndicatorTextAnimation = true;
            currentCustomization.getOcrConfirmationCustomization().enableFixedConfirmButton = true;
            currentCustomization.getOcrConfirmationCustomization().showScrollIndicatorImage = false;
            // Result Screen Customization
            currentCustomization.getResultScreenCustomization().backgroundColors = backgroundColor;
            currentCustomization.getResultScreenCustomization().foregroundColor = primaryColor;
            currentCustomization.getResultScreenCustomization().messageFont = boldTypeface;
            currentCustomization.getResultScreenCustomization().activityIndicatorColor = primaryColor;
            currentCustomization.getResultScreenCustomization().customActivityIndicatorImage = R.drawable.activity_indicator_orange;
            currentCustomization.getResultScreenCustomization().customActivityIndicatorRotationInterval = 1500;
            currentCustomization.getResultScreenCustomization().customActivityIndicatorAnimation = 0;
            currentCustomization.getResultScreenCustomization().resultAnimationBackgroundColor = primaryColor;
            currentCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundColor = primaryColor;
            currentCustomization.getResultScreenCustomization().resultAnimationForegroundColor = backgroundColor;
            currentCustomization.getResultScreenCustomization().resultAnimationUnsuccessForegroundColor = backgroundColor;
            currentCustomization.getResultScreenCustomization().resultAnimationIDScanSuccessForegroundColor = primaryColor;
            currentCustomization.getResultScreenCustomization().resultAnimationNFCSuccessForegroundColor = primaryColor;
            currentCustomization.getResultScreenCustomization().resultAnimationSuccessBackgroundImage = 0;
            currentCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundImage = 0;
            currentCustomization.getResultScreenCustomization().customResultAnimationIDScanSuccess = 0;
            currentCustomization.getResultScreenCustomization().customResultAnimationNFCSuccess = 0;
            currentCustomization.getResultScreenCustomization().customResultAnimationSuccess = 0;
            currentCustomization.getResultScreenCustomization().customResultAnimationUnsuccess = 0;
            currentCustomization.getResultScreenCustomization().showUploadProgressBar = true;
            currentCustomization.getResultScreenCustomization().uploadProgressTrackColor = Color.parseColor("#33000000");
            currentCustomization.getResultScreenCustomization().uploadProgressFillColor = primaryColor;
            currentCustomization.getResultScreenCustomization().animationRelativeScale = 1.0f;
            currentCustomization.getResultScreenCustomization().resultAnimationDisplayTime = 2.5;
            currentCustomization.getResultScreenCustomization().faceScanStillUploadingMessageDelayTime = 6.0;
            currentCustomization.getResultScreenCustomization().idScanStillUploadingMessageDelayTime = 8.0;
            // Feedback Customization
            currentCustomization.getFeedbackCustomization().backgroundColors = primaryColor;
            currentCustomization.getFeedbackCustomization().textColor = backgroundColor;
            currentCustomization.getFeedbackCustomization().textFont = boldTypeface;
            currentCustomization.getFeedbackCustomization().cornerRadius = 5;
            currentCustomization.getFeedbackCustomization().elevation = 10;
            // Frame Customization
            currentCustomization.getFrameCustomization().backgroundColor = backgroundColor;
            currentCustomization.getFrameCustomization().borderColor = backgroundColor;
            currentCustomization.getFrameCustomization().borderWidth = 2;
            currentCustomization.getFrameCustomization().cornerRadius = 5;
            currentCustomization.getFrameCustomization().elevation = 10;
            // Oval Customization
            currentCustomization.getOvalCustomization().strokeColor = primaryColor;
            currentCustomization.getOvalCustomization().progressColor1 = secondaryColor;
            currentCustomization.getOvalCustomization().progressColor2 = secondaryColor;
            // Cancel Button Customization
            currentCustomization.getCancelButtonCustomization().customImage = R.drawable.single_chevron_left_orange;
            currentCustomization.getCancelButtonCustomization().setLocation(FaceTecCancelButtonCustomization.ButtonLocation.TOP_LEFT);
            currentCustomization.getCancelButtonCustomization().hideForCameraPermissions = false;
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentCustomization.getInitialLoadingAnimationCustomization().backgroundColors = backgroundColor;
            currentCustomization.getInitialLoadingAnimationCustomization().foregroundColor = primaryColor;
            currentCustomization.getInitialLoadingAnimationCustomization().customAnimation = 0;
            currentCustomization.getInitialLoadingAnimationCustomization().customAnimationImage = 0;
            currentCustomization.getInitialLoadingAnimationCustomization().customAnimationImageRotationInterval = 1000;
            currentCustomization.getInitialLoadingAnimationCustomization().animationRelativeScale = 1.0f;
            currentCustomization.getInitialLoadingAnimationCustomization().defaultAnimationBackgroundColor = backgroundColorLight;
            currentCustomization.getInitialLoadingAnimationCustomization().defaultAnimationForegroundColor = primaryColor;
            currentCustomization.getInitialLoadingAnimationCustomization().messageFont = boldTypeface;
            // Orientation Screen Customization
            currentCustomization.getOrientationScreenCustomization().backgroundColors = backgroundColor;
            currentCustomization.getOrientationScreenCustomization().foregroundColor = primaryColor;
            currentCustomization.getOrientationScreenCustomization().messageFont = boldTypeface;
            currentCustomization.getOrientationScreenCustomization().iconImage = 0;

            // Guidance Customization -- Text Style Overrides
            // Ready Screen Header
            currentCustomization.getGuidanceCustomization().readyScreenHeaderFont = boldTypeface;
            currentCustomization.getGuidanceCustomization().readyScreenHeaderTextColor = primaryColor;
            // Ready Screen Subtext
            currentCustomization.getGuidanceCustomization().readyScreenSubtextFont = normalTypeface;
            currentCustomization.getGuidanceCustomization().readyScreenSubtextTextColor = secondaryColor;
            // Retry Screen Header
            currentCustomization.getGuidanceCustomization().retryScreenHeaderFont = boldTypeface;
            currentCustomization.getGuidanceCustomization().retryScreenHeaderTextColor = primaryColor;
            // Retry Screen Subtext
            currentCustomization.getGuidanceCustomization().retryScreenSubtextFont = normalTypeface;
            currentCustomization.getGuidanceCustomization().retryScreenSubtextTextColor = secondaryColor;

        }
        else if (theme.equals("eKYC")) {
            int primaryColor = Color.parseColor("#ED1C24"); // red
            int primaryColorLight = Color.parseColor("#F79498"); // lighter red
            int secondaryColor = Color.BLACK;
            int backgroundColor = Color.WHITE;
            int buttonTextDisabledColor = Color.parseColor("#4DED1C24");
            int readyScreenOvalFillColor = Color.parseColor("#00FFFFFF"); // transparent white

            // Overlay Customization
            currentCustomization.getOverlayCustomization().backgroundColor = Color.TRANSPARENT;
            currentCustomization.getOverlayCustomization().showBrandingImage = true;
            currentCustomization.getOverlayCustomization().brandingImage = R.drawable.ekyc_logo;
            // Guidance Customization
            currentCustomization.getGuidanceCustomization().backgroundColors = backgroundColor;
            currentCustomization.getGuidanceCustomization().foregroundColor = secondaryColor;
            currentCustomization.getGuidanceCustomization().headerFont = null;
            currentCustomization.getGuidanceCustomization().subtextFont = null;
            currentCustomization.getGuidanceCustomization().buttonFont = null;
            currentCustomization.getGuidanceCustomization().buttonTextNormalColor = primaryColor;
            currentCustomization.getGuidanceCustomization().buttonBackgroundNormalColor = Color.TRANSPARENT;
            currentCustomization.getGuidanceCustomization().buttonTextHighlightColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().buttonBackgroundHighlightColor = primaryColor;
            currentCustomization.getGuidanceCustomization().buttonTextDisabledColor = buttonTextDisabledColor;
            currentCustomization.getGuidanceCustomization().buttonBackgroundDisabledColor = Color.TRANSPARENT;
            currentCustomization.getGuidanceCustomization().buttonBorderColor = primaryColor;
            currentCustomization.getGuidanceCustomization().buttonBorderWidth = 2;
            currentCustomization.getGuidanceCustomization().buttonCornerRadius = 8;
            currentCustomization.getGuidanceCustomization().readyScreenOvalFillColor = readyScreenOvalFillColor;
            currentCustomization.getGuidanceCustomization().readyScreenTextBackgroundColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().readyScreenTextBackgroundCornerRadius = 3;
            currentCustomization.getGuidanceCustomization().retryScreenImageBorderColor = primaryColor;
            currentCustomization.getGuidanceCustomization().retryScreenImageBorderWidth = 2;
            currentCustomization.getGuidanceCustomization().retryScreenImageCornerRadius = 3;
            currentCustomization.getGuidanceCustomization().retryScreenOvalStrokeColor = primaryColor;
            currentCustomization.getGuidanceCustomization().retryScreenSlideshowImages = retryScreenSlideshowImages;
            currentCustomization.getGuidanceCustomization().retryScreenSlideshowInterval = 1500;
            currentCustomization.getGuidanceCustomization().enableRetryScreenSlideshowShuffle = true;
            currentCustomization.getGuidanceCustomization().cameraPermissionsScreenImage = R.drawable.camera_red;
            // ID Scan Customization
            currentCustomization.getIdScanCustomization().showSelectionScreenDocumentImage = false;
            currentCustomization.getIdScanCustomization().selectionScreenDocumentImage = 0;
            currentCustomization.getIdScanCustomization().selectionScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().reviewScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().captureScreenForegroundColor = backgroundColor;
            currentCustomization.getIdScanCustomization().reviewScreenForegroundColor = backgroundColor;
            currentCustomization.getIdScanCustomization().selectionScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureScreenFocusMessageTextColor = secondaryColor;
            currentCustomization.getIdScanCustomization().captureScreenFocusMessageFont = null;
            currentCustomization.getIdScanCustomization().headerFont = null;
            currentCustomization.getIdScanCustomization().subtextFont = null;
            currentCustomization.getIdScanCustomization().buttonFont = null;
            currentCustomization.getIdScanCustomization().buttonTextNormalColor = primaryColor;
            currentCustomization.getIdScanCustomization().buttonBackgroundNormalColor = Color.TRANSPARENT;
            currentCustomization.getIdScanCustomization().buttonTextHighlightColor = backgroundColor;
            currentCustomization.getIdScanCustomization().buttonBackgroundHighlightColor = primaryColor;
            currentCustomization.getIdScanCustomization().buttonTextDisabledColor = buttonTextDisabledColor;
            currentCustomization.getIdScanCustomization().buttonBackgroundDisabledColor = Color.TRANSPARENT;
            currentCustomization.getIdScanCustomization().buttonBorderColor = primaryColor;
            currentCustomization.getIdScanCustomization().buttonBorderWidth = 2;
            currentCustomization.getIdScanCustomization().buttonCornerRadius = 8;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundBorderColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundBorderWidth = 0;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundCornerRadius = 2;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundBorderColor = primaryColor;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundBorderWidth = 0;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundCornerRadius = 2;
            currentCustomization.getIdScanCustomization().captureScreenBackgroundColor = backgroundColor;
            currentCustomization.getIdScanCustomization().captureFrameStrokeColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureFrameStrokeWidth = 2;
            currentCustomization.getIdScanCustomization().captureFrameCornerRadius = 12;
            currentCustomization.getIdScanCustomization().activeTorchButtonImage = R.drawable.torch_active_black;
            currentCustomization.getIdScanCustomization().inactiveTorchButtonImage = R.drawable.torch_inactive_black;
            currentCustomization.getIdScanCustomization().customNFCStartingAnimation = R.drawable.facetec_nfc_starting_animation_red;
            currentCustomization.getIdScanCustomization().customNFCScanningAnimation = R.drawable.facetec_nfc_scanning_animation;
            currentCustomization.getIdScanCustomization().customNFCSkipOrErrorAnimation = R.drawable.ekyc_unsuccess_vector_drawable;
            currentCustomization.getIdScanCustomization().additionalReviewScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().additionalReviewScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().additionalReviewScreenImage = 0;
            currentCustomization.getIdScanCustomization().additionalReviewScreenAnimation = 0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().idFeedbackScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().idFeedbackScreenFlipIDFrontImage = 0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenFlipIDBackImage = 0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenFlipIDToBackAnimation = 0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenFlipIDToFrontAnimation = 0;
            currentCustomization.getIdScanCustomization().additionalReviewScreenAnimationDisplayTime = 2.0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenAnimationDisplayTime = 2.0;
            currentCustomization.getIdScanCustomization().nfcScreenAnimationDisplayTime = 2.0;
            currentCustomization.getIdScanCustomization().enableAdditionalReviewTag = true;
            currentCustomization.getIdScanCustomization().additionalReviewTagImage = 0;
            currentCustomization.getIdScanCustomization().additionalReviewTagImageColor = primaryColor;
            currentCustomization.getIdScanCustomization().additionalReviewTagTextColor = secondaryColor;
            // OCR Confirmation Screen Customization
            currentCustomization.getOcrConfirmationCustomization().backgroundColors = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderDividerLineColor = secondaryColor;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderDividerLineWidth = 2;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderFont = null;
            currentCustomization.getOcrConfirmationCustomization().sectionHeaderFont = null;
            currentCustomization.getOcrConfirmationCustomization().fieldLabelFont = null;
            currentCustomization.getOcrConfirmationCustomization().fieldValueFont = null;
            currentCustomization.getOcrConfirmationCustomization().inputFieldFont = null;
            currentCustomization.getOcrConfirmationCustomization().inputFieldPlaceholderFont = null;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderTextColor = secondaryColor;
            currentCustomization.getOcrConfirmationCustomization().sectionHeaderTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().fieldLabelTextColor = secondaryColor;
            currentCustomization.getOcrConfirmationCustomization().fieldValueTextColor = secondaryColor;
            currentCustomization.getOcrConfirmationCustomization().inputFieldTextColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().inputFieldPlaceholderTextColor = Color.parseColor("#66FFFFFF");
            currentCustomization.getOcrConfirmationCustomization().inputFieldBackgroundColor = secondaryColor;
            currentCustomization.getOcrConfirmationCustomization().inputFieldBorderColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().inputFieldBorderWidth = 0;
            currentCustomization.getOcrConfirmationCustomization().inputFieldCornerRadius = 8;
            currentCustomization.getOcrConfirmationCustomization().showInputFieldBottomBorderOnly = false;
            currentCustomization.getOcrConfirmationCustomization().buttonFont = null;
            currentCustomization.getOcrConfirmationCustomization().buttonTextNormalColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBackgroundNormalColor = Color.TRANSPARENT;
            currentCustomization.getOcrConfirmationCustomization().buttonTextHighlightColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBackgroundHighlightColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().buttonTextDisabledColor = buttonTextDisabledColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBackgroundDisabledColor = Color.TRANSPARENT;
            currentCustomization.getOcrConfirmationCustomization().buttonBorderColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBorderWidth = 2;
            currentCustomization.getOcrConfirmationCustomization().buttonCornerRadius = 8;
            currentCustomization.getOcrConfirmationCustomization().customScrollIndicatorAnimation = R.drawable.ekyc_down_arrow_animated_vector_drawable;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundNormalColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundHighlightColor = primaryColorLight;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundNormalColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundHighlightColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBorderColor = Color.TRANSPARENT;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBorderWidth = 0;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorCornerRadius = 8;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorFont = null;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorElevation = 10;
            currentCustomization.getOcrConfirmationCustomization().enableScrollIndicator = true;
            currentCustomization.getOcrConfirmationCustomization().enableScrollIndicatorTextAnimation = true;
            currentCustomization.getOcrConfirmationCustomization().enableFixedConfirmButton = false;
            currentCustomization.getOcrConfirmationCustomization().showScrollIndicatorImage = true;
            // Result Screen Customization
            currentCustomization.getResultScreenCustomization().backgroundColors = backgroundColor;
            currentCustomization.getResultScreenCustomization().foregroundColor = secondaryColor;
            currentCustomization.getResultScreenCustomization().messageFont  = null;
            currentCustomization.getResultScreenCustomization().activityIndicatorColor = primaryColor;
            currentCustomization.getResultScreenCustomization().customActivityIndicatorImage = 0;
            currentCustomization.getResultScreenCustomization().customActivityIndicatorRotationInterval = 1500;
            currentCustomization.getResultScreenCustomization().customActivityIndicatorAnimation = R.drawable.ekyc_animated_activity_indicator;
            currentCustomization.getResultScreenCustomization().resultAnimationBackgroundColor = Color.TRANSPARENT;
            currentCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundColor = Color.TRANSPARENT;
            currentCustomization.getResultScreenCustomization().resultAnimationForegroundColor = Color.TRANSPARENT;
            currentCustomization.getResultScreenCustomization().resultAnimationUnsuccessForegroundColor = primaryColor;
            currentCustomization.getResultScreenCustomization().resultAnimationIDScanSuccessForegroundColor = Color.TRANSPARENT;
            currentCustomization.getResultScreenCustomization().resultAnimationNFCSuccessForegroundColor = Color.TRANSPARENT;
            currentCustomization.getResultScreenCustomization().resultAnimationSuccessBackgroundImage = 0;
            currentCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundImage = 0;
            currentCustomization.getResultScreenCustomization().customResultAnimationIDScanSuccess = R.drawable.ekyc_success_vector_drawable;
            currentCustomization.getResultScreenCustomization().customResultAnimationNFCSuccess = R.drawable.ekyc_success_vector_drawable;
            currentCustomization.getResultScreenCustomization().customResultAnimationSuccess = R.drawable.ekyc_success_vector_drawable;
            currentCustomization.getResultScreenCustomization().customResultAnimationUnsuccess = R.drawable.ekyc_unsuccess_vector_drawable;
            currentCustomization.getResultScreenCustomization().showUploadProgressBar = false;
            currentCustomization.getResultScreenCustomization().uploadProgressTrackColor = Color.parseColor("#33000000");
            currentCustomization.getResultScreenCustomization().uploadProgressFillColor = primaryColor;
            currentCustomization.getResultScreenCustomization().animationRelativeScale = 1.0f;
            currentCustomization.getResultScreenCustomization().resultAnimationDisplayTime = 2.0;
            currentCustomization.getResultScreenCustomization().faceScanStillUploadingMessageDelayTime = 6.0;
            currentCustomization.getResultScreenCustomization().idScanStillUploadingMessageDelayTime = 8.0;
            // Feedback Customization
            currentCustomization.getFeedbackCustomization().backgroundColors = secondaryColor;
            currentCustomization.getFeedbackCustomization().textColor = backgroundColor;
            currentCustomization.getFeedbackCustomization().textFont = null;
            currentCustomization.getFeedbackCustomization().cornerRadius = 3;
            currentCustomization.getFeedbackCustomization().elevation = 10;
            // Frame Customization
            currentCustomization.getFrameCustomization().backgroundColor = backgroundColor;
            currentCustomization.getFrameCustomization().borderColor = primaryColor;
            currentCustomization.getFrameCustomization().borderWidth = 2;
            currentCustomization.getFrameCustomization().cornerRadius = 8;
            currentCustomization.getFrameCustomization().elevation = 10;
            // Oval Customization
            currentCustomization.getOvalCustomization().strokeColor = primaryColor;
            currentCustomization.getOvalCustomization().progressColor1 = Color.parseColor("#BFED1C24");
            currentCustomization.getOvalCustomization().progressColor2 = Color.parseColor("#BFED1C24");
            // Cancel Button Customization
            currentCustomization.getCancelButtonCustomization().customImage = R.drawable.cancel_box_red;
            currentCustomization.getCancelButtonCustomization().setLocation(FaceTecCancelButtonCustomization.ButtonLocation.TOP_RIGHT);
            currentCustomization.getCancelButtonCustomization().hideForCameraPermissions = false;
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentCustomization.getInitialLoadingAnimationCustomization().backgroundColors = backgroundColor;
            currentCustomization.getInitialLoadingAnimationCustomization().foregroundColor = secondaryColor;
            currentCustomization.getInitialLoadingAnimationCustomization().customAnimation = R.drawable.ekyc_animated_activity_indicator;
            currentCustomization.getInitialLoadingAnimationCustomization().customAnimationImage = 0;
            currentCustomization.getInitialLoadingAnimationCustomization().customAnimationImageRotationInterval = 1500;
            currentCustomization.getInitialLoadingAnimationCustomization().animationRelativeScale = 1.0f;
            currentCustomization.getInitialLoadingAnimationCustomization().defaultAnimationBackgroundColor = backgroundColor;
            currentCustomization.getInitialLoadingAnimationCustomization().defaultAnimationForegroundColor = primaryColor;
            currentCustomization.getInitialLoadingAnimationCustomization().messageFont = null;
            // Orientation Screen Customization
            currentCustomization.getOrientationScreenCustomization().backgroundColors = backgroundColor;
            currentCustomization.getOrientationScreenCustomization().foregroundColor = secondaryColor;
            currentCustomization.getOrientationScreenCustomization().messageFont = null;
            currentCustomization.getOrientationScreenCustomization().iconImage = 0;
        }
        else if (theme.equals("Sample Bank")) {
            int primaryColor = Color.parseColor("#FFFFFF"); // white
            int primaryColorLight = Color.parseColor("#CCFFFFFF"); // white
            int backgroundColor = Color.parseColor("#1D174F"); // navy
            int buttonTextDisabledColor = Color.parseColor("#1d174f");
            int readyScreenOvalFillColor = Color.parseColor("#001D174F"); // transparent navy

            Typeface boldTypeface = Typeface.create("sans-serif", Typeface.BOLD);
            Typeface normalTypeface = Typeface.create("sans-serif", Typeface.NORMAL);

            // Overlay Customization
            currentCustomization.getOverlayCustomization().backgroundColor = Color.TRANSPARENT;
            currentCustomization.getOverlayCustomization().showBrandingImage = true;
            currentCustomization.getOverlayCustomization().brandingImage = R.drawable.sample_bank_logo;
            // Guidance Customization
            currentCustomization.getGuidanceCustomization().backgroundColors = backgroundColor;
            currentCustomization.getGuidanceCustomization().foregroundColor = primaryColor;
            currentCustomization.getGuidanceCustomization().headerFont = boldTypeface;
            currentCustomization.getGuidanceCustomization().subtextFont = normalTypeface;
            currentCustomization.getGuidanceCustomization().buttonFont = boldTypeface;
            currentCustomization.getGuidanceCustomization().buttonTextNormalColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().buttonBackgroundNormalColor = primaryColor;
            currentCustomization.getGuidanceCustomization().buttonTextHighlightColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().buttonBackgroundHighlightColor = primaryColorLight;
            currentCustomization.getGuidanceCustomization().buttonTextDisabledColor = buttonTextDisabledColor;
            currentCustomization.getGuidanceCustomization().buttonBackgroundDisabledColor = primaryColor;
            currentCustomization.getGuidanceCustomization().buttonBorderColor = primaryColor;
            currentCustomization.getGuidanceCustomization().buttonBorderWidth = 2;
            currentCustomization.getGuidanceCustomization().buttonCornerRadius = 2;
            currentCustomization.getGuidanceCustomization().readyScreenOvalFillColor = readyScreenOvalFillColor;
            currentCustomization.getGuidanceCustomization().readyScreenTextBackgroundColor = backgroundColor;
            currentCustomization.getGuidanceCustomization().readyScreenTextBackgroundCornerRadius = 2;
            currentCustomization.getGuidanceCustomization().retryScreenImageBorderColor = primaryColor;
            currentCustomization.getGuidanceCustomization().retryScreenImageBorderWidth = 2;
            currentCustomization.getGuidanceCustomization().retryScreenImageCornerRadius = 2;
            currentCustomization.getGuidanceCustomization().retryScreenOvalStrokeColor = primaryColor;
            currentCustomization.getGuidanceCustomization().retryScreenSlideshowImages = retryScreenSlideshowImages;
            currentCustomization.getGuidanceCustomization().retryScreenSlideshowInterval = 1500;
            currentCustomization.getGuidanceCustomization().enableRetryScreenSlideshowShuffle = false;
            currentCustomization.getGuidanceCustomization().cameraPermissionsScreenImage = R.drawable.camera_white_navy;
            // ID Scan Customization
            currentCustomization.getIdScanCustomization().showSelectionScreenDocumentImage = false;
            currentCustomization.getIdScanCustomization().selectionScreenDocumentImage = 0;
            currentCustomization.getIdScanCustomization().selectionScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().reviewScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().captureScreenForegroundColor = backgroundColor;
            currentCustomization.getIdScanCustomization().reviewScreenForegroundColor = backgroundColor;
            currentCustomization.getIdScanCustomization().selectionScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureScreenFocusMessageTextColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureScreenFocusMessageFont = normalTypeface;
            currentCustomization.getIdScanCustomization().headerFont = boldTypeface;
            currentCustomization.getIdScanCustomization().subtextFont = normalTypeface;
            currentCustomization.getIdScanCustomization().buttonFont = boldTypeface;
            currentCustomization.getIdScanCustomization().buttonTextNormalColor = backgroundColor;
            currentCustomization.getIdScanCustomization().buttonBackgroundNormalColor = primaryColor;
            currentCustomization.getIdScanCustomization().buttonTextHighlightColor = backgroundColor;
            currentCustomization.getIdScanCustomization().buttonBackgroundHighlightColor = primaryColorLight;
            currentCustomization.getIdScanCustomization().buttonTextDisabledColor = buttonTextDisabledColor;
            currentCustomization.getIdScanCustomization().buttonBackgroundDisabledColor = primaryColor;
            currentCustomization.getIdScanCustomization().buttonBorderColor = primaryColor;
            currentCustomization.getIdScanCustomization().buttonBorderWidth = 2;
            currentCustomization.getIdScanCustomization().buttonCornerRadius = 2;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundBorderColor = backgroundColor;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundBorderWidth = 2;
            currentCustomization.getIdScanCustomization().captureScreenTextBackgroundCornerRadius = 2;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundBorderColor = backgroundColor;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundBorderWidth = 2;
            currentCustomization.getIdScanCustomization().reviewScreenTextBackgroundCornerRadius = 2;
            currentCustomization.getIdScanCustomization().captureScreenBackgroundColor = backgroundColor;
            currentCustomization.getIdScanCustomization().captureFrameStrokeColor = primaryColor;
            currentCustomization.getIdScanCustomization().captureFrameStrokeWidth = 2;
            currentCustomization.getIdScanCustomization().captureFrameCornerRadius = 12;
            currentCustomization.getIdScanCustomization().activeTorchButtonImage = R.drawable.torch_active_white;
            currentCustomization.getIdScanCustomization().inactiveTorchButtonImage = R.drawable.torch_inactive_white;
            currentCustomization.getIdScanCustomization().customNFCStartingAnimation = R.drawable.facetec_nfc_starting_animation;
            currentCustomization.getIdScanCustomization().customNFCScanningAnimation = R.drawable.facetec_nfc_scanning_animation;
            currentCustomization.getIdScanCustomization().customNFCSkipOrErrorAnimation = R.drawable.warning_white;
            currentCustomization.getIdScanCustomization().additionalReviewScreenBackgroundColors = backgroundColor;
            currentCustomization.getIdScanCustomization().additionalReviewScreenForegroundColor = primaryColor;
            currentCustomization.getIdScanCustomization().additionalReviewScreenImage = R.drawable.review_white;
            currentCustomization.getIdScanCustomization().additionalReviewScreenAnimation = 0;
            currentCustomization.getIdScanCustomization().additionalReviewScreenAnimationDisplayTime = 2.0;
            currentCustomization.getIdScanCustomization().idFeedbackScreenAnimationDisplayTime = 2.0;
            currentCustomization.getIdScanCustomization().nfcScreenAnimationDisplayTime = 2.0;
            currentCustomization.getIdScanCustomization().enableAdditionalReviewTag = true;
            currentCustomization.getIdScanCustomization().additionalReviewTagImage = R.drawable.warning_white;
            currentCustomization.getIdScanCustomization().additionalReviewTagImageColor = primaryColor;
            currentCustomization.getIdScanCustomization().additionalReviewTagTextColor = primaryColor;
            // OCR Confirmation Screen Customization
            currentCustomization.getOcrConfirmationCustomization().backgroundColors = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderDividerLineColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderDividerLineWidth = 2;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderFont = boldTypeface;
            currentCustomization.getOcrConfirmationCustomization().sectionHeaderFont = boldTypeface;
            currentCustomization.getOcrConfirmationCustomization().fieldLabelFont = normalTypeface;
            currentCustomization.getOcrConfirmationCustomization().fieldValueFont = normalTypeface;
            currentCustomization.getOcrConfirmationCustomization().inputFieldFont = normalTypeface;
            currentCustomization.getOcrConfirmationCustomization().inputFieldPlaceholderFont = normalTypeface;
            currentCustomization.getOcrConfirmationCustomization().mainHeaderTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().sectionHeaderTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().fieldLabelTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().fieldValueTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().inputFieldTextColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().inputFieldPlaceholderTextColor = Color.parseColor("#66FFFFFF");
            currentCustomization.getOcrConfirmationCustomization().inputFieldBackgroundColor = Color.TRANSPARENT;
            currentCustomization.getOcrConfirmationCustomization().inputFieldBorderColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().inputFieldBorderWidth = 2;
            currentCustomization.getOcrConfirmationCustomization().inputFieldCornerRadius = 0;
            currentCustomization.getOcrConfirmationCustomization().showInputFieldBottomBorderOnly = true;
            currentCustomization.getOcrConfirmationCustomization().buttonFont = boldTypeface;
            currentCustomization.getOcrConfirmationCustomization().buttonTextNormalColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBackgroundNormalColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().buttonTextHighlightColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBackgroundHighlightColor = primaryColorLight;
            currentCustomization.getOcrConfirmationCustomization().buttonTextDisabledColor = buttonTextDisabledColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBackgroundDisabledColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBorderColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().buttonBorderWidth = 2;
            currentCustomization.getOcrConfirmationCustomization().buttonCornerRadius = 2;
            currentCustomization.getOcrConfirmationCustomization().customScrollIndicatorAnimation = 0;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundNormalColor = primaryColor;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundHighlightColor = primaryColorLight;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundNormalColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundHighlightColor = backgroundColor;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBorderColor = Color.TRANSPARENT;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorBorderWidth = 0;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorCornerRadius = 2;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorFont = boldTypeface;
            currentCustomization.getOcrConfirmationCustomization().scrollIndicatorElevation = 0;
            currentCustomization.getOcrConfirmationCustomization().enableScrollIndicator = true;
            currentCustomization.getOcrConfirmationCustomization().enableScrollIndicatorTextAnimation = true;
            currentCustomization.getOcrConfirmationCustomization().enableFixedConfirmButton = true;
            currentCustomization.getOcrConfirmationCustomization().showScrollIndicatorImage = false;
            // Result Screen Customization
            currentCustomization.getResultScreenCustomization().backgroundColors = backgroundColor;
            currentCustomization.getResultScreenCustomization().foregroundColor = primaryColor;
            currentCustomization.getResultScreenCustomization().messageFont  = boldTypeface;
            currentCustomization.getResultScreenCustomization().activityIndicatorColor = primaryColor;
            currentCustomization.getResultScreenCustomization().customActivityIndicatorImage = R.drawable.activity_indicator_white;
            currentCustomization.getResultScreenCustomization().customActivityIndicatorRotationInterval = 1000;
            currentCustomization.getResultScreenCustomization().customActivityIndicatorAnimation = 0;
            currentCustomization.getResultScreenCustomization().resultAnimationBackgroundColor = Color.TRANSPARENT;
            currentCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundColor = Color.TRANSPARENT;
            currentCustomization.getResultScreenCustomization().resultAnimationForegroundColor = primaryColor;
            currentCustomization.getResultScreenCustomization().resultAnimationUnsuccessForegroundColor = primaryColor;
            currentCustomization.getResultScreenCustomization().resultAnimationIDScanSuccessForegroundColor = primaryColor;
            currentCustomization.getResultScreenCustomization().resultAnimationNFCSuccessForegroundColor = primaryColor;
            currentCustomization.getResultScreenCustomization().resultAnimationSuccessBackgroundImage = R.drawable.reticle_white;
            currentCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundImage = R.drawable.reticle_white;
            currentCustomization.getResultScreenCustomization().customResultAnimationIDScanSuccess = 0;
            currentCustomization.getResultScreenCustomization().customResultAnimationNFCSuccess = 0;
            currentCustomization.getResultScreenCustomization().customResultAnimationSuccess = 0;
            currentCustomization.getResultScreenCustomization().customResultAnimationUnsuccess = 0;
            currentCustomization.getResultScreenCustomization().showUploadProgressBar = true;
            currentCustomization.getResultScreenCustomization().uploadProgressTrackColor = Color.parseColor("#33FFFFFF");
            currentCustomization.getResultScreenCustomization().uploadProgressFillColor = primaryColor;
            currentCustomization.getResultScreenCustomization().animationRelativeScale = 1.0f;
            currentCustomization.getResultScreenCustomization().resultAnimationDisplayTime = 2.0;
            currentCustomization.getResultScreenCustomization().faceScanStillUploadingMessageDelayTime = 6.0;
            currentCustomization.getResultScreenCustomization().idScanStillUploadingMessageDelayTime = 8.0;
            // Feedback Customization
            currentCustomization.getFeedbackCustomization().backgroundColors = primaryColor;
            currentCustomization.getFeedbackCustomization().textColor = backgroundColor;
            currentCustomization.getFeedbackCustomization().textFont = boldTypeface;
            currentCustomization.getFeedbackCustomization().cornerRadius = 2;
            currentCustomization.getFeedbackCustomization().elevation = 0;
            // Frame Customization
            currentCustomization.getFrameCustomization().backgroundColor = backgroundColor;
            currentCustomization.getFrameCustomization().borderColor = primaryColor;
            currentCustomization.getFrameCustomization().borderWidth = 2;
            currentCustomization.getFrameCustomization().cornerRadius = 2;
            currentCustomization.getFrameCustomization().elevation = 10;
            // Oval Customization
            currentCustomization.getOvalCustomization().strokeColor = primaryColor;
            currentCustomization.getOvalCustomization().progressColor1 = Color.parseColor("#BFFFFFFF");
            currentCustomization.getOvalCustomization().progressColor2 = Color.parseColor("#BFFFFFFF");
            // Cancel Button Customization
            currentCustomization.getCancelButtonCustomization().customImage = R.drawable.cancel_white;
            currentCustomization.getCancelButtonCustomization().setLocation(FaceTecCancelButtonCustomization.ButtonLocation.TOP_LEFT);
            currentCustomization.getCancelButtonCustomization().hideForCameraPermissions = true;
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentCustomization.getInitialLoadingAnimationCustomization().backgroundColors = backgroundColor;
            currentCustomization.getInitialLoadingAnimationCustomization().foregroundColor = primaryColor;
            currentCustomization.getInitialLoadingAnimationCustomization().customAnimation = 0;
            currentCustomization.getInitialLoadingAnimationCustomization().customAnimationImage = 0;
            currentCustomization.getInitialLoadingAnimationCustomization().customAnimationImageRotationInterval = 1000;
            currentCustomization.getInitialLoadingAnimationCustomization().animationRelativeScale = 1.0f;
            currentCustomization.getInitialLoadingAnimationCustomization().defaultAnimationBackgroundColor = Color.parseColor("#33FFFFFF");
            currentCustomization.getInitialLoadingAnimationCustomization().defaultAnimationForegroundColor = primaryColor;
            currentCustomization.getInitialLoadingAnimationCustomization().messageFont = boldTypeface;
            // Orientation Screen Customization
            currentCustomization.getOrientationScreenCustomization().backgroundColors = backgroundColor;
            currentCustomization.getOrientationScreenCustomization().foregroundColor = primaryColor;
            currentCustomization.getOrientationScreenCustomization().messageFont = boldTypeface;
            currentCustomization.getOrientationScreenCustomization().iconImage = 0;
        }

        return currentCustomization;
    }

    static FaceTecCustomization getLowLightCustomizationForTheme(Context context, String theme) {
        FaceTecCustomization currentLowLightCustomization = getCustomizationForTheme(context, theme);

        int[] retryScreenSlideshowImages = new int[]{R.drawable.ideal_image_1, R.drawable.ideal_image_2, R.drawable.ideal_image_3, R.drawable.ideal_image_4, R.drawable.ideal_image_5};

        if (theme.equals("Config Wizard Theme")) {
            currentLowLightCustomization = Config.retrieveLowLightConfigurationWizardCustomization();
        }
        else if (theme.equals("Bitcoin Exchange")) {
            int primaryColor = Color.parseColor("#F79634"); // orange
            int primaryColorLight = Color.parseColor("#F9B36C"); // light orange
            int primaryColorDark = Color.parseColor("#C46608"); // dark orange
            int secondaryColor = Color.parseColor("#FFFF1E"); // yellow
            int backgroundColor = Color.parseColor("#424242"); // dark grey
            int readyScreenOvalFillColor = Color.parseColor("#00FFFFFF"); // transparent white

            // Overlay Customization
            currentLowLightCustomization.getOverlayCustomization().brandingImage = R.drawable.bitcoin_exchange_logo;
            // Guidance Customization
            currentLowLightCustomization.getGuidanceCustomization().foregroundColor = backgroundColor;
            currentLowLightCustomization.getGuidanceCustomization().buttonTextNormalColor = Color.WHITE;
            currentLowLightCustomization.getGuidanceCustomization().buttonBackgroundNormalColor = primaryColor;
            currentLowLightCustomization.getGuidanceCustomization().buttonTextHighlightColor = Color.WHITE;
            currentLowLightCustomization.getGuidanceCustomization().buttonBackgroundHighlightColor = primaryColorDark;
            currentLowLightCustomization.getGuidanceCustomization().buttonTextDisabledColor = Color.WHITE;
            currentLowLightCustomization.getGuidanceCustomization().buttonBackgroundDisabledColor = primaryColorLight;
            currentLowLightCustomization.getGuidanceCustomization().buttonBorderColor = Color.TRANSPARENT;
            currentLowLightCustomization.getGuidanceCustomization().readyScreenOvalFillColor = readyScreenOvalFillColor;
            currentLowLightCustomization.getGuidanceCustomization().readyScreenTextBackgroundColor = Color.WHITE;
            currentLowLightCustomization.getGuidanceCustomization().retryScreenImageBorderColor = primaryColor;
            currentLowLightCustomization.getGuidanceCustomization().retryScreenOvalStrokeColor = primaryColor;
            currentLowLightCustomization.getGuidanceCustomization().retryScreenSlideshowImages = new int[0];
            // ID Scan Customization
            currentLowLightCustomization.getIdScanCustomization().selectionScreenDocumentImage = R.drawable.document_grey;
            currentLowLightCustomization.getIdScanCustomization().captureScreenForegroundColor = Color.WHITE;
            currentLowLightCustomization.getIdScanCustomization().reviewScreenForegroundColor = Color.WHITE;
            currentLowLightCustomization.getIdScanCustomization().selectionScreenForegroundColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().captureScreenFocusMessageTextColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().buttonTextNormalColor = Color.WHITE;
            currentLowLightCustomization.getIdScanCustomization().buttonBackgroundNormalColor = primaryColor;
            currentLowLightCustomization.getIdScanCustomization().buttonTextHighlightColor = Color.WHITE;
            currentLowLightCustomization.getIdScanCustomization().buttonBackgroundHighlightColor = primaryColorDark;
            currentLowLightCustomization.getIdScanCustomization().buttonTextDisabledColor = Color.WHITE;
            currentLowLightCustomization.getIdScanCustomization().buttonBackgroundDisabledColor = primaryColorLight;
            currentLowLightCustomization.getIdScanCustomization().buttonBorderColor = Color.TRANSPARENT;
            currentLowLightCustomization.getIdScanCustomization().captureScreenTextBackgroundColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().captureScreenTextBackgroundBorderColor = Color.TRANSPARENT;
            currentLowLightCustomization.getIdScanCustomization().reviewScreenTextBackgroundColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().reviewScreenTextBackgroundBorderColor = Color.TRANSPARENT;
            currentLowLightCustomization.getIdScanCustomization().captureFrameStrokeColor = primaryColor;
            currentLowLightCustomization.getIdScanCustomization().activeTorchButtonImage = R.drawable.torch_active_orange;
            currentLowLightCustomization.getIdScanCustomization().inactiveTorchButtonImage = R.drawable.torch_inactive_orange;
            currentLowLightCustomization.getIdScanCustomization().customNFCStartingAnimation = R.drawable.facetec_nfc_starting_animation;
            currentLowLightCustomization.getIdScanCustomization().customNFCScanningAnimation = R.drawable.facetec_nfc_scanning_animation;
            currentLowLightCustomization.getIdScanCustomization().customNFCSkipOrErrorAnimation = R.drawable.warning_orange;
            currentLowLightCustomization.getIdScanCustomization().additionalReviewScreenForegroundColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().additionalReviewScreenImage = 0;
            currentLowLightCustomization.getIdScanCustomization().additionalReviewScreenAnimation = R.drawable.facetec_additional_review_animation_green;
            currentLowLightCustomization.getIdScanCustomization().idFeedbackScreenForegroundColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().idFeedbackScreenFlipIDFrontImage = 0;
            currentLowLightCustomization.getIdScanCustomization().idFeedbackScreenFlipIDBackImage = 0;
            currentLowLightCustomization.getIdScanCustomization().idFeedbackScreenFlipIDToBackAnimation = 0;
            currentLowLightCustomization.getIdScanCustomization().idFeedbackScreenFlipIDToFrontAnimation = 0;
            currentLowLightCustomization.getIdScanCustomization().additionalReviewTagImage = R.drawable.warning_orange;
            currentLowLightCustomization.getIdScanCustomization().additionalReviewTagImageColor = primaryColor;
            currentLowLightCustomization.getIdScanCustomization().additionalReviewTagTextColor = backgroundColor;
            // OCR Confirmation Screen Customization
            currentLowLightCustomization.getOcrConfirmationCustomization().mainHeaderDividerLineColor = secondaryColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().mainHeaderTextColor = primaryColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().sectionHeaderTextColor = primaryColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().fieldLabelTextColor = primaryColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().fieldValueTextColor = primaryColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().inputFieldTextColor = primaryColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().inputFieldPlaceholderTextColor = Color.parseColor("#66F79634");
            currentLowLightCustomization.getOcrConfirmationCustomization().inputFieldBackgroundColor = Color.TRANSPARENT;
            currentLowLightCustomization.getOcrConfirmationCustomization().inputFieldBorderColor = primaryColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().buttonTextNormalColor = backgroundColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().buttonBackgroundNormalColor = primaryColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().buttonTextHighlightColor = backgroundColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().buttonBackgroundHighlightColor = primaryColorDark;
            currentLowLightCustomization.getOcrConfirmationCustomization().buttonTextDisabledColor = Color.WHITE;
            currentLowLightCustomization.getOcrConfirmationCustomization().buttonBackgroundDisabledColor = primaryColorLight;
            currentLowLightCustomization.getOcrConfirmationCustomization().buttonBorderColor = Color.TRANSPARENT;
            currentLowLightCustomization.getOcrConfirmationCustomization().customScrollIndicatorAnimation = 0;
            currentLowLightCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundNormalColor = primaryColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundHighlightColor = primaryColorLight;
            currentLowLightCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundNormalColor = backgroundColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundHighlightColor = backgroundColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().scrollIndicatorBorderColor = Color.TRANSPARENT;
            // Result Screen Customization
            currentLowLightCustomization.getResultScreenCustomization().foregroundColor = backgroundColor;
            currentLowLightCustomization.getResultScreenCustomization().activityIndicatorColor = primaryColor;
            currentLowLightCustomization.getResultScreenCustomization().customActivityIndicatorImage = R.drawable.activity_indicator_orange;
            currentLowLightCustomization.getResultScreenCustomization().customActivityIndicatorAnimation = 0;
            currentLowLightCustomization.getResultScreenCustomization().resultAnimationBackgroundColor = primaryColor;
            currentLowLightCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundColor = primaryColor;
            currentLowLightCustomization.getResultScreenCustomization().resultAnimationForegroundColor = Color.WHITE;
            currentLowLightCustomization.getResultScreenCustomization().resultAnimationUnsuccessForegroundColor = Color.WHITE;
            currentLowLightCustomization.getResultScreenCustomization().resultAnimationIDScanSuccessForegroundColor = primaryColor;
            currentLowLightCustomization.getResultScreenCustomization().resultAnimationNFCSuccessForegroundColor = primaryColor;
            currentLowLightCustomization.getResultScreenCustomization().customResultAnimationIDScanSuccess = 0;
            currentLowLightCustomization.getResultScreenCustomization().customResultAnimationNFCSuccess = 0;
            currentLowLightCustomization.getResultScreenCustomization().customResultAnimationSuccess = 0;
            currentLowLightCustomization.getResultScreenCustomization().customResultAnimationUnsuccess = 0;
            currentLowLightCustomization.getResultScreenCustomization().uploadProgressTrackColor = Color.parseColor("#33000000");
            currentLowLightCustomization.getResultScreenCustomization().uploadProgressFillColor = primaryColor;
            // Feedback Customization
            currentLowLightCustomization.getFeedbackCustomization().backgroundColors = primaryColor;
            currentLowLightCustomization.getFeedbackCustomization().textColor = Color.WHITE;
            // Frame Customization
            currentLowLightCustomization.getFrameCustomization().borderColor = backgroundColor;
            // Oval Customization
            currentLowLightCustomization.getOvalCustomization().strokeColor = primaryColor;
            currentLowLightCustomization.getOvalCustomization().progressColor1 = secondaryColor;
            currentLowLightCustomization.getOvalCustomization().progressColor2 = secondaryColor;
            // Cancel Button Customization
            currentLowLightCustomization.getCancelButtonCustomization().customImage = R.drawable.single_chevron_left_orange;
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentLowLightCustomization.getInitialLoadingAnimationCustomization().foregroundColor = backgroundColor;
            currentLowLightCustomization.getInitialLoadingAnimationCustomization().customAnimation = 0;
            currentLowLightCustomization.getInitialLoadingAnimationCustomization().customAnimationImage = 0;
            currentLowLightCustomization.getInitialLoadingAnimationCustomization().defaultAnimationBackgroundColor = primaryColorLight;
            currentLowLightCustomization.getInitialLoadingAnimationCustomization().defaultAnimationForegroundColor = primaryColor;
            // Orientation Screen Customization
            currentLowLightCustomization.getOrientationScreenCustomization().foregroundColor = backgroundColor;
            currentLowLightCustomization.getOrientationScreenCustomization().iconImage = 0;

            // Guidance Customization -- Text Style Overrides
            // Ready Screen Header
            currentLowLightCustomization.getGuidanceCustomization().readyScreenHeaderTextColor = primaryColor;
            // Ready Screen Subtext
            currentLowLightCustomization.getGuidanceCustomization().readyScreenSubtextTextColor = backgroundColor;
            // Retry Screen Header
            currentLowLightCustomization.getGuidanceCustomization().retryScreenHeaderTextColor = primaryColor;
            // Retry Screen Subtext
            currentLowLightCustomization.getGuidanceCustomization().retryScreenSubtextTextColor = backgroundColor;
        }
        else if (theme.equals("Sample Bank")) {
            int primaryColor = Color.WHITE;
            int backgroundColor = Color.parseColor("#1D174F"); // navy
            int backgroundColorLight = Color.parseColor("#BF1D174F"); // lighter navy
            int readyScreenOvalFillColor = Color.parseColor("#00FFFFFF"); // transparent white

            // Overlay Customization
            currentLowLightCustomization.getOverlayCustomization().brandingImage = R.drawable.sample_bank_logo;
            // Guidance Customization
            currentLowLightCustomization.getGuidanceCustomization().foregroundColor = backgroundColor;
            currentLowLightCustomization.getGuidanceCustomization().buttonTextNormalColor = primaryColor;
            currentLowLightCustomization.getGuidanceCustomization().buttonBackgroundNormalColor = backgroundColor;
            currentLowLightCustomization.getGuidanceCustomization().buttonTextHighlightColor = primaryColor;
            currentLowLightCustomization.getGuidanceCustomization().buttonBackgroundHighlightColor = backgroundColorLight;
            currentLowLightCustomization.getGuidanceCustomization().buttonTextDisabledColor = Color.parseColor("#4DFFFFFF");
            currentLowLightCustomization.getGuidanceCustomization().buttonBackgroundDisabledColor = backgroundColor;
            currentLowLightCustomization.getGuidanceCustomization().buttonBorderColor = backgroundColor;
            currentLowLightCustomization.getGuidanceCustomization().readyScreenOvalFillColor = readyScreenOvalFillColor;
            currentLowLightCustomization.getGuidanceCustomization().readyScreenTextBackgroundColor = primaryColor;
            currentLowLightCustomization.getGuidanceCustomization().retryScreenImageBorderColor = backgroundColor;
            currentLowLightCustomization.getGuidanceCustomization().retryScreenOvalStrokeColor = primaryColor;
            currentLowLightCustomization.getGuidanceCustomization().retryScreenSlideshowImages = retryScreenSlideshowImages;
            // ID Scan Customization
            currentLowLightCustomization.getIdScanCustomization().selectionScreenDocumentImage = 0;
            currentLowLightCustomization.getIdScanCustomization().captureScreenForegroundColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().reviewScreenForegroundColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().selectionScreenForegroundColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().captureScreenFocusMessageTextColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().buttonTextNormalColor = primaryColor;
            currentLowLightCustomization.getIdScanCustomization().buttonBackgroundNormalColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().buttonTextHighlightColor = primaryColor;
            currentLowLightCustomization.getIdScanCustomization().buttonBackgroundHighlightColor = backgroundColorLight;
            currentLowLightCustomization.getIdScanCustomization().buttonTextDisabledColor = Color.parseColor("#4DFFFFFF");
            currentLowLightCustomization.getIdScanCustomization().buttonBackgroundDisabledColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().buttonBorderColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().captureScreenTextBackgroundColor = primaryColor;
            currentLowLightCustomization.getIdScanCustomization().captureScreenTextBackgroundBorderColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().reviewScreenTextBackgroundColor = primaryColor;
            currentLowLightCustomization.getIdScanCustomization().reviewScreenTextBackgroundBorderColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().captureFrameStrokeColor = primaryColor;
            currentLowLightCustomization.getIdScanCustomization().activeTorchButtonImage = R.drawable.torch_active_navy;
            currentLowLightCustomization.getIdScanCustomization().inactiveTorchButtonImage = R.drawable.torch_inactive_navy;
            currentLowLightCustomization.getIdScanCustomization().customNFCStartingAnimation = R.drawable.facetec_nfc_starting_animation;
            currentLowLightCustomization.getIdScanCustomization().customNFCScanningAnimation = R.drawable.facetec_nfc_scanning_animation;
            currentLowLightCustomization.getIdScanCustomization().customNFCSkipOrErrorAnimation = R.drawable.warning_navy;
            currentLowLightCustomization.getIdScanCustomization().additionalReviewScreenForegroundColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().additionalReviewScreenImage = R.drawable.review_navy;
            currentLowLightCustomization.getIdScanCustomization().additionalReviewScreenAnimation = 0;
            currentLowLightCustomization.getIdScanCustomization().additionalReviewTagImage = R.drawable.warning_navy;
            currentLowLightCustomization.getIdScanCustomization().additionalReviewTagImageColor = backgroundColor;
            currentLowLightCustomization.getIdScanCustomization().additionalReviewTagTextColor = backgroundColor;
            // OCR Confirmation Screen Customization
            currentLowLightCustomization.getOcrConfirmationCustomization().mainHeaderDividerLineColor = backgroundColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().mainHeaderTextColor = backgroundColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().sectionHeaderTextColor = backgroundColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().fieldLabelTextColor = backgroundColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().fieldValueTextColor = backgroundColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().inputFieldTextColor = backgroundColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().inputFieldPlaceholderTextColor = Color.parseColor("#661D174F");
            currentLowLightCustomization.getOcrConfirmationCustomization().inputFieldBackgroundColor = Color.TRANSPARENT;
            currentLowLightCustomization.getOcrConfirmationCustomization().inputFieldBorderColor = backgroundColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().buttonTextNormalColor = primaryColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().buttonBackgroundNormalColor = backgroundColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().buttonTextHighlightColor = primaryColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().buttonBackgroundHighlightColor = backgroundColorLight;
            currentLowLightCustomization.getOcrConfirmationCustomization().buttonTextDisabledColor = Color.parseColor("#4DFFFFFF");
            currentLowLightCustomization.getOcrConfirmationCustomization().buttonBackgroundDisabledColor = backgroundColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().buttonBorderColor = backgroundColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().customScrollIndicatorAnimation = 0;
            currentLowLightCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundNormalColor = backgroundColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundHighlightColor = backgroundColorLight;
            currentLowLightCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundNormalColor = primaryColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundHighlightColor = primaryColor;
            currentLowLightCustomization.getOcrConfirmationCustomization().scrollIndicatorBorderColor = Color.TRANSPARENT;
            // Result Screen Customization
            currentLowLightCustomization.getResultScreenCustomization().foregroundColor = backgroundColor;
            currentLowLightCustomization.getResultScreenCustomization().activityIndicatorColor = backgroundColor;
            currentLowLightCustomization.getResultScreenCustomization().customActivityIndicatorImage = R.drawable.activity_indicator_navy;
            currentLowLightCustomization.getResultScreenCustomization().customActivityIndicatorAnimation = 0;
            currentLowLightCustomization.getResultScreenCustomization().resultAnimationBackgroundColor = Color.TRANSPARENT;
            currentLowLightCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundColor = Color.TRANSPARENT;
            currentLowLightCustomization.getResultScreenCustomization().resultAnimationForegroundColor = backgroundColor;
            currentLowLightCustomization.getResultScreenCustomization().resultAnimationUnsuccessForegroundColor = backgroundColor;
            currentLowLightCustomization.getResultScreenCustomization().resultAnimationIDScanSuccessForegroundColor = backgroundColor;
            currentLowLightCustomization.getResultScreenCustomization().resultAnimationNFCSuccessForegroundColor = backgroundColor;
            currentLowLightCustomization.getResultScreenCustomization().resultAnimationSuccessBackgroundImage = R.drawable.reticle_navy;
            currentLowLightCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundImage = R.drawable.reticle_navy;
            currentLowLightCustomization.getResultScreenCustomization().customResultAnimationIDScanSuccess = 0;
            currentLowLightCustomization.getResultScreenCustomization().customResultAnimationNFCSuccess = 0;
            currentLowLightCustomization.getResultScreenCustomization().customResultAnimationSuccess = 0;
            currentLowLightCustomization.getResultScreenCustomization().customResultAnimationUnsuccess = 0;
            currentLowLightCustomization.getResultScreenCustomization().uploadProgressTrackColor = Color.parseColor("#33000000");
            currentLowLightCustomization.getResultScreenCustomization().uploadProgressFillColor = backgroundColor;
            // Feedback Customization
            currentLowLightCustomization.getFeedbackCustomization().backgroundColors = backgroundColor;
            currentLowLightCustomization.getFeedbackCustomization().textColor = primaryColor;
            // Frame Customization
            currentLowLightCustomization.getFrameCustomization().borderColor = backgroundColor;
            // Oval Customization
            currentLowLightCustomization.getOvalCustomization().strokeColor = backgroundColor;
            currentLowLightCustomization.getOvalCustomization().progressColor1 = Color.parseColor("#BF1D174F");
            currentLowLightCustomization.getOvalCustomization().progressColor2 = Color.parseColor("#BF1D174F");
            // Cancel Button Customization
            currentLowLightCustomization.getCancelButtonCustomization().customImage = R.drawable.cancel_navy;
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentLowLightCustomization.getInitialLoadingAnimationCustomization().foregroundColor = backgroundColor;
            currentLowLightCustomization.getInitialLoadingAnimationCustomization().customAnimation = 0;
            currentLowLightCustomization.getInitialLoadingAnimationCustomization().customAnimationImage = 0;
            currentLowLightCustomization.getInitialLoadingAnimationCustomization().defaultAnimationBackgroundColor = Color.parseColor("#BF1D174F");
            currentLowLightCustomization.getInitialLoadingAnimationCustomization().defaultAnimationForegroundColor = backgroundColor;
            // Orientation Screen Customization
            currentLowLightCustomization.getOrientationScreenCustomization().foregroundColor = backgroundColor;
            currentLowLightCustomization.getOrientationScreenCustomization().iconImage = 0;
        }

        return currentLowLightCustomization;
    }

    static FaceTecCustomization getDynamicDimmingCustomizationForTheme(Context context, String theme) {
        FaceTecCustomization currentDynamicDimmingCustomization = getCustomizationForTheme(context, theme);

        int[] retryScreenSlideshowImages = new int[]{R.drawable.ideal_image_1, R.drawable.ideal_image_2, R.drawable.ideal_image_3, R.drawable.ideal_image_4, R.drawable.ideal_image_5};

        if (theme.equals("FaceTec Theme")) {
            // ID Scan Customization
            currentDynamicDimmingCustomization.getIdScanCustomization().captureScreenFocusMessageTextColor = Color.WHITE;
            // OCR Confirmation Screen Customization
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().sectionHeaderTextColor = Color.WHITE;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().fieldLabelTextColor = Color.WHITE;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().fieldValueTextColor = Color.WHITE;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().inputFieldTextColor = Color.WHITE;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().inputFieldPlaceholderTextColor = Color.parseColor("#66FFFFFF");
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().inputFieldBorderColor = Color.WHITE;
        }
        else if (theme.equals("Config Wizard Theme")) {
            currentDynamicDimmingCustomization = Config.retrieveDynamicDimmingConfigurationWizardCustomization();
        }
        else if (theme.equals("Pseudo-Fullscreen")) {
            int primaryColor = Color.parseColor("#EEF6F8"); // off-white
            int primaryColorLight = Color.WHITE; // white
            int secondaryColor = Color.parseColor("#3BC371"); // green
            int backgroundColor = Color.BLACK;
            int readyScreenOvalFillColor = Color.TRANSPARENT; // transparent black

            // Overlay Customization
            currentDynamicDimmingCustomization.getOverlayCustomization().brandingImage = 0;
            // Guidance Customization
            currentDynamicDimmingCustomization.getGuidanceCustomization().foregroundColor = primaryColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().buttonTextNormalColor = backgroundColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().buttonBackgroundNormalColor = primaryColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().buttonTextHighlightColor = backgroundColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().buttonBackgroundHighlightColor = Color.WHITE;
            currentDynamicDimmingCustomization.getGuidanceCustomization().buttonTextDisabledColor = backgroundColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().buttonBackgroundDisabledColor = Color.parseColor("#BFEEF6F8");
            currentDynamicDimmingCustomization.getGuidanceCustomization().buttonBorderColor = Color.TRANSPARENT;
            currentDynamicDimmingCustomization.getGuidanceCustomization().readyScreenOvalFillColor = readyScreenOvalFillColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().readyScreenTextBackgroundColor = backgroundColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().retryScreenImageBorderColor = primaryColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().retryScreenOvalStrokeColor = backgroundColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().retryScreenSlideshowImages = retryScreenSlideshowImages;
            // ID Scan Customization
            currentDynamicDimmingCustomization.getIdScanCustomization().selectionScreenDocumentImage = R.drawable.document_offwhite;
            currentDynamicDimmingCustomization.getIdScanCustomization().captureScreenForegroundColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().reviewScreenForegroundColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().selectionScreenForegroundColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().captureScreenFocusMessageTextColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().buttonTextNormalColor = backgroundColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().buttonBackgroundNormalColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().buttonTextHighlightColor = backgroundColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().buttonBackgroundHighlightColor = Color.WHITE;
            currentDynamicDimmingCustomization.getIdScanCustomization().buttonTextDisabledColor = backgroundColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().buttonBackgroundDisabledColor = Color.parseColor("#BFEEF6F8");
            currentDynamicDimmingCustomization.getIdScanCustomization().buttonBorderColor = Color.TRANSPARENT;
            currentDynamicDimmingCustomization.getIdScanCustomization().captureScreenTextBackgroundColor = backgroundColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().captureScreenTextBackgroundBorderColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().reviewScreenTextBackgroundColor = backgroundColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().reviewScreenTextBackgroundBorderColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().captureFrameStrokeColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().activeTorchButtonImage = R.drawable.torch_active_offwhite;
            currentDynamicDimmingCustomization.getIdScanCustomization().inactiveTorchButtonImage = R.drawable.torch_inactive_offwhite;
            currentDynamicDimmingCustomization.getIdScanCustomization().customNFCStartingAnimation = R.drawable.facetec_nfc_starting_animation_black;
            currentDynamicDimmingCustomization.getIdScanCustomization().customNFCScanningAnimation = R.drawable.facetec_nfc_scanning_animation;
            currentDynamicDimmingCustomization.getIdScanCustomization().customNFCSkipOrErrorAnimation = R.drawable.pseudo_fullscreen_animated_unsuccess_offwhite;
            currentDynamicDimmingCustomization.getIdScanCustomization().additionalReviewScreenForegroundColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().additionalReviewScreenImage = R.drawable.review_offwhite;
            currentDynamicDimmingCustomization.getIdScanCustomization().additionalReviewScreenAnimation = 0;
            currentDynamicDimmingCustomization.getIdScanCustomization().idFeedbackScreenForegroundColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().idFeedbackScreenFlipIDFrontImage = 0;
            currentDynamicDimmingCustomization.getIdScanCustomization().idFeedbackScreenFlipIDBackImage = 0;
            currentDynamicDimmingCustomization.getIdScanCustomization().idFeedbackScreenFlipIDToBackAnimation = 0;
            currentDynamicDimmingCustomization.getIdScanCustomization().idFeedbackScreenFlipIDToFrontAnimation = 0;
            currentDynamicDimmingCustomization.getIdScanCustomization().additionalReviewTagImage = 0;
            currentDynamicDimmingCustomization.getIdScanCustomization().additionalReviewTagImageColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().additionalReviewTagTextColor = primaryColor;
            // OCR Confirmation Screen Customization
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().mainHeaderDividerLineColor = secondaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().mainHeaderTextColor = secondaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().sectionHeaderTextColor = primaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().fieldLabelTextColor = primaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().fieldValueTextColor = primaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().inputFieldTextColor = primaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().inputFieldPlaceholderTextColor = Color.parseColor("#663BC371");
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().inputFieldBackgroundColor = Color.TRANSPARENT;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().inputFieldBorderColor = secondaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().buttonTextNormalColor = backgroundColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().buttonBackgroundNormalColor = primaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().buttonTextHighlightColor = backgroundColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().buttonBackgroundHighlightColor = Color.WHITE;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().buttonTextDisabledColor = backgroundColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().buttonBackgroundDisabledColor = Color.parseColor("#BFEEF6F8");
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().buttonBorderColor = Color.TRANSPARENT;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().customScrollIndicatorAnimation = 0;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundNormalColor = primaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundHighlightColor = primaryColorLight;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundNormalColor = backgroundColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundHighlightColor = backgroundColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorBorderColor = Color.TRANSPARENT;
            // Result Screen Customization
            currentDynamicDimmingCustomization.getResultScreenCustomization().foregroundColor = primaryColor;
            currentDynamicDimmingCustomization.getResultScreenCustomization().activityIndicatorColor = primaryColor;
            currentDynamicDimmingCustomization.getResultScreenCustomization().customActivityIndicatorImage = 0;
            currentDynamicDimmingCustomization.getResultScreenCustomization().customActivityIndicatorAnimation = R.drawable.pseudo_fullscreen_animated_activity_indicator_offwhite;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationBackgroundColor = secondaryColor;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundColor = secondaryColor;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationForegroundColor = backgroundColor;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationUnsuccessForegroundColor = backgroundColor;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationIDScanSuccessForegroundColor = primaryColor;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationNFCSuccessForegroundColor = primaryColor;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationSuccessBackgroundImage = 0;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundImage = 0;
            currentDynamicDimmingCustomization.getResultScreenCustomization().customResultAnimationIDScanSuccess = R.drawable.pseudo_fullscreen_animated_success_offwhite;
            currentDynamicDimmingCustomization.getResultScreenCustomization().customResultAnimationNFCSuccess = R.drawable.pseudo_fullscreen_animated_success_offwhite;
            currentDynamicDimmingCustomization.getResultScreenCustomization().customResultAnimationSuccess = R.drawable.pseudo_fullscreen_animated_success_offwhite;
            currentDynamicDimmingCustomization.getResultScreenCustomization().customResultAnimationUnsuccess = R.drawable.pseudo_fullscreen_animated_unsuccess_offwhite;
            currentDynamicDimmingCustomization.getResultScreenCustomization().uploadProgressTrackColor = Color.parseColor("#332B2B2B");
            currentDynamicDimmingCustomization.getResultScreenCustomization().uploadProgressFillColor = secondaryColor;
            // Feedback Customization
            currentDynamicDimmingCustomization.getFeedbackCustomization().backgroundColors = secondaryColor;
            currentDynamicDimmingCustomization.getFeedbackCustomization().textColor = backgroundColor;
            // Frame Customization
            currentDynamicDimmingCustomization.getFrameCustomization().borderColor = primaryColor;
            // Oval Customization
            currentDynamicDimmingCustomization.getOvalCustomization().strokeColor = primaryColor;
            currentDynamicDimmingCustomization.getOvalCustomization().progressColor1 = Color.parseColor("#BF3BC371");
            currentDynamicDimmingCustomization.getOvalCustomization().progressColor2 = Color.parseColor("#BF3BC371");
            // Cancel Button Customization
            currentDynamicDimmingCustomization.getCancelButtonCustomization().customImage = R.drawable.single_chevron_left_offwhite;
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentDynamicDimmingCustomization.getInitialLoadingAnimationCustomization().foregroundColor = primaryColor;
            currentDynamicDimmingCustomization.getInitialLoadingAnimationCustomization().customAnimation = R.drawable.pseudo_fullscreen_animated_activity_indicator_offwhite;
            currentDynamicDimmingCustomization.getInitialLoadingAnimationCustomization().customAnimationImage = 0;
            currentDynamicDimmingCustomization.getInitialLoadingAnimationCustomization().defaultAnimationBackgroundColor = Color.parseColor("#332B2B2B");
            currentDynamicDimmingCustomization.getInitialLoadingAnimationCustomization().defaultAnimationForegroundColor = secondaryColor;
            // Orientation Screen Customization
            currentDynamicDimmingCustomization.getOrientationScreenCustomization().foregroundColor = primaryColor;
            currentDynamicDimmingCustomization.getOrientationScreenCustomization().iconImage = 0;

            // Guidance Customization -- Text Style Overrides
            // Ready Screen Header
            currentDynamicDimmingCustomization.getGuidanceCustomization().readyScreenHeaderTextColor = primaryColor;
            // Ready Screen Subtext
            currentDynamicDimmingCustomization.getGuidanceCustomization().readyScreenSubtextTextColor = primaryColor;
            // Ready Screen Header
            currentDynamicDimmingCustomization.getGuidanceCustomization().retryScreenHeaderTextColor = primaryColor;
            // Retry Screen Subtext
            currentDynamicDimmingCustomization.getGuidanceCustomization().retryScreenSubtextTextColor = primaryColor;
        }
        else if (theme.equals("Well-Rounded")) {
            int backgroundColor = Color.BLACK;

            // OCR Confirmation Screen Customization
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundNormalColor = backgroundColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundHighlightColor = backgroundColor;
        }
        else if (theme.equals("Bitcoin Exchange")) {
            int primaryColor = Color.parseColor("#F79634"); // orange
            int backgroundColor = Color.parseColor("#424242"); // dark grey
            int readyScreenOvalFillColor = Color.TRANSPARENT; // transparent black

            // Overlay Customization
            currentDynamicDimmingCustomization.getOverlayCustomization().brandingImage = R.drawable.bitcoin_exchange_logo_white;
            // Guidance Customization
            currentDynamicDimmingCustomization.getGuidanceCustomization().readyScreenOvalFillColor = readyScreenOvalFillColor;
            // ID Scan Customization
            currentDynamicDimmingCustomization.getIdScanCustomization().additionalReviewTagImage = R.drawable.warning_orange;
            currentDynamicDimmingCustomization.getIdScanCustomization().additionalReviewTagImageColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().additionalReviewTagTextColor = primaryColor;
            // Result Screen Customization
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationBackgroundColor = primaryColor;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundColor = primaryColor;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationForegroundColor = Color.BLACK;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationUnsuccessForegroundColor = Color.BLACK;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationIDScanSuccessForegroundColor = primaryColor;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationNFCSuccessForegroundColor = primaryColor;
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentDynamicDimmingCustomization.getInitialLoadingAnimationCustomization().foregroundColor = primaryColor;
            currentDynamicDimmingCustomization.getInitialLoadingAnimationCustomization().customAnimation = 0;
            currentDynamicDimmingCustomization.getInitialLoadingAnimationCustomization().customAnimationImage = 0;
            currentDynamicDimmingCustomization.getInitialLoadingAnimationCustomization().defaultAnimationBackgroundColor = backgroundColor;
            currentDynamicDimmingCustomization.getInitialLoadingAnimationCustomization().defaultAnimationForegroundColor = primaryColor;
            // Orientation Screen Customization
            currentDynamicDimmingCustomization.getOrientationScreenCustomization().foregroundColor = primaryColor;
            currentDynamicDimmingCustomization.getOrientationScreenCustomization().iconImage = 0;
        }
        else if (theme.equals("eKYC")) {
            int primaryColor = Color.parseColor("#ED1C24"); // red
            int primaryColorLight = Color.parseColor("#CCED1C24"); // red
            int secondaryColor = Color.WHITE;
            int backgroundColor = Color.BLACK;
            int readyScreenOvalFillColor = Color.TRANSPARENT; // transparent black

            // Overlay Customization
            currentDynamicDimmingCustomization.getOverlayCustomization().brandingImage = R.drawable.ekyc_logo_white;
            // Guidance Customization
            currentDynamicDimmingCustomization.getGuidanceCustomization().foregroundColor = secondaryColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().buttonTextNormalColor = primaryColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().buttonBackgroundNormalColor = Color.TRANSPARENT;
            currentDynamicDimmingCustomization.getGuidanceCustomization().buttonTextHighlightColor = backgroundColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().buttonBackgroundHighlightColor = primaryColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().buttonTextDisabledColor = Color.parseColor("#4DED1C24");
            currentDynamicDimmingCustomization.getGuidanceCustomization().buttonBackgroundDisabledColor = Color.TRANSPARENT;
            currentDynamicDimmingCustomization.getGuidanceCustomization().buttonBorderColor = primaryColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().readyScreenOvalFillColor = readyScreenOvalFillColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().readyScreenTextBackgroundColor = backgroundColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().retryScreenImageBorderColor = primaryColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().retryScreenOvalStrokeColor = primaryColor;
            currentDynamicDimmingCustomization.getGuidanceCustomization().retryScreenSlideshowImages = retryScreenSlideshowImages;
            // ID Scan Customization
            currentDynamicDimmingCustomization.getIdScanCustomization().selectionScreenDocumentImage = 0;
            currentDynamicDimmingCustomization.getIdScanCustomization().captureScreenForegroundColor = backgroundColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().reviewScreenForegroundColor = backgroundColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().selectionScreenForegroundColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().captureScreenFocusMessageTextColor = secondaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().buttonTextNormalColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().buttonBackgroundNormalColor = Color.TRANSPARENT;
            currentDynamicDimmingCustomization.getIdScanCustomization().buttonTextHighlightColor = backgroundColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().buttonBackgroundHighlightColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().buttonTextDisabledColor = Color.parseColor("#4DED1C24");
            currentDynamicDimmingCustomization.getIdScanCustomization().buttonBackgroundDisabledColor = Color.TRANSPARENT;
            currentDynamicDimmingCustomization.getIdScanCustomization().buttonBorderColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().captureScreenTextBackgroundColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().captureScreenTextBackgroundBorderColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().reviewScreenTextBackgroundColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().reviewScreenTextBackgroundBorderColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().captureFrameStrokeColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().activeTorchButtonImage = R.drawable.torch_active_offwhite;
            currentDynamicDimmingCustomization.getIdScanCustomization().inactiveTorchButtonImage = R.drawable.torch_inactive_offwhite;
            currentDynamicDimmingCustomization.getIdScanCustomization().customNFCScanningAnimation = R.drawable.facetec_nfc_scanning_animation;
            currentDynamicDimmingCustomization.getIdScanCustomization().customNFCStartingAnimation = R.drawable.facetec_nfc_starting_animation_red;
            currentDynamicDimmingCustomization.getIdScanCustomization().customNFCSkipOrErrorAnimation = R.drawable.ekyc_unsuccess_white_vector_drawable;
            currentDynamicDimmingCustomization.getIdScanCustomization().additionalReviewScreenForegroundColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().additionalReviewScreenImage = 0;
            currentDynamicDimmingCustomization.getIdScanCustomization().additionalReviewScreenAnimation = 0;
            currentDynamicDimmingCustomization.getIdScanCustomization().idFeedbackScreenForegroundColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().idFeedbackScreenFlipIDFrontImage = 0;
            currentDynamicDimmingCustomization.getIdScanCustomization().idFeedbackScreenFlipIDBackImage = 0;
            currentDynamicDimmingCustomization.getIdScanCustomization().idFeedbackScreenFlipIDToBackAnimation = 0;
            currentDynamicDimmingCustomization.getIdScanCustomization().idFeedbackScreenFlipIDToFrontAnimation = 0;
            currentDynamicDimmingCustomization.getIdScanCustomization().additionalReviewTagImage = 0;
            currentDynamicDimmingCustomization.getIdScanCustomization().additionalReviewTagImageColor = primaryColor;
            currentDynamicDimmingCustomization.getIdScanCustomization().additionalReviewTagTextColor = secondaryColor;
            // OCR Confirmation Screen Customization
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().mainHeaderDividerLineColor = secondaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().mainHeaderTextColor = secondaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().sectionHeaderTextColor = primaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().fieldLabelTextColor = secondaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().fieldValueTextColor = secondaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().inputFieldTextColor = backgroundColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().inputFieldPlaceholderTextColor = Color.parseColor("#66000000");
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().inputFieldBackgroundColor = secondaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().inputFieldBorderColor = primaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().buttonTextNormalColor = primaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().buttonBackgroundNormalColor = Color.TRANSPARENT;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().buttonTextHighlightColor = backgroundColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().buttonBackgroundHighlightColor = primaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().buttonTextDisabledColor = Color.parseColor("#4DED1C24");
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().buttonBackgroundDisabledColor = Color.TRANSPARENT;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().buttonBorderColor = primaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().customScrollIndicatorAnimation = 0;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundNormalColor = primaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundHighlightColor = primaryColorLight;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundNormalColor = backgroundColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundHighlightColor = backgroundColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorBorderColor = Color.TRANSPARENT;
            // Result Screen Customization
            currentDynamicDimmingCustomization.getResultScreenCustomization().backgroundColors = backgroundColor;
            currentDynamicDimmingCustomization.getResultScreenCustomization().foregroundColor = secondaryColor;
            currentDynamicDimmingCustomization.getResultScreenCustomization().activityIndicatorColor = primaryColor;
            currentDynamicDimmingCustomization.getResultScreenCustomization().customActivityIndicatorImage = 0;
            currentDynamicDimmingCustomization.getResultScreenCustomization().customActivityIndicatorAnimation = R.drawable.ekyc_animated_activity_indicator;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationBackgroundColor = Color.TRANSPARENT;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundColor = Color.TRANSPARENT;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationForegroundColor = Color.TRANSPARENT;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationUnsuccessForegroundColor = primaryColor;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationIDScanSuccessForegroundColor = Color.TRANSPARENT;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationNFCSuccessForegroundColor = Color.TRANSPARENT;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationSuccessBackgroundImage = 0;
            currentDynamicDimmingCustomization.getResultScreenCustomization().resultAnimationUnsuccessBackgroundImage = 0;
            currentDynamicDimmingCustomization.getResultScreenCustomization().customResultAnimationIDScanSuccess = R.drawable.ekyc_success_white_vector_drawable;
            currentDynamicDimmingCustomization.getResultScreenCustomization().customResultAnimationNFCSuccess = R.drawable.ekyc_success_white_vector_drawable;
            currentDynamicDimmingCustomization.getResultScreenCustomization().customResultAnimationSuccess = R.drawable.ekyc_success_white_vector_drawable;
            currentDynamicDimmingCustomization.getResultScreenCustomization().customResultAnimationUnsuccess = R.drawable.ekyc_unsuccess_white_vector_drawable;
            currentDynamicDimmingCustomization.getResultScreenCustomization().uploadProgressTrackColor = Color.parseColor("#33FFFFFF");
            currentDynamicDimmingCustomization.getResultScreenCustomization().uploadProgressFillColor = primaryColor;
            // Feedback Customization
            currentDynamicDimmingCustomization.getFeedbackCustomization().backgroundColors = secondaryColor;
            currentDynamicDimmingCustomization.getFeedbackCustomization().textColor = backgroundColor;
            // Frame Customization
            currentDynamicDimmingCustomization.getFrameCustomization().borderColor = primaryColor;
            // Oval Customization
            currentDynamicDimmingCustomization.getOvalCustomization().strokeColor = primaryColor;
            currentDynamicDimmingCustomization.getOvalCustomization().progressColor1 = Color.parseColor("#BFED1C24");
            currentDynamicDimmingCustomization.getOvalCustomization().progressColor2 = Color.parseColor("#BFED1C24");
            // Cancel Button Customization
            currentDynamicDimmingCustomization.getCancelButtonCustomization().customImage = R.drawable.cancel_box_red;
            // Securing Camera Screen Customization (Exclusive to Photo ID Scan Only Mode)
            currentDynamicDimmingCustomization.getInitialLoadingAnimationCustomization().foregroundColor = secondaryColor;
            currentDynamicDimmingCustomization.getInitialLoadingAnimationCustomization().customAnimation = R.drawable.ekyc_animated_activity_indicator;
            currentDynamicDimmingCustomization.getInitialLoadingAnimationCustomization().customAnimationImage = 0;
            currentDynamicDimmingCustomization.getInitialLoadingAnimationCustomization().defaultAnimationBackgroundColor = Color.parseColor("#33FFFFFF");
            currentDynamicDimmingCustomization.getInitialLoadingAnimationCustomization().defaultAnimationForegroundColor = primaryColor;
            // Orientation Screen Customization
            currentDynamicDimmingCustomization.getOrientationScreenCustomization().foregroundColor = secondaryColor;
            currentDynamicDimmingCustomization.getOrientationScreenCustomization().iconImage = 0;
        }
        else if (theme.equals("Sample Bank")) {
            int primaryColor = Color.BLACK;
            int backgroundColor = Color.parseColor("#1D174F"); // navy
            int backgroundColorLight = Color.parseColor("#BF1D174F"); // lighter navy
            int readyScreenOvalFillColor = Color.TRANSPARENT; // transparent black

            // Guidance Customization
            currentDynamicDimmingCustomization.getGuidanceCustomization().readyScreenOvalFillColor = readyScreenOvalFillColor;
            // OCR Confirmation Screen Customization
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().customScrollIndicatorAnimation = 0;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundNormalColor = backgroundColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorBackgroundHighlightColor = backgroundColorLight;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundNormalColor = primaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorForegroundHighlightColor = primaryColor;
            currentDynamicDimmingCustomization.getOcrConfirmationCustomization().scrollIndicatorBorderColor = Color.TRANSPARENT;
        }

        return currentDynamicDimmingCustomization;
    }
}
