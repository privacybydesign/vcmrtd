package foundation.privacybydesign.vcmrtd

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {

    private lateinit var deepLinkPlugin: DeepLinkPlugin
    private lateinit var proofingDeepLinkPlugin: ProofingDeepLinkPlugin

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Initialize deep link plugin
        deepLinkPlugin = DeepLinkPlugin()
        flutterEngine.plugins.add(deepLinkPlugin)

        // Initialize identity-proofing-service deep link plugin
        proofingDeepLinkPlugin = ProofingDeepLinkPlugin()
        flutterEngine.plugins.add(proofingDeepLinkPlugin)

        // Register image_channel for JP2 decoding (used for passport photo)
        ImageDecodeChannel.register(flutterEngine, applicationContext)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (::deepLinkPlugin.isInitialized) {
            deepLinkPlugin.onNewIntent(intent)
        }
        if (::proofingDeepLinkPlugin.isInitialized) {
            proofingDeepLinkPlugin.onNewIntent(intent)
        }
    }
}
