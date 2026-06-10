package foundation.privacybydesign.vcmrtd.ocr

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

        val bytes = call.argument<ByteArray>("bytes")
        val width = call.argument<Int>("width")
        val height = call.argument<Int>("height")
        val stride = call.argument<Int>("stride")
        val rotation = call.argument<Int>("rotation") ?: 0
        val lang = call.argument<String>("lang") ?: "ocrb"
        val roiLeft = call.argument<Double>("roiLeft") ?: 0.0
        val roiTop = call.argument<Double>("roiTop") ?: 0.0
        val roiWidth = call.argument<Double>("roiWidth") ?: 1.0
        val roiHeight = call.argument<Double>("roiHeight") ?: 1.0

        if (bytes == null || width == null || height == null || stride == null) {
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
                val text = engine.ocrYPlane(
                    bytes = bytes,
                    width = width,
                    height = height,
                    stride = stride,
                    rotation = rotation,
                    lang = lang,
                    roi = RoiParams(roiLeft, roiTop, roiWidth, roiHeight),
                )
                main.post { result.success(text) }
            } catch (e: Exception) {
                main.post { result.error("OCR", e.message, null) }
            }
        }
    }
}