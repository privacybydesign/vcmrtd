package foundation.privacybydesign.vcmrtd.ocr

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class TesseractOcrPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var engine: TesseractOcrEngine
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        engine = TesseractOcrEngine(binding.applicationContext)
        channel = MethodChannel(binding.binaryMessenger, "tesseract_ocr")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        engine.close()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {

            "ocrNv21" -> {
                Thread {
                    try {
                        val bytes = call.argument<ByteArray>("bytes")
                        val width = call.argument<Int>("width")
                        val height = call.argument<Int>("height")
                        val rotation = call.argument<Int>("rotation") ?: 0 // camera rotation, front back
                        val lang = call.argument<String>("lang") ?: "ocrb"
                        val roiLeft = call.argument<Double>("roiLeft") ?: 0.0
                        val roiTop = call.argument<Double>("roiTop") ?: 0.0
                        val roiWidth = call.argument<Double>("roiWidth") ?: 1.0
                        val roiHeight = call.argument<Double>("roiHeight") ?: 1.0

                        if (bytes == null || width == null || height == null) {
                            main.post { result.error("ARG", "Missing bytes/width/height", null) }
                            return@Thread
                        }

                        val text = engine.ocrNv21(
                            bytes = bytes,
                            width = width,
                            height = height,
                            rotation = rotation,
                            lang = lang,
                            roiLeft = roiLeft,
                            roiTop = roiTop,
                            roiWidth = roiWidth,
                            roiHeight = roiHeight
                        )

                        main.post { result.success(text) }
                    } catch (e: Exception) {
                        main.post { result.error("OCR", e.message, null) }
                    }
                }.start()
            }
            else -> result.notImplemented()
        }
    }
}