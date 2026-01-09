package Utilities;

import android.app.AlertDialog;
import android.content.Context;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.os.Build;
import android.util.Log;
import android.view.ContextThemeWrapper;
import android.view.View;
import android.view.ViewGroup;

import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.databinding.DataBindingUtil;

import com.facetec.sampleapp.Config;
import com.facetec.sampleapp.R;
import com.facetec.sampleapp.SampleAppActivity;
import com.facetec.sdk.FaceTecSDK;
import com.facetec.sdk.FaceTecVocalGuidanceCustomization;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

public class SampleAppUtilities {
    enum VocalGuidanceMode {
        OFF,
        MINIMAL,
        FULL
    }

    static MediaPlayer vocalGuidanceOnPlayer;
    static MediaPlayer vocalGuidanceOffPlayer;
    static SampleAppUtilities.VocalGuidanceMode vocalGuidanceMode = VocalGuidanceMode.MINIMAL;
    public static String currentTheme = "Config Wizard Theme";


    public static void setupAllButtons(SampleAppActivity sampleAppActivity) {
        sampleAppActivity.runOnUiThread(() -> {
            sampleAppActivity.activityMainBinding.enrollButton.setupButton(sampleAppActivity);
            sampleAppActivity.activityMainBinding.verifyButton.setupButton(sampleAppActivity);
            sampleAppActivity.activityMainBinding.livenessCheckButton.setupButton(sampleAppActivity);
            sampleAppActivity.activityMainBinding.identityCheckButton.setupButton(sampleAppActivity);
            sampleAppActivity.activityMainBinding.identityScanOnlyButton.setupButton(sampleAppActivity);
            sampleAppActivity.activityMainBinding.settingsButton.setupButton(sampleAppActivity);
            sampleAppActivity.activityMainBinding.officialIDPhotoButton.setupButton(sampleAppActivity);
            sampleAppActivity.activityMainBinding.vocalGuidanceSettingButton.setOnClickListener(sampleAppActivity::onVocalGuidanceSettingsButtonPressed);
        });
    }

    public static void disableAllButtons(SampleAppActivity sampleAppActivity) {
        sampleAppActivity.runOnUiThread(() -> {
            sampleAppActivity.activityMainBinding.enrollButton.setEnabled(false, true);
            sampleAppActivity.activityMainBinding.verifyButton.setEnabled(false, true);
            sampleAppActivity.activityMainBinding.livenessCheckButton.setEnabled(false, true);
            sampleAppActivity.activityMainBinding.identityCheckButton.setEnabled(false, true);
            sampleAppActivity.activityMainBinding.identityScanOnlyButton.setEnabled(false, true);
            sampleAppActivity.activityMainBinding.settingsButton.setEnabled(false, true);
            sampleAppActivity.activityMainBinding.officialIDPhotoButton.setEnabled(false, true);
        });
    }

    public static void enableAllButtons(SampleAppActivity sampleAppActivity) {
        sampleAppActivity.runOnUiThread(() -> {
            sampleAppActivity.activityMainBinding.enrollButton.setEnabled(true, true);
            sampleAppActivity.activityMainBinding.verifyButton.setEnabled(true, true);
            sampleAppActivity.activityMainBinding.livenessCheckButton.setEnabled(true, true);
            sampleAppActivity.activityMainBinding.identityCheckButton.setEnabled(true, true);
            sampleAppActivity.activityMainBinding.identityScanOnlyButton.setEnabled(true, true);
            sampleAppActivity.activityMainBinding.settingsButton.setEnabled(true, true);
            sampleAppActivity.activityMainBinding.officialIDPhotoButton.setEnabled(true, true);
        });
    }

    // Disable buttons to prevent hammering, fade out main interface elements, and shuffle the guidance images.
    public static void fadeOutMainUIAndPrepareForFaceTecSDK(SampleAppActivity sampleAppActivity, final Runnable callback) {
        disableAllButtons(sampleAppActivity);
        sampleAppActivity.runOnUiThread(() -> {
            sampleAppActivity.activityMainBinding.vocalGuidanceSettingButton.animate().alpha(0f).setDuration(600).start();
            sampleAppActivity.activityMainBinding.themeTransitionImageView.animate().alpha(1f).setDuration(600).start();
            sampleAppActivity.activityMainBinding.contentLayout.animate().alpha(0f).setDuration(600).withEndAction(callback).start();
        });
    }

    public static void fadeInMainUI(SampleAppActivity sampleAppActivity) {
        enableAllButtons(sampleAppActivity);
        sampleAppActivity.runOnUiThread(() -> {
                sampleAppActivity.activityMainBinding.vocalGuidanceSettingButton.animate().alpha(1f).setDuration(600);
                sampleAppActivity.activityMainBinding.contentLayout.animate().alpha(1f).setDuration(600);
                sampleAppActivity.activityMainBinding.themeTransitionImageView.animate().alpha(0f).setDuration(600);
            }
        );
    }

    public static void displayStatus(SampleAppActivity sampleAppActivity, final String statusString) {
        displayStatus(sampleAppActivity, statusString, true);
    }

    public static void displayStatus(SampleAppActivity sampleAppActivity, final String statusString, boolean shouldLog) {
        if (shouldLog) {
            Log.d("FaceTecSDKSampleApp", statusString);
        }
        
        sampleAppActivity.runOnUiThread(() -> sampleAppActivity.activityMainBinding.statusLabel.setText(statusString));
    }

    public static void showThemeSelectionMenu(SampleAppActivity sampleAppActivity) {
        final String[] themes = new String[] { "Config Wizard Theme", "FaceTec Theme", "Pseudo-Fullscreen", "Well-Rounded", "Bitcoin Exchange", "eKYC", "Sample Bank"};

        AlertDialog.Builder builder = new AlertDialog.Builder(new ContextThemeWrapper(sampleAppActivity, android.R.style.Theme_Holo_Light));
        builder.setTitle("Select a Theme:");
        builder.setItems(themes, (dialog, index) -> {
            currentTheme = themes[index];
            ThemeHelpers.setAppTheme(sampleAppActivity, currentTheme);
            updateThemeTransitionView(sampleAppActivity);
        });
        builder.show();
    }

    public static void updateThemeTransitionView(SampleAppActivity sampleAppActivity) {
        int transitionViewImage = 0;
        int transitionViewTextColor = Config.currentCustomization.getGuidanceCustomization().foregroundColor;
        switch (currentTheme) {
            case "FaceTec Theme":
                break;
            case "Config Wizard Theme":
                break;
            case "Pseudo-Fullscreen":
                break;
            case "Well-Rounded":
                transitionViewImage = R.drawable.well_rounded_bg;
                transitionViewTextColor = Config.currentCustomization.getFrameCustomization().backgroundColor;
                break;
            case "Bitcoin Exchange":
                transitionViewImage = R.drawable.bitcoin_exchange_bg;
                transitionViewTextColor = Config.currentCustomization.getFrameCustomization().backgroundColor;
                break;
            case "eKYC":
                transitionViewImage = R.drawable.ekyc_bg;
                break;
            case "Sample Bank":
                transitionViewImage = R.drawable.sample_bank_bg;
                transitionViewTextColor = Config.currentCustomization.getFrameCustomization().backgroundColor;
                break;
            default:
                break;
        }

        sampleAppActivity.activityMainBinding.themeTransitionImageView.setImageResource(transitionViewImage);
        sampleAppActivity.activityMainBinding.themeTransitionText.setTextColor(transitionViewTextColor);
    }

    public static void setUpVocalGuidancePlayers(SampleAppActivity sampleAppActivity) {
        vocalGuidanceOnPlayer = MediaPlayer.create(sampleAppActivity, R.raw.vocal_guidance_on);
        vocalGuidanceOffPlayer = MediaPlayer.create(sampleAppActivity, R.raw.vocal_guidance_off);
        vocalGuidanceMode = SampleAppUtilities.VocalGuidanceMode.MINIMAL;
        sampleAppActivity.runOnUiThread(() -> sampleAppActivity.activityMainBinding.vocalGuidanceSettingButton.setEnabled(true));
    }

    public static void setVocalGuidanceMode(SampleAppActivity sampleAppActivity) {
        if (isDeviceMuted(sampleAppActivity)) {
            AlertDialog alertDialog = new AlertDialog.Builder(new ContextThemeWrapper(sampleAppActivity, android.R.style.Theme_Holo_Light)).create();
            alertDialog.setMessage("Vocal Guidance is disabled when the device is muted");
            alertDialog.setButton(AlertDialog.BUTTON_NEUTRAL, "OK",
                    (dialog, which) -> dialog.dismiss());
            alertDialog.show();
            return;
        }

        if (vocalGuidanceOnPlayer == null || vocalGuidanceOffPlayer == null || vocalGuidanceOnPlayer.isPlaying() || vocalGuidanceOffPlayer.isPlaying()) {
            return;
        }

        sampleAppActivity.runOnUiThread(() -> {
            switch (vocalGuidanceMode) {
                case OFF:
                    vocalGuidanceMode = VocalGuidanceMode.MINIMAL;
                    sampleAppActivity.activityMainBinding.vocalGuidanceSettingButton.setImageResource(R.drawable.vocal_minimal);
                    vocalGuidanceOnPlayer.start();
                    Config.currentCustomization.vocalGuidanceCustomization.mode = FaceTecVocalGuidanceCustomization.VocalGuidanceMode.MINIMAL_VOCAL_GUIDANCE;
                    break;
                case MINIMAL:
                    vocalGuidanceMode = VocalGuidanceMode.FULL;
                    sampleAppActivity.activityMainBinding.vocalGuidanceSettingButton.setImageResource(R.drawable.vocal_full);
                    vocalGuidanceOnPlayer.start();
                    Config.currentCustomization.vocalGuidanceCustomization.mode = FaceTecVocalGuidanceCustomization.VocalGuidanceMode.FULL_VOCAL_GUIDANCE;
                    break;
                case FULL:
                    vocalGuidanceMode = VocalGuidanceMode.OFF;
                    sampleAppActivity.activityMainBinding.vocalGuidanceSettingButton.setImageResource(R.drawable.vocal_off);
                    vocalGuidanceOffPlayer.start();
                    Config.currentCustomization.vocalGuidanceCustomization.mode = FaceTecVocalGuidanceCustomization.VocalGuidanceMode.NO_VOCAL_GUIDANCE;
                    break;
            }

            SampleAppUtilities.setVocalGuidanceSoundFiles();
            FaceTecSDK.setCustomization(Config.currentCustomization);
        });
    }

    public static void setVocalGuidanceSoundFiles() {
        Config.currentCustomization.vocalGuidanceCustomization.pleaseFrameYourFaceInTheOvalSoundFile = R.raw.please_frame_your_face_sound_file;
        Config.currentCustomization.vocalGuidanceCustomization.pleaseMoveCloserSoundFile = R.raw.please_move_closer_sound_file;
        Config.currentCustomization.vocalGuidanceCustomization.pleaseRetrySoundFile = R.raw.please_retry_sound_file;
        Config.currentCustomization.vocalGuidanceCustomization.uploadingSoundFile = R.raw.uploading_sound_file;
        Config.currentCustomization.vocalGuidanceCustomization.facescanSuccessfulSoundFile = R.raw.facescan_successful_sound_file;
        Config.currentCustomization.vocalGuidanceCustomization.pleasePressTheButtonToStartSoundFile = R.raw.please_press_button_sound_file;

        switch (vocalGuidanceMode) {
            case OFF:
                Config.currentCustomization.vocalGuidanceCustomization.mode = FaceTecVocalGuidanceCustomization.VocalGuidanceMode.NO_VOCAL_GUIDANCE;
                break;
            case MINIMAL:
                Config.currentCustomization.vocalGuidanceCustomization.mode = FaceTecVocalGuidanceCustomization.VocalGuidanceMode.MINIMAL_VOCAL_GUIDANCE;
                break;
            case FULL:
                Config.currentCustomization.vocalGuidanceCustomization.mode = FaceTecVocalGuidanceCustomization.VocalGuidanceMode.FULL_VOCAL_GUIDANCE;
                break;
        }
    }

    public static boolean isDeviceMuted(SampleAppActivity sampleAppActivity) {
        AudioManager audio = (AudioManager) (sampleAppActivity.getSystemService(Context.AUDIO_SERVICE));
        return audio.getStreamVolume(AudioManager.STREAM_MUSIC) == 0;
    }

    public static void setOCRLocalization(Context context) {
        // Set the strings to be used for group names, field names, and placeholder texts for the FaceTec ID Scan User OCR Confirmation Screen.
        // DEVELOPER NOTE: For this demo, we are using the template json file, 'FaceTec_OCR_Customization.json,' as the parameter in calling this API.
        // For the configureOCRLocalization API parameter, you may use any object that follows the same structure and key naming as the template json file, 'FaceTec_OCR_Customization.json'.
        try {
            InputStream is = context.getAssets().open("FaceTec_OCR_Customization.json");
            int size = is.available();
            byte[] buffer = new byte[size];
            is.read(buffer);
            is.close();
            String ocrLocalizationJSONString = new String(buffer, StandardCharsets.UTF_8);
            JSONObject ocrLocalizationJSON = new JSONObject(ocrLocalizationJSONString);

            FaceTecSDK.configureOCRLocalization(ocrLocalizationJSON);

        } catch (IOException | JSONException ex) {
            ex.printStackTrace();
        }
    }

    public static void configureInitialSampleAppUI(SampleAppActivity sampleAppActivity) {
        sampleAppActivity.getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_FULLSCREEN);

        sampleAppActivity.activityMainBinding = DataBindingUtil.setContentView(sampleAppActivity, R.layout.activity_main);

        if (Build.VERSION.SDK_INT >= 35) {
            // Since edge-to-edge layout is enforced in Android 15, update main activity content to layout between the system bar bounds
            ViewCompat.setOnApplyWindowInsetsListener(sampleAppActivity.activityMainBinding.contentLayout, (view, windowInsets) -> {
                Insets insets = windowInsets.getInsets(WindowInsetsCompat.Type.systemBars());
                ViewGroup.MarginLayoutParams marginLayoutParams = (ViewGroup.MarginLayoutParams) view.getLayoutParams();
                marginLayoutParams.topMargin = insets.top;
                marginLayoutParams.leftMargin = insets.left;
                marginLayoutParams.bottomMargin = insets.bottom;
                marginLayoutParams.rightMargin = insets.right;
                view.setLayoutParams(marginLayoutParams);

                return WindowInsetsCompat.CONSUMED;
            });
        }

        setupAllButtons(sampleAppActivity);

        // If the screen size is small, reduce FaceTec Logo
        if (sampleAppActivity.getResources().getConfiguration().screenHeightDp < 500) {
            sampleAppActivity.activityMainBinding.facetecLogo.setScaleX(0.6f);
            sampleAppActivity.activityMainBinding.facetecLogo.setScaleY(0.6f);
            ViewGroup.MarginLayoutParams params = (ViewGroup.MarginLayoutParams) sampleAppActivity.activityMainBinding.facetecLogo.getLayoutParams();
            params.setMargins(0, 0, 0, 0);
        }

        sampleAppActivity.runOnUiThread(() -> sampleAppActivity.activityMainBinding.vocalGuidanceSettingButton.setEnabled(false));
    }
}
