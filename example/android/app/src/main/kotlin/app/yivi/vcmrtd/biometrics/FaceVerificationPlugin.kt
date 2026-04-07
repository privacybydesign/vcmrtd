package foundation.privacybydesign.vcmrtd.biometrics

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.Channel
import foundation.privacybydesign.vcmrtd.ImageUtil
import java.io.ByteArrayOutputStream
import java.io.File

class FaceVerificationPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var engine: FaceVerificationEngine
    private lateinit var livenessService: LivenessService
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    companion object {
        private const val CHANNEL = "foundation.privacybydesign.vcmrtd/face_verification"
        private const val TAG     = "FaceVerificationPlugin"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        engine = FaceVerificationEngine(binding.applicationContext)
        engine.initialize()
        livenessService = LivenessService(binding.applicationContext)
        livenessService.initialize()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        scope.cancel()
        channel.setMethodCallHandler(null)
        engine.close()
        livenessService.close()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "verifyFace"             -> handleVerifyFace(call, result)
            "verifyFaceAndLiveness"  -> handleVerifyFaceAndLiveness(call, result)
            else                     -> result.notImplemented()
        }
    }

    private fun handleVerifyFace(call: MethodCall, result: MethodChannel.Result) {
        val nfcImageBytes = call.argument<ByteArray>("nfcImage")
        val selfieBytes   = call.argument<ByteArray>("selfieImage")
        if (nfcImageBytes == null || selfieBytes == null) {
            result.error("INVALID_ARGS", "nfcImage and selfieImage are required", null)
            return
        }
        scope.launch {
            try {
                val score = withContext(Dispatchers.IO) {
                    engine.verify(prepareNfcImage(nfcImageBytes), selfieBytes)
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

    private fun handleVerifyFaceAndLiveness(call: MethodCall, result: MethodChannel.Result) {
        val nfcImageBytes = call.argument<ByteArray>("nfcImage")
        val videoBytes    = call.argument<ByteArray>("videoBytes")
        if (nfcImageBytes == null || videoBytes == null) {
            result.error("INVALID_ARGS", "nfcImage and videoBytes are required", null)
            return
        }
        scope.launch {
            try {
                val verificationResult = withContext(Dispatchers.IO) {
                    val nfcJpegBytes = prepareNfcImage(nfcImageBytes)
                    val tempFile     = File.createTempFile("video", ".mp4")
                    try {
                        tempFile.writeBytes(videoBytes)
                        val frameChannel = Channel<Bitmap>(capacity = 30)

                        // fps and first frame are delivered together via a single
                        // CompletableDeferred to avoid the race condition where
                        // livenessService consumes fps before the producer sets it.
                        val firstFrameDeferred = CompletableDeferred<Pair<Int, ByteArray>>()

                        val producerJob = launch {
                            extractFramesStreaming(tempFile, frameChannel) { fps, firstFrame ->
                                firstFrameDeferred.complete(fps to bitmapToJpeg(firstFrame))
                            }
                        }

                        val matchDeferred = async {
                            val (_, jpeg) = firstFrameDeferred.await()
                            engine.verify(nfcJpegBytes, jpeg)
                        }

                        val livenessDeferred = async {
                            val (fps, _) = firstFrameDeferred.await()
                            livenessService.isLiveStreaming(frameChannel, fps)
                        }

                        producerJob.join()
                        val matchScore = matchDeferred.await()
                        val isLive     = livenessDeferred.await()

                        android.util.Log.d(TAG, "Match score: $matchScore, isLive: $isLive")
                        mapOf("matchScore" to matchScore, "isLive" to isLive)
                    } finally {
                        tempFile.delete()
                    }
                }
                result.success(verificationResult)
            } catch (e: IllegalStateException) {
                result.error("NO_FACE", e.message, null)
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Verification error: ${e.message}", e)
                result.error("ERROR", e.message, null)
            }
        }
    }

    private suspend fun extractFramesStreaming(
        tempFile: File,
        frameChannel: Channel<Bitmap>,
        onFirstFrame: (fps: Int, frame: Bitmap) -> Unit
    ) {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(tempFile.absolutePath)
            val durationMs = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION
            )?.toLongOrNull() ?: 0L
            val fps = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_CAPTURE_FRAMERATE
            )?.toFloatOrNull()?.toInt()?.takeIf { it > 0 } ?: 30
            val frameIntervalMs = 1000L / fps

            android.util.Log.d(TAG, "Video duration: ${durationMs}ms, fps: $fps")

            var frameCount = 0
            var timeMs     = 0L
            while (timeMs < durationMs) {
                val frame = retriever.getFrameAtTime(
                    timeMs * 1000,
                    MediaMetadataRetriever.OPTION_CLOSEST
                ) ?: run { timeMs += frameIntervalMs; continue }

                if (frameCount == 0) onFirstFrame(fps, frame)
                frameChannel.send(frame)
                frameCount++
                timeMs += frameIntervalMs
            }
            android.util.Log.d(TAG, "Extracted $frameCount frames")
        } finally {
            retriever.release()
            frameChannel.close()
        }
    }

    private fun bitmapToJpeg(bitmap: Bitmap, quality: Int = 95): ByteArray {
        val baos = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, quality, baos)
        return baos.toByteArray()
    }

    private fun prepareNfcImage(imageBytes: ByteArray): ByteArray {
        if (!isJP2(imageBytes)) return imageBytes
        android.util.Log.d(TAG, "JP2 detected, decoding via ImageUtil")
        val bitmap = ImageUtil.decodeImage(null, "image/jp2", imageBytes.inputStream())
        val baos   = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 100, baos)
        return baos.toByteArray()
    }

    private fun isJP2(bytes: ByteArray): Boolean =
        bytes.size > 4 &&
                bytes[0] == 0x00.toByte() &&
                bytes[1] == 0x00.toByte() &&
                bytes[2] == 0x00.toByte() &&
                bytes[3] == 0x0C.toByte()
}