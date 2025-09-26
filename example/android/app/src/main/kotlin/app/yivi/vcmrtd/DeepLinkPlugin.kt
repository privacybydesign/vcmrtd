package foundation.privacybydesign.vcmrtd

import android.content.Intent
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.embedding.android.FlutterActivity

class DeepLinkPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    companion object {
        private const val CHANNEL = "deep_link_handler"
        private const val METHOD_GET_INITIAL_LINK = "getInitialLink"
        private const val METHOD_HANDLE_DEEP_LINK = "handleDeepLink"
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
            METHOD_GET_INITIAL_LINK -> {
                result.success(initialLink)
                initialLink = null
            }
            METHOD_HANDLE_DEEP_LINK -> {
                val url = call.arguments as? String
                if (url != null) {
                    val handled = processDeepLink(url)
                    result.success(mapOf("success" to handled))
                } else {
                    result.error("INVALID_ARGUMENTS", "URL is required", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    fun onNewIntent(intent: Intent) {
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (intent.action == Intent.ACTION_VIEW) {
            val uri = intent.data ?: return
            val url = uri.toString()

            if (isValidPassportIssuerUrl(uri)) {
                if (::channel.isInitialized) {
                    channel.invokeMethod(METHOD_HANDLE_DEEP_LINK, url)
                } else {
                    initialLink = url
                }
            }
        }
    }

    private fun isValidPassportIssuerUrl(uri: Uri): Boolean {
        if (uri.scheme != "https") return false
        if (uri.host != "passport-issuer.staging.yivi.app") return false
        if (!uri.path.orEmpty().startsWith("/start-app")) return false

        val sessionId = uri.getQueryParameter("sessionId")
        val nonce = uri.getQueryParameter("nonce")

        return !sessionId.isNullOrEmpty() && !nonce.isNullOrEmpty()
    }

    private fun processDeepLink(url: String): Boolean {
        return try {
            val uri = Uri.parse(url)
            if (!isValidPassportIssuerUrl(uri)) {
                false
            } else {
                android.util.Log.i("DeepLinkPlugin", "Processing valid deep link: $url")
                true
            }
        } catch (e: Exception) {
            android.util.Log.e("DeepLinkPlugin", "Error processing deep link: ${e.message}")
            false
        }
    }
}
