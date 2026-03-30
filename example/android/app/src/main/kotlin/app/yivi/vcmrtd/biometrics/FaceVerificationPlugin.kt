package foundation.privacybydesign.vcmrtd.biometrics

import android.graphics.Bitmap
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import foundation.privacybydesign.vcmrtd.ImageUtil
import java.io.ByteArrayOutputStream
import java.io.FileOutputStream

class FaceVerificationPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var engine: FaceVerificationEngine
    private val scope = CoroutineScope(Dispatchers.Main)

    companion object {
        private const val CHANNEL = "foundation.privacybydesign.vcmrtd/face_verification"
        private const val TAG = "FaceVerificationPlugin"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        engine = FaceVerificationEngine(binding.applicationContext)
        engine.initialize()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        engine.close()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "verifyFace" -> {
                val nfcImageBytes = call.argument<ByteArray>("nfcImage")
                val selfieBytes = call.argument<ByteArray>("selfieImage")

                if (nfcImageBytes == null || selfieBytes == null) {
                    result.error("INVALID_ARGS", "nfcImage and selfieImage are required", null)
                    return
                }

                scope.launch {
                    try {
                        val score = withContext(Dispatchers.IO) {
                            val nfcJpegBytes = prepareNfcImage(nfcImageBytes)
                            engine.verify(nfcJpegBytes, selfieBytes)
                        }
                        result.success(score)
                    } catch (e: IllegalStateException) {
                        result.error("NO_FACE", e.message, null)
                    } catch (e: Exception) {
                        android.util.Log.e(TAG, "Verification error: ${e.message}", e)
                        result.error("ERROR", e.message, null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Prepares NFC image for face detection.
     * Decodes JP2 (passport photo format) to jpg.
     * testing reason why we need this
     */
    private fun prepareNfcImage(imageBytes: ByteArray): ByteArray {

        if (!isJP2(imageBytes)) {
            return imageBytes
        }

        val bitmap = ImageUtil.decodeImage(null, "image/jp2", imageBytes.inputStream())

        val baos = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 100, baos)
        return baos.toByteArray()
    }

    /**
     * Checks if the image is in JP2 (JPEG2000) format.
     * JP2 files start with a specific 4-byte signature.
     */
    private fun isJP2(bytes: ByteArray): Boolean =
        bytes.size > 4 &&
                bytes[0] == 0x00.toByte() &&
                bytes[1] == 0x00.toByte() &&
                bytes[2] == 0x00.toByte() &&
                bytes[3] == 0x0C.toByte()
}