package foundation.privacybydesign.vcmrtd

import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugins.GeneratedPluginRegistrant

// FaceTec SDK imports
import com.facetec.sdk.*

class MainActivity : FlutterActivity(), FaceTecSessionRequestProcessor {
    private lateinit var deepLinkPlugin: DeepLinkPlugin

    // FaceTec properties
    private var faceTecSDKInstance: FaceTecSDKInstance? = null
    private var latestExternalDatabaseRefID: String = ""
    private var processorChannel: MethodChannel? = null
    private var initializeResultCallback: MethodChannel.Result? = null
    private var requestCallback: FaceTecSessionRequestProcessor.Callback? = null

    companion object {
        private const val FACETEC_CHANNEL = "com.facetec.sdk"
        private const val FACETEC_PROCESSOR_CHANNEL = "com.facetec.sdk/livenesscheck"
        private const val IMAGE_CHANNEL = "image_channel"
        private const val TAG = "FaceTecVCMRTD"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Initialize deep link plugin
        deepLinkPlugin = DeepLinkPlugin()
        flutterEngine.plugins.add(deepLinkPlugin)

        // Setup Image channel (existing functionality)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IMAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "decodeImage") {
                    val jp2ImageData = call.argument<ByteArray?>("jp2ImageData")
                    if (jp2ImageData != null) {
                        ImageUtil.decodeImage(applicationContext, jp2ImageData, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "jp2ImageData is null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // Setup FaceTec channels
        val faceTecSDKChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FACETEC_CHANNEL)
        processorChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FACETEC_PROCESSOR_CHANNEL)

        faceTecSDKChannel.setMethodCallHandler { call, result ->
            receivedFaceTecSDKMethodCall(call, result)
        }

        processorChannel?.setMethodCallHandler { call, result ->
            receivedLivenessCheckProcessorCall(call, result)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (::deepLinkPlugin.isInitialized) {
            deepLinkPlugin.onNewIntent(intent)
        }
    }

    // ============ FaceTec SDK Methods ============

    private fun receivedFaceTecSDKMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val deviceKeyIdentifier = call.argument<String>("deviceKeyIdentifier")
                val faceScanEncryptionKey = call.argument<String>("publicFaceScanEncryptionKey")

                if (deviceKeyIdentifier != null && faceScanEncryptionKey != null) {
                    initializeFaceTecSDK(deviceKeyIdentifier, faceScanEncryptionKey, result)
                } else {
                    result.error("InvalidArguments", "Missing deviceKeyIdentifier or publicFaceScanEncryptionKey", null)
                }
            }
            "startLivenessCheck" -> {
                startLivenessCheck(result)
            }
            "createAPIUserAgentString" -> {
                val data = FaceTecSDK.getTestingAPIHeader()
                result.success(data)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun receivedLivenessCheckProcessorCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "abortOnCatastrophicError" -> {
                onCatastrophicNetworkError()
            }
            "onResponseBlobReceived" -> {
                val responseBlob = call.argument<String>("responseBlob")
                if (responseBlob != null) {
                    onResponseBlobReceived(responseBlob)
                } else {
                    result.error("InvalidArguments", "Missing arguments for onResponseBlobReceived", null)
                }
            }
            "onUploadProgress" -> {
                val progress = call.argument<Float>("progress")
                if (progress != null) {
                    onUploadProgress(progress)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun initializeFaceTecSDK(
        deviceKeyIdentifier: String,
        publicFaceScanEncryptionKey: String,
        result: MethodChannel.Result
    ) {
        initializeResultCallback = result

        // Customize FaceTec UI
        val ftCustomization = FaceTecCustomization()
        FaceTecSDK.setCustomization(ftCustomization)

        // Initialize FaceTec SDK
        val callback = object : FaceTecSDK.InitializeCallback {
            override fun onSuccess(sdkInstance: FaceTecSDKInstance) {
                onFaceTecSDKInitializationSuccess(sdkInstance)
                initializeResultCallback?.success(true)
                initializeResultCallback = null
            }

            override fun onError(error: FaceTecInitializationError) {
                onFaceTecSDKInitializationFailure(error)
                initializeResultCallback?.error("InitializeFailure", "Unable to initialize FaceTec SDK: ${error.name}", null)
                initializeResultCallback = null
            }
        }

        FaceTecSDK.initializeWithSessionRequest(this, deviceKeyIdentifier, this, callback)
    }

    private fun onFaceTecSDKInitializationSuccess(sdkInstance: FaceTecSDKInstance) {
        faceTecSDKInstance = sdkInstance
        Log.d(TAG, "FaceTec SDK Initialized Successfully")
    }

    private fun onFaceTecSDKInitializationFailure(error: FaceTecInitializationError) {
        Log.e(TAG, "FaceTec SDK Initialization Failed: ${error.name}")
    }

    private fun startLivenessCheck(result: MethodChannel.Result) {
        latestExternalDatabaseRefID = ""
        faceTecSDKInstance?.start3DLiveness(this, this)
        result.success(true)
    }

    // FaceTecSessionRequestProcessor implementation
    override fun onSessionRequest(sessionRequestBlob: String, sessionRequestCallback: FaceTecSessionRequestProcessor.Callback) {
        requestCallback = sessionRequestCallback

        val args = mapOf(
            "sessionRequestBlob" to sessionRequestBlob,
            "externalDatabaseRefID" to latestExternalDatabaseRefID,
            "userAgentString" to FaceTecSDK.getTestingAPIHeader()
        )

        runOnUiThread {
            processorChannel?.invokeMethod("processSession", args)
        }
    }

    private fun onResponseBlobReceived(responseBlob: String) {
        requestCallback?.processResponse(responseBlob)
    }

    private fun onUploadProgress(progress: Float) {
        requestCallback?.updateProgress(progress)
    }

    private fun onCatastrophicNetworkError() {
        requestCallback?.abortOnCatastrophicError()
    }
}
