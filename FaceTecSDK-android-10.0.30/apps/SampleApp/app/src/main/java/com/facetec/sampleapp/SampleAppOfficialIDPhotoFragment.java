package com.facetec.sampleapp;

import android.Manifest;
import android.app.AlertDialog;
import android.app.Fragment;
import android.app.FragmentTransaction;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.view.ContextThemeWrapper;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;
import androidx.core.content.FileProvider;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.UUID;

import Utilities.SampleAppActionButton;
import Utilities.SampleAppUtilities;

public class SampleAppOfficialIDPhotoFragment extends Fragment {
    public static final String PREF_NAME= "sampleapp.prefs";
    public static final String USER_EMAIL_KEY = "sampleapp.email";

    final int ANIMATION_DURATION = 500;
    private static final int REQUEST_WRITE_PERMISSION = 1001;

    LinearLayout contentLayout;
    LinearLayout shareImageLayout;
    SampleAppActionButton continueButton;
    ImageView cancelButton;
    SampleAppActionButton downloadPhotoButton;
    SampleAppActionButton emailPhotoButton;
    EditText emailField;
    ImageView officialIDPhotoImageView;
    public static Bitmap latestOfficialIDPhoto;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_official_id_photo, container, false);

        contentLayout = view.findViewById(R.id.contentLayout);
        shareImageLayout = view.findViewById(R.id.shareImageLayout);
        cancelButton = view.findViewById(R.id.cancelButton);
        emailField = view.findViewById(R.id.emailField);
        continueButton = view.findViewById(R.id.continueButton);
        downloadPhotoButton = view.findViewById(R.id.downloadPhotoButton);
        emailPhotoButton = view.findViewById(R.id.emailPhotoButton);
        officialIDPhotoImageView = view.findViewById(R.id.officialIDPhotoImageView);

        SampleAppActivity sampleAppActivity = (SampleAppActivity) getActivity();

        continueButton.setupButton(sampleAppActivity);
        continueButton.setOnClickListener(this::onContinueButtonPressed);

        downloadPhotoButton.setupButton(sampleAppActivity);
        downloadPhotoButton.setOnClickListener(this::onDownloadPhotoButtonPressed);

        emailPhotoButton.setupButton(sampleAppActivity);
        emailPhotoButton.setOnClickListener(this::onEmailPhotoButtonPressed);

        cancelButton.setOnClickListener(this::onCancelButtonPressed);

        getSavedEmail(getActivity());

        fadeInInstructionScreen();

        return view;
    }

    void launchOfficialIDPhotoSession(SampleAppActivity sampleAppActivity) {
        SampleAppActivity.demonstrationExternalDatabaseRefID = "";
        sampleAppActivity.sdkInstance.startSecureOfficialIDPhotoCapture(sampleAppActivity, new SessionRequestProcessor());
    }

    static void exitSampleAppOfficialIDFragment(SampleAppActivity sampleAppActivity) {
        if (sampleAppActivity.sampleAppOfficialIDPhotoFragment != null) {
            sampleAppActivity.sampleAppOfficialIDPhotoFragment.fadeOutOfficialIDPhotoFragment(() -> {
                FragmentTransaction transaction = sampleAppActivity.getFragmentManager().beginTransaction();
                transaction.remove(sampleAppActivity.sampleAppOfficialIDPhotoFragment);
                transaction.commit();
                sampleAppActivity.sampleAppOfficialIDPhotoFragment = null;

                sampleAppActivity.activityMainBinding.officialIDFragmentLayout.setAlpha(0);
                SampleAppUtilities.fadeInMainUI(sampleAppActivity);
            });
        }
    }

    static void handleSampleAppOfficialIDPhotoResult(SampleAppActivity sampleAppActivity) {
        if (SampleAppOfficialIDPhotoFragment.latestOfficialIDPhoto != null) {
            sampleAppActivity.sampleAppOfficialIDPhotoFragment.fadeInResultScreen();
            sampleAppActivity.sampleAppOfficialIDPhotoFragment.setButtonsEnabled(true);
        }
        else {
            SampleAppOfficialIDPhotoFragment.exitSampleAppOfficialIDFragment(sampleAppActivity);
            SampleAppUtilities.displayStatus(sampleAppActivity, "An issue occurred creating your Official ID Photo.", false);
            SampleAppUtilities.fadeInMainUI(sampleAppActivity);
        }
    }

    // Launch Official ID Photo session
    public void onContinueButtonPressed(View v) {
        setButtonsEnabled(false);
        latestOfficialIDPhoto = null;

        fadeOutOfficialIDPhotoFragment(() -> {
            SampleAppActivity activity = (SampleAppActivity) getActivity();
            launchOfficialIDPhotoSession(activity);
        });
    }

    // If the permission was granted in older Android SDK versions, download the Official ID Photo image
    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);

        if (requestCode == REQUEST_WRITE_PERMISSION) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                downloadImageForOlderAndroidVersions();
            }
            else {
                Toast.makeText(getActivity(), "Download failed. Permission denied.", Toast.LENGTH_SHORT).show();
            }
        }
    }

    // Download the Official ID Photo image for Android SDK version 29 and up
    private void downloadImage() {
        String filename = generateFileName();
        OutputStream fos;

        try {
            ContentValues values = new ContentValues();
            values.put(MediaStore.Images.Media.DISPLAY_NAME, filename);
            values.put(MediaStore.Images.Media.MIME_TYPE, "image/png");
            values.put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES);

            Uri uri = getActivity().getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);

            if (uri != null) {
                fos = getActivity().getContentResolver().openOutputStream(uri);
                latestOfficialIDPhoto.compress(Bitmap.CompressFormat.PNG, 100, fos);
                fos.close();
                Toast.makeText(getActivity(), "Official ID Photo Downloaded Successfully", Toast.LENGTH_SHORT).show();
            }
        }
        catch (IOException e) {
            Toast.makeText(getActivity(), "Download failed: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    // Download the Official ID Photo image for older Android SDK versions
    private void downloadImageForOlderAndroidVersions() {
        String filename = generateFileName();
        OutputStream fos;

        try {
            File picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES);
            File imageFile = new File(picturesDir, filename);
            fos = new FileOutputStream(imageFile);
            latestOfficialIDPhoto.compress(Bitmap.CompressFormat.PNG, 100, fos);
            fos.close();

            Intent mediaScanIntent = new Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE);
            Uri contentUri = Uri.fromFile(imageFile);
            mediaScanIntent.setData(contentUri);
            getActivity().sendBroadcast(mediaScanIntent);

            Toast.makeText(getActivity(), "Official ID Photo Downloaded Successfully", Toast.LENGTH_SHORT).show();
        }
        catch (IOException e) {
            Toast.makeText(getActivity(), "Download failed: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    // Download the Official ID Photo image to the device's gallery
    public void onDownloadPhotoButtonPressed(View v) {
        if (latestOfficialIDPhoto == null) {
            return;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            downloadImage();
        }
        else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (ContextCompat.checkSelfPermission(getActivity(), android.Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(new String[]{ Manifest.permission.WRITE_EXTERNAL_STORAGE}, REQUEST_WRITE_PERMISSION);
                return;
            }

            downloadImageForOlderAndroidVersions();
        }
        else {
            downloadImageForOlderAndroidVersions();
        }
    }

    // Open the share menu to email or share the Official ID Photo
    public void onEmailPhotoButtonPressed(View v) {
        if (latestOfficialIDPhoto == null) {
            return;
        }

        String email = emailField.getText().toString();

        // Check if email is valid
        if (!android.util.Patterns.EMAIL_ADDRESS.matcher(email).matches()) {
            showAlertForInvalidEmail(getActivity());
            return;
        }

        saveEmail(getActivity());

        try {
            File cachePath = new File(getActivity().getCacheDir(), "official_id");
            cachePath.mkdirs();
            File imageFile = new File(cachePath, generateFileName());

            FileOutputStream stream = new FileOutputStream(imageFile);
            latestOfficialIDPhoto.compress(Bitmap.CompressFormat.PNG, 100, stream);

            Uri imageUri = FileProvider.getUriForFile(getActivity(), getActivity().getPackageName() + ".fileprovider", imageFile);

            Intent shareIntent = new Intent(Intent.ACTION_SEND);
            shareIntent.setType("image/png");
            shareIntent.putExtra(Intent.EXTRA_STREAM, imageUri);
            shareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            shareIntent.putExtra(Intent.EXTRA_EMAIL, new String[]{email});
            startActivity(Intent.createChooser(shareIntent, "Share Image"));
        }
        catch (IOException e) {
            e.printStackTrace();
        }
    }

    // Exit the Official ID Photo fragment
    public void onCancelButtonPressed(View v) {
        setButtonsEnabled(false);
        exitSampleAppOfficialIDFragment((SampleAppActivity) getActivity());
    }

    // Enable or disable all buttons in the view
    public void setButtonsEnabled(boolean enabled) {
        if (cancelButton != null) {
            cancelButton.setEnabled(enabled);
        }

        if (continueButton != null) {
            continueButton.setEnabled(enabled, true);
        }

        if (emailPhotoButton != null) {
            emailPhotoButton.setEnabled(enabled, true);
        }

        if (downloadPhotoButton != null) {
            downloadPhotoButton.setEnabled(enabled, true);
        }
    }

    // Fade out the Official ID Photo fragment
    void fadeOutOfficialIDPhotoFragment(final Runnable runnable) {
        getActivity().runOnUiThread(() -> {
            cancelButton.animate().alpha(0f).setDuration(ANIMATION_DURATION).setListener(null).start();
            shareImageLayout.animate().alpha(0f).setDuration(ANIMATION_DURATION).setListener(null).start();
            contentLayout.animate().alpha(0f).setDuration(ANIMATION_DURATION).setListener(null).withEndAction(() -> {
                if (runnable != null) {
                    runnable.run();
                }
            }).start();
        });
    }

    // Show a screen with instructions to perform the session in the best lighting conditions
    private void fadeInInstructionScreen() {
        getActivity().runOnUiThread(() -> {
            shareImageLayout.setAlpha(0);
            shareImageLayout.setVisibility(View.GONE);
            contentLayout.setAlpha(0);
            contentLayout.setVisibility(View.VISIBLE);
            cancelButton.setAlpha(0f);
            cancelButton.setVisibility(View.VISIBLE);

            cancelButton.animate().alpha(1f).setDuration(ANIMATION_DURATION).setListener(null).start();
            contentLayout.animate().alpha(1f).setDuration(ANIMATION_DURATION).setListener(null).start();
        });
    }

    // Show a screen with the Official ID Photo image and options to download or share the image
    void fadeInResultScreen() {
        getActivity().runOnUiThread(() -> {
            contentLayout.setAlpha(0);
            contentLayout.setVisibility(View.GONE);
            shareImageLayout.setAlpha(0);
            shareImageLayout.setVisibility(View.VISIBLE);
            cancelButton.setAlpha(0f);
            cancelButton.setVisibility(View.VISIBLE);

            cancelButton.animate().alpha(1f).setDuration(ANIMATION_DURATION).setListener(null).start();
            shareImageLayout.animate().alpha(1f).setDuration(ANIMATION_DURATION).setListener(null).start();

            if (latestOfficialIDPhoto != null ) {
                officialIDPhotoImageView.setImageBitmap(latestOfficialIDPhoto);
            }
        });
    }

    private void showAlertForInvalidEmail(Context context) {
        new AlertDialog.Builder(new ContextThemeWrapper(context, android.R.style.Theme_Holo_Light))
                .setMessage("Please enter a valid email address.")
                .setNeutralButton("OK", null)
                .show();
    }

    // Save the entered email to Shared Preferences
    private void saveEmail(Context context) {
        SharedPreferences.Editor editor = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE).edit();
        editor.putString(USER_EMAIL_KEY, emailField.getText().toString());
        editor.apply();
    }

    // Retrieve the email from Shared Preferences if it exists
    private void getSavedEmail(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
        emailField.setText(prefs.getString(USER_EMAIL_KEY, ""));
    }

    private String generateFileName() {
        String date = new SimpleDateFormat("yyyyMMdd", Locale.US).format(new Date());
        String shortUUID = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        return "FaceTec_Generated_Official_ID_Photo_" + date + "_" + shortUUID + ".png";
    }
}
