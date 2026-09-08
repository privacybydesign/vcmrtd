package foundation.privacybydesign.faceverificationiris

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import iris.Iris

/** Flutter plugin bridging [IrisFaceVerifier] (Dart) to the Iris SDK. */
class FaceVerificationIrisPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    ActivityResultListener {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "The Iris SDK requires an attached Activity", null)
            return
        }
        when (call.method) {
            "version" -> result.success(Iris(currentActivity).version())
            "verify" -> startVerification(currentActivity, call, result)
            else -> result.notImplemented()
        }
    }

    private fun startVerification(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("ALREADY_RUNNING", "A verification is already in progress", null)
            return
        }
        val portrait = call.arguments as? ByteArray
        if (portrait == null) {
            result.error("INVALID_ARGUMENT", "Expected the portrait PNG bytes as the call argument", null)
            return
        }
        pendingResult = result
        activity.startActivityForResult(IrisFaceVerificationActivity.buildIntent(activity, portrait), REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) {
            return false
        }
        val result = pendingResult ?: return true
        pendingResult = null
        val outcome = data?.getStringExtra(IrisFaceVerificationActivity.EXTRA_OUTCOME)
            ?: IrisFaceVerificationActivity.OUTCOME_FAILED
        val face = data?.getByteArrayExtra(IrisFaceVerificationActivity.EXTRA_FACE)
        result.success(mapOf("outcome" to outcome, "face" to face))
        return true
    }

    companion object {
        private const val CHANNEL_NAME = "face_verification_iris"
        private const val REQUEST_CODE = 0x1155
    }
}
