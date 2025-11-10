package foundation.privacybydesign.vcmrtd

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel

import android.content.Context
import foundation.privacybydesign.vcmrtd.ImageUtil

class MainActivity : FlutterActivity() {
    private lateinit var deepLinkPlugin: DeepLinkPlugin

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Initialize deep link plugin
        deepLinkPlugin = DeepLinkPlugin()
        flutterEngine.plugins.add(deepLinkPlugin)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "image_channel")
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

        // Build flavor detection channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "build_config")
            .setMethodCallHandler { call, result ->
                if (call.method == "getFlavor") {
                    result.success(BuildConfig.FLAVOR)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (::deepLinkPlugin.isInitialized) {
            deepLinkPlugin.onNewIntent(intent)
        }
    }
}
