package foundation.privacybydesign.mrzcapture

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class TesseractOcrPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var engine: TesseractOcrEngine
    private val main = Handler(Looper.getMainLooper())
    private var ocrExecutor: ExecutorService? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        engine = TesseractOcrEngine(binding.applicationContext)
        ocrExecutor = Executors.newSingleThreadExecutor()
        channel = MethodChannel(binding.binaryMessenger, "tesseract_ocr")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        ocrExecutor?.shutdownNow()
        ocrExecutor = null
        engine.close()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "processImage") {
            result.notImplemented()
            return
        }

        val pixels = call.argument<ByteArray>("pixels")
        val width = call.argument<Int>("width")
        val height = call.argument<Int>("height")
        val lang = call.argument<String>("lang") ?: "ocrb"

        if (pixels == null || width == null || height == null) {
            result.error("ARG", "Missing required arguments", null)
            return
        }

        val executor = ocrExecutor
        if (executor == null || executor.isShutdown) {
            result.error("OCR", "OCR engine not available", null)
            return
        }

        executor.execute {
            try {
                val text = engine.ocr(pixels, width, height, lang)
                main.post { result.success(text) }
            } catch (e: Exception) {
                main.post { result.error("OCR", e.message, null) }
            }
        }
    }
}