package foundation.privacybydesign.idem

import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Forwards a tapped vcmrtd:// identity-proofing deep link to Dart. Kept
 * separate from DeepLinkPlugin, which only accepts an https URL carrying
 * sessionId/nonce for the unrelated passport-issuer.yivi.app flow and would
 * reject this shape outright (see identity-proofing-service's deepLink() in
 * backend/internal/api/sessions.go — "vcmrtd://verify?token=...&api=...").
 */
class ProofingDeepLinkPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    companion object {
        private const val CHANNEL = "proofing_deeplink"
    }

    private lateinit var channel: MethodChannel
    private var activity: FlutterActivity? = null
    private var initialLink: String? = null

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity as? FlutterActivity
        activity?.intent?.let { handleIntent(it) }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity as? FlutterActivity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getInitialLink" -> {
                result.success(initialLink)
                initialLink = null // only ever answered once per cold start
            }
            else -> result.notImplemented()
        }
    }

    /** The app was already running when the link was tapped. */
    fun onNewIntent(intent: Intent) {
        val url = extractUrl(intent) ?: return
        if (::channel.isInitialized) {
            channel.invokeMethod("onLink", url)
        } else {
            initialLink = url
        }
    }

    /** Cold start via a vcmrtd:// link. Reopening the app from recents
     *  replays the intent it was first launched with - an already used
     *  claim/handover link - so that one is ignored. */
    private fun handleIntent(intent: Intent) {
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        initialLink = extractUrl(intent)
    }

    private fun extractUrl(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        val uri = intent.data ?: return null
        if (uri.scheme != "vcmrtd") return null
        return uri.toString()
    }
}
