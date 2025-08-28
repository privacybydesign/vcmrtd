package app.yivi.vcmrtd

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

/**
 * DeepLinkPlugin handles deep link processing for MRTD validation
 * Integrates with Flutter's MethodChannel for cross-platform communication
 */
class DeepLinkPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    companion object {
        private const val CHANNEL = "deep_link_handler"
        private const val METHOD_GET_INITIAL_LINK = "getInitialLink"
        private const val METHOD_HANDLE_DEEP_LINK = "handleDeepLink"
    }

    private lateinit var channel: MethodChannel
    private var activity: FlutterActivity? = null
    private var initialLink: String? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity as? FlutterActivity
        
        // Check if app was launched via deep link
        activity?.intent?.let { intent ->
            handleIntent(intent)
        }
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
                initialLink = null // Clear after first access
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
            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Handle new intent (when app is already running)
     */
    fun onNewIntent(intent: Intent) {
        handleIntent(intent)
    }

    /**
     * Process incoming intent for deep links
     */
    private fun handleIntent(intent: Intent) {
        if (intent.action == Intent.ACTION_VIEW) {
            val uri = intent.data
            if (uri != null) {
                val url = uri.toString()
                
                if (isValidMrtdUrl(uri)) {
                    // If Flutter is ready, send immediately
                    if (::channel.isInitialized) {
                        channel.invokeMethod(METHOD_HANDLE_DEEP_LINK, url)
                    } else {
                        // Store for later retrieval
                        initialLink = url
                    }
                }
            }
        }
    }

    /**
     * Validate MRTD URL format and security
     */
    private fun isValidMrtdUrl(uri: Uri): Boolean {
        // Check scheme
        if (uri.scheme != "mrtd" && uri.scheme != "https") {
            return false
        }

        // For MRTD scheme, check host
        if (uri.scheme == "mrtd" && uri.host != "validate") {
            return false
        }

        // For HTTPS scheme, check domain and path
        if (uri.scheme == "https") {
            if (uri.host != "mrtd.app" || !uri.path.orEmpty().startsWith("/validate")) {
                return false
            }
        }

        // Check required parameters
        val requiredParams = listOf("sessionId", "nonce", "timestamp", "signature")
        for (param in requiredParams) {
            if (uri.getQueryParameter(param).isNullOrEmpty()) {
                return false
            }
        }

        // Validate sessionId format (basic UUID check)
        val sessionId = uri.getQueryParameter("sessionId")
        if (sessionId?.matches(Regex("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")) != true) {
            return false
        }

        // Validate timestamp format
        val timestamp = uri.getQueryParameter("timestamp")
        if (timestamp?.toLongOrNull() == null) {
            return false
        }

        // Basic nonce validation (should be Base64)
        val nonce = uri.getQueryParameter("nonce")
        if (nonce?.matches(Regex("[A-Za-z0-9+/]+=*")) != true) {
            return false
        }

        return true
    }

    /**
     * Process validated deep link
     */
    private fun processDeepLink(url: String): Boolean {
        return try {
            val uri = Uri.parse(url)
            
            if (!isValidMrtdUrl(uri)) {
                false
            } else {
                // Log security event
                android.util.Log.i("DeepLinkPlugin", "Processing valid MRTD deep link: ${uri.host}")
                
                // Additional security checks could be performed here
                // such as rate limiting, IP validation, etc.
                
                true
            }
        } catch (e: Exception) {
            android.util.Log.e("DeepLinkPlugin", "Error processing deep link: ${e.message}")
            false
        }
    }
}