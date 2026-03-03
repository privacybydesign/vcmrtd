package foundation.privacybydesign.vcmrtd

import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import org.opencv.android.OpenCVLoader
import foundation.privacybydesign.vcmrtd.ocr.TesseractOcrPlugin

class MainActivity : FlutterActivity() {

    private lateinit var deepLinkPlugin: DeepLinkPlugin

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // OpenCV initialisatie for Tesseract Zone Detection
        if (!OpenCVLoader.initLocal()) {
            Log.e("OpenCV", "OpenCV initialization failed")
        }

        // Initialize deep link plugin
        deepLinkPlugin = DeepLinkPlugin()
        flutterEngine.plugins.add(deepLinkPlugin)

        // Register Tesseract OCR plugin
        flutterEngine.plugins.add(TesseractOcrPlugin())

        // Register image_channel for JP2 decoding (used for passport photo)
        ImageDecodeChannel.register(flutterEngine, applicationContext)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (::deepLinkPlugin.isInitialized) {
            deepLinkPlugin.onNewIntent(intent)
        }
    }
}
