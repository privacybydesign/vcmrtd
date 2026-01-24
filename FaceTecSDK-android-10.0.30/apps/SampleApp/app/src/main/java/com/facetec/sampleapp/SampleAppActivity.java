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
package com.facetec.sampleapp;

import static java.util.UUID.randomUUID;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.FragmentTransaction;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.View;

import androidx.annotation.NonNull;

import com.facetec.sampleapp.databinding.ActivityMainBinding;
import com.facetec.sdk.FaceTecInitializationError;
import com.facetec.sdk.FaceTecSDK;
import com.facetec.sdk.FaceTecSDKInstance;
import com.facetec.sdk.FaceTecSessionResult;
import com.facetec.sdk.FaceTecSessionStatus;

import Utilities.SampleAppUtilities;
import Utilities.ThemeHelpers;

public class SampleAppActivity extends Activity {
    public ActivityMainBinding activityMainBinding;
    public FaceTecSDKInstance sdkInstance;
    SampleAppOfficialIDPhotoFragment sampleAppOfficialIDPhotoFragment;

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
    public static String demonstrationExternalDatabaseRefID = "";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Optional - Preload resources related to the FaceTec SDK so that it can run as soon as possible.
        // Run this as soon as you think you might use the SDK for optimal start up performance.
        FaceTecSDK.preload(this);

        SampleAppUtilities.configureInitialSampleAppUI(this);
        SampleAppUtilities.displayStatus(this, "Initializing...");

        // Required Parameters:
        // - context:  The current activity
        // - deviceKeyIdentifier:  The public Device Key Identifier associated with your Application
        // - sessionRequestProcessor:  A SessionRequestProcessor class.  Please see the implementation of SessionRequestProcessor in this Sample App
        // - callback:  An InitializeCallback.
        //      - The onSuccess callback is called with a FaceTecSDKInstance when successful.
        //      - The onError callback is called when your SessionRequestProcessor cannot make a connection to your Server, or an invalid Device Key Identifier was used.
        FaceTecSDK.initializeWithSessionRequest(this, Config.DeviceKeyIdentifier, new SessionRequestProcessor(), new FaceTecSDK.InitializeCallback() {
            @Override
            public void onSuccess(@NonNull FaceTecSDKInstance sdkInstance) {
                onFaceTecSDKInitializationSuccess(sdkInstance);
            }

            @Override
            public void onError(@NonNull FaceTecInitializationError error) {
                onFaceTecSDKInitializationFailure(error);
            }
        });
    }

    // Finish setup after initialization success
    private void onFaceTecSDKInitializationSuccess(FaceTecSDKInstance sdkInstance) {
        this.sdkInstance = sdkInstance;

        SampleAppUtilities.enableAllButtons(this);

        // Set your FaceTec Device SDK Customizations.
        ThemeHelpers.setAppTheme(this, SampleAppUtilities.currentTheme);

        // Set the strings to be used for group names, field names, and placeholder texts for the FaceTec ID Scan User OCR Confirmation Screen.
        SampleAppUtilities.setOCRLocalization(this);

        // Set the FaceTec Customization defined in the Config File.
        SampleAppUtilities.setVocalGuidanceSoundFiles();
        SampleAppUtilities.setUpVocalGuidancePlayers(this);
        SampleAppUtilities.displayStatus(this, "Initialized Successfully.");
    }

    // Displays the FaceTec SDK Status as a Text Prompt.
    private void onFaceTecSDKInitializationFailure(FaceTecInitializationError error) {
        SampleAppUtilities.displayStatus(this, error.toString());
    }

    // Initiate a 3D Liveness Check.
    public void onLivenessCheckPressed(View v) {
        SampleAppUtilities.fadeOutMainUIAndPrepareForFaceTecSDK(this, () -> {
            demonstrationExternalDatabaseRefID = "";
            sdkInstance.start3DLiveness(this, new SessionRequestProcessor());
        });
    }

    // Initiate a 3D Liveness Check, then storing the 3D FaceMap in the Database, also known as "Enrollment". A random externalDatabaseRefID is generated each time to guarantee uniqueness.
    public void onEnrollUserPressed(View v) {
        SampleAppUtilities.fadeOutMainUIAndPrepareForFaceTecSDK(this, () -> {
            demonstrationExternalDatabaseRefID = "android_sample_app_" + randomUUID();
            sdkInstance.start3DLiveness(this, new SessionRequestProcessor());
        });
    }

    // Initiate a 3D to 3D Verification against the Enrollment previously performed.
    public void onVerifyUserPressed(View v) {
        if (demonstrationExternalDatabaseRefID.isEmpty()) {
            SampleAppUtilities.displayStatus(this, "Please enroll first before trying verification.");
            return;
        }

        SampleAppUtilities.fadeOutMainUIAndPrepareForFaceTecSDK(this, () ->  {
            sdkInstance.start3DLivenessThen3DFaceMatch(this, new SessionRequestProcessor());
        });
    }

    // Initiate a 3D Liveness Check, then an ID Scan, then Match the 3D FaceMap to the ID Scan.
    public void onPhotoIDMatchPressed(View view) {
        SampleAppUtilities.fadeOutMainUIAndPrepareForFaceTecSDK(this, () -> {
            demonstrationExternalDatabaseRefID = "android_sample_app_" + randomUUID();
            sdkInstance.start3DLivenessThen3D2DPhotoIDMatch(this, new SessionRequestProcessor());
        });
    }

    // Initiate a Photo ID Scan.
    public void onPhotoIDScanOnlyPressed(View view) {
        SampleAppUtilities.fadeOutMainUIAndPrepareForFaceTecSDK(this, () -> {
            sdkInstance.startIDScanOnly(this, new SessionRequestProcessor());
        });
    }

    // Initiate a 3D Liveness Check and generate a 2D Image that can be used for Official ID Photo Documentation.
    public void onOfficialIDPhotoPressed(View view) {
        runOnUiThread(() -> new AlertDialog.Builder(this)
            .setMessage("This is a Paid Extra-Feature, please contact FaceTec before use.")
            .setPositiveButton("OK", (dialog, which) -> dialog.dismiss())
            .show());

        // Uncomment this code to use Official ID Photo
//        sampleAppOfficialIDPhotoFragment = new SampleAppOfficialIDPhotoFragment();
//        FragmentTransaction transaction = getFragmentManager().beginTransaction();
//        transaction.replace(R.id.officialIDFragmentLayout, sampleAppOfficialIDPhotoFragment);
//        transaction.addToBackStack(null);
//        transaction.commit();
//
//        SampleAppUtilities.fadeOutMainUIAndPrepareForFaceTecSDK(this, () -> {
//            activityMainBinding.officialIDFragmentLayout.setAlpha(1);
//        });
    }

    // Set the Vocal Guidance Customizations for FaceTec.
    public void onVocalGuidanceSettingsButtonPressed(View v) {
        SampleAppUtilities.setVocalGuidanceMode(this);
    }

    // When the FaceTec SDK is completely done, you receive control back here.
    // Since you have already handled all results in your Processor code, how you proceed here is up to you and how your App works.
    // In general, there was either a Success, or there was some other case where you cancelled out.
    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);

        FaceTecSessionResult sessionResult = FaceTecSDK.getActivitySessionResult(requestCode, resultCode, data);
        if (sessionResult != null) {
            if (sessionResult.getStatus() != null) {
                Log.d("FaceTecSDKSampleApp", "Session Status: " + sessionResult.getStatus());
            }

            boolean successful = sessionResult.getStatus() == FaceTecSessionStatus.SESSION_COMPLETED;
            // Reset the demonstrationExternalDatabaseRefID
            if (!successful) {
                demonstrationExternalDatabaseRefID = "";
            }

            if (successful && sampleAppOfficialIDPhotoFragment != null) {
                SampleAppOfficialIDPhotoFragment.handleSampleAppOfficialIDPhotoResult(this);
                return;
            }
        }
        else {
            Log.d("FaceTecSDKSampleApp", "FaceTecSessionResult unexpectedly null");
            demonstrationExternalDatabaseRefID = "";
        }

        SampleAppOfficialIDPhotoFragment.exitSampleAppOfficialIDFragment(this);
        SampleAppUtilities.displayStatus(this, "See logs for more details.", false);
        SampleAppUtilities.fadeInMainUI(this);
    }

    // Present settings action sheet, allowing user to select a new app theme (pre-made FaceTecCustomization configuration).
    public void onThemeSelectionPressed(View view) {
        SampleAppUtilities.showThemeSelectionMenu(this);
    }

    @Override
    public void onBackPressed() {
        if (sampleAppOfficialIDPhotoFragment != null) {
            SampleAppOfficialIDPhotoFragment.exitSampleAppOfficialIDFragment(this);
        }
        else {
            super.onBackPressed();
        }
    }
}
