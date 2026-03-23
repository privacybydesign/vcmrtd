package com.example.flutter_facetec_sample_app;

import androidx.annotation.NonNull;
import android.content.Context;

import android.util.Log;
import com.facetec.sdk.FaceTecCustomization;
import com.facetec.sdk.FaceTecInitializationError;
import com.facetec.sdk.FaceTecSDK;
import com.facetec.sdk.FaceTecSDKInstance;
import com.facetec.sdk.FaceTecSessionRequestProcessor;

import java.util.HashMap;
import java.util.Map;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity implements FaceTecSessionRequestProcessor {
    // MainActivity acts as a makeshift processor for the FaceTec session, since the actual
    // processing code in Dart cannot directly be called. It implements the required methods of a
    // processor delegate, processSessionWhileFaceTecSDKWaits() and onFaceTecSDKCompletelyDone().

    private static final String CHANNEL = "com.facetec.sdk";
    private static final String PROCESSOR_CHANNEL = "com.facetec.sdk/livenesscheck";
    private FaceTecSDKInstance faceTecSDKInstance = null;
    private String latestExternalDatabaseRefID = "";
    private MethodChannel processorChannel;
    private static MethodChannel.Result initializeResultCallback;
    private FaceTecSessionRequestProcessor.Callback requestCallback;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // configureFlutterEngine() creates processor channels for commmunicating with main.dart and LivenessCheckProcessor.dart.
        // Other processors you may create will be instantiated through another method channel.
        MethodChannel SDKChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        processorChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), PROCESSOR_CHANNEL);

        SDKChannel.setMethodCallHandler(this::receivedFaceTecSDKMethodCall);
        processorChannel.setMethodCallHandler(this::receivedLivenessCheckProcessorCall);
    }

    private void receivedFaceTecSDKMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        // Used to handle calls received over the "com.facetec.sdk" channel.
        // Currently two methods are implemented: initialize and startLivenessCheck.
        // When you make a call in main.dart or another file linked to the "com.facetec.sdk"
        // method channel, it will be received here and you will need to add logic for handling
        // that request.
        switch (call.method) {
            case "initialize":
                if (call.hasArgument("deviceKeyIdentifier") && call.hasArgument("publicFaceScanEncryptionKey")) {
                    String deviceKeyIdentifier = call.argument("deviceKeyIdentifier");
                    String faceScanEncryptionKey = call.argument("publicFaceScanEncryptionKey");
                    initialize(deviceKeyIdentifier, faceScanEncryptionKey, result);
                }
                else {
                    result.error("InvalidArguments", "Missing deviceKeyIdentifier or publicFaceScanEncryptionKey", null);
                }
                break;
            case "startLivenessCheck":
                startLivenessCheck(result);
                break;
            case "createAPIUserAgentString":
                String data = FaceTecSDK.getTestingAPIHeader();
                result.success(data);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void receivedLivenessCheckProcessorCall(MethodCall call, MethodChannel.Result result) {
        // Used to handle calls received over "com.facetec.sdk/livenesscheck".
        // Currently there is only one method needed, but your processor code may require
        // more communication between dart and native code. If so, you may want to implement
        // any processor code and then receive the results and handle updating logic or run code on completion here.
        switch (call.method) {
            case "abortOnCatastrophicError":
                onCatastrophicNetworkError();
                break;
            case "onResponseBlobReceived":
                if (call.hasArgument("responseBlob")) {
                    String responseBlob = call.argument("responseBlob");
                    onResponseBlobReceived(responseBlob);
                }
                else {
                    result.error("InvalidArguments", "Missing arguments for onResponseBlobReceived", null);
                }
                break;
            case "onUploadProgress":
                if (call.hasArgument("progress")) {
                    Float progress = call.argument("progress");
                    onUploadProgress(progress);
                }
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void initialize(String deviceKeyIdentifier, String publicFaceScanEncryptionKey, MethodChannel.Result result) {
        final Context context = this;
        initializeResultCallback = result;

        FaceTecCustomization ftCustomization = new FaceTecCustomization();
        ftCustomization.getOverlayCustomization().brandingImage = R.drawable.flutter_logo;
        FaceTecSDK.setCustomization(ftCustomization);

        FaceTecSDK.InitializeCallback initializeFaceTecSDKCallback = new FaceTecSDK.InitializeCallback() {
            @Override
            public void onSuccess(FaceTecSDKInstance sdkInstance) {
                onFaceTecSDKInitializationSuccess(sdkInstance);
                MainActivity.initializeResultCallback.success(true);
                MainActivity.initializeResultCallback = null;
            }

            @Override
            public void onError(FaceTecInitializationError error) {
                onFaceTecSDKInitializationFailure(error);
                MainActivity.initializeResultCallback.error("Initialize Failure", "Unable to initialize FaceTec SDK", null);
                MainActivity.initializeResultCallback = null;
            }
        };

        FaceTecSDK.initializeWithSessionRequest(this, deviceKeyIdentifier, this, initializeFaceTecSDKCallback);
    }

    private void onFaceTecSDKInitializationSuccess(FaceTecSDKInstance sdkInstance) {
        this.faceTecSDKInstance = sdkInstance;
        Log.d("FaceTecSDKSampleApp", "Initialized Successfully.");
    }

    private void onFaceTecSDKInitializationFailure(FaceTecInitializationError error) {
        // Displays the FaceTec SDK Status to text field if init failed.
        String errorMessage = error.toString();
        Log.d("FaceTecSDKSampleApp", errorMessage);
    }

    private void startLivenessCheck(MethodChannel.Result result) {
        // startLivenessCheck() will open the FaceTec interface and start the liveness check process. The
        // method processSessionWhileFaceTecSDKWaits() and onFaceTecSDKCompletelyDone() are not explicitly called,
        // but are implicitly called through the FaceTec controller. If you want to implement multiple processors,
        // you would need to keep track of which method was called to instantiate the session (in this case, startLivenessCheck)
        // and having branching logic in the implicitly called methods to handle multiple processors.
        this.latestExternalDatabaseRefID = "";
        this.faceTecSDKInstance.start3DLiveness(this, this);
        result.success(true);
    }

    // FaceTecSessionRequestProcessor required method
    // This method gets called from inside the FaceTecSDK when some server side process is needed to continue processing
    @Override
    public void onSessionRequest(@NonNull String sessionRequestBlob, @NonNull Callback sessionRequestCallback) {
        // Save the FaceTec SDK request callback so it can be accessed in the 3 helper methods
        this.requestCallback = sessionRequestCallback;

        // Ready arguments to be sent from native Android code to Dart files accessed by Flutter.
        Map<String, Object> args = new HashMap<>();
        args.put("sessionRequestBlob", sessionRequestBlob);
        args.put("externalDatabaseRefID", this.latestExternalDatabaseRefID);
        args.put("userAgentString", FaceTecSDK.getTestingAPIHeader());

        // Send arguments across the com.facetec.sdk/livenesscheck method channel, to the Liveness Check Processor code.
        // New processors you add would invoke a different method or communicate across a different channel. Therefore
        // any processor decisions you make should be tracked and branching logic should occur here.
        runOnUiThread(() -> {
            if (processorChannel != null) {
                processorChannel.invokeMethod("processSession", args);
            }
        });
    }

    // FaceTecSessionRequestProcessor required method
    // When the request blob has been received, send it back to the FaceTecSDK for continued processing
    public void onResponseBlobReceived(String responseBlob) {
        requestCallback.processResponse(responseBlob);
    }

    // FaceTecSessionRequestProcessor required method
    // Send the upload progress event to the FaceTec SDK
    public void onUploadProgress(float progress) {
        requestCallback.updateProgress(progress);
    }

    // FaceTecSessionRequestProcessor required method
    // When an unrecoverable network event occurs call the FaceTec SDK abortOnCatastrophicError
    // This should never be called except when a hard server error occurs. For example the user loses network connectivity.
    public void onCatastrophicNetworkError() {
        requestCallback.abortOnCatastrophicError();
    }
}