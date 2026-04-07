package foundation.privacybydesign.vcmrtd.biometrics

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import kotlinx.coroutines.channels.Channel
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Service responsible for detecting "liveness" in a stream of face images.
 * It combines multiple techniques:
 * 1. Deep Learning based anti-spoofing (MiniFASNet) to detect masks, photos, or screens.
 * 2. rPPG (remote Photoplethysmography) to detect a pulse from skin color variations.
 * 3. Harmonic analysis of the pulse signal to ensure it looks like a human heartbeat.
 */
class LivenessService(private val context: Context) {

    private var faceLandmarker: FaceLandmarker? = null

    companion object {
        private const val TAG = "LivenessService"
        private const val MODEL_FILE = "face_landmarker.task"
        private const val MINIFASNET_V1SE_FILE = "minifasnet_v1se.tflite"
        private const val MINIFASNET_V2_FILE = "minifasnet_v2.tflite"

        // Thresholds for rPPG signal quality
        private const val MIN_SNR = 1.5
        private const val VALID_HR_MIN = 45.0                 
        private const val VALID_HR_MAX = 110.0
        private const val MAX_HARMONIC_RATIO = 0.8
        private const val MIN_FUNDAMENTAL_RATIO = 2.0
        private const val ROI_FRACTION = 0.15f
        private const val POS_WINDOW_SECONDS = 2.0

        // Thresholds for MiniFASNet anti-spoofing
        private const val MIN_ANTI_SPOOF_SCORE = 0.95
        private const val MIN_LIVE_RATIO = 0.95
    }

    /**
     * Initializes the service by loading MediaPipe and MiniFASNet models.
     */
    fun initialize() {
        android.util.Log.d(TAG, "Initializing LivenessService")

        val baseOptions = BaseOptions.builder()
            .setModelAssetPath(MODEL_FILE)
            .build()

        val options = FaceLandmarker.FaceLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setMinFaceDetectionConfidence(0.5f)
            .setMinFacePresenceConfidence(0.5f)
            .setNumFaces(1)
            .setRunningMode(RunningMode.IMAGE)
            .build()

        faceLandmarker = FaceLandmarker.createFromOptions(context, options)
        MiniFASNetService.initialize(context)

        android.util.Log.d(TAG, "LivenessService initialized")
    }

    /**
     * Processes a stream of bitmaps from a channel and returns true if liveness is confirmed.
     *
     * @param frameChannel The channel providing camera frames.
     * @param fps The estimated frames per second of the input stream.
     */
    suspend fun isLiveStreaming(frameChannel: Channel<Bitmap>, fps: Int): Boolean {
        val samples = mapOf(
            RoiZone.FOREHEAD to mutableListOf<FloatArray>(),
            RoiZone.LEFT_CHEEK to mutableListOf(),
            RoiZone.RIGHT_CHEEK to mutableListOf(),
            RoiZone.NOSE to mutableListOf(),
            RoiZone.LIPS to mutableListOf(),
        )

        val allFrames = mutableListOf<Bitmap>()
        val faceRois = mutableListOf<Map<RoiZone, FloatArray>?>()

        var tMediaPipeTotal = 0L
        var tMediaPipeCount = 0

        // 1. Frame collection and facial landmark extraction
        for (frame in frameChannel) {
            val bitmap = frame.toArgb8888()

            val tMp = System.currentTimeMillis()
            val rois = detectRois(bitmap)
            tMediaPipeTotal += System.currentTimeMillis() - tMp
            tMediaPipeCount++

            faceRois.add(rois)

            // Extract RGB mean values only when this exact frame has valid ROIs.
            rois?.forEach { (zone, roi) ->
                extractRgbFromRoi(bitmap, roi)?.let { rgb ->
                    samples[zone]?.add(rgb)
                }
            }

            allFrames.add(bitmap)
        }

        val tStream = System.currentTimeMillis()

        android.util.Log.d(
            TAG,
            "Streaming complete — samples per zone: " +
                    samples.map { "${it.key.name}=${it.value.size}" }.joinToString()
        )
        android.util.Log.d(
            TAG,
            "Time MediaPipe avg per frame: " +
                    "${if (tMediaPipeCount > 0) tMediaPipeTotal / tMediaPipeCount else 0}ms " +
                    "over $tMediaPipeCount frames (total: ${tMediaPipeTotal}ms)"
        )

        val foreheadSamples = samples[RoiZone.FOREHEAD] ?: emptyList()
        if (foreheadSamples.isEmpty()) {
            android.util.Log.w(TAG, "No usable forehead samples")
            return false
        }

        // 2. Run Deep Learning Anti-Spoofing (MiniFASNet)
        val tAntiSpoof = System.currentTimeMillis()
        val antiSpoof = MiniFASNetService.score(allFrames, faceRois)
        android.util.Log.d(
            TAG,
            "MiniFASNet avgLiveScore: ${"%.3f".format(antiSpoof.avgLiveScore)}, " +
                    "liveRatio: ${"%.3f".format(antiSpoof.liveRatio)}, " +
                    "usedFrames: ${antiSpoof.usedFrames}"
        )
        android.util.Log.d(TAG, "Time MiniFASNet: ${System.currentTimeMillis() - tAntiSpoof}ms")

        // 3. Run rPPG Pulse Analysis
        val tRppg = System.currentTimeMillis()
        val foreheadRaw = posAlgorithmWindowed(foreheadSamples, fps)
        val filtered = bandpassFilter(foreheadRaw, 0.7, 4.0, fps.toDouble())
        val fftData = fft(filtered)

        val snr = calculateSnrFromFft(fftData, fps.toDouble())
        val heartRate = estimateHeartRate(filtered, fps)
        val isValidHarmonics = checkHarmonicStructureFromFft(fftData, fps.toDouble())
        val isValidHr = heartRate != null && heartRate in VALID_HR_MIN..VALID_HR_MAX

        android.util.Log.d(
            TAG,
            "rPPG — SNR: ${"%.2f".format(snr)}, HR: $heartRate, " +
                    "harmonics: $isValidHarmonics, validHR: $isValidHr"
        )
        android.util.Log.d(TAG, "Time rPPG+harmonics: ${System.currentTimeMillis() - tRppg}ms")

        // Final decision combines classification and physiological signal checks
        val antiSpoofPass =
            antiSpoof.avgLiveScore >= MIN_ANTI_SPOOF_SCORE &&
                    antiSpoof.liveRatio >= MIN_LIVE_RATIO

        val rppgPass =
            isValidHarmonics &&
                    isValidHr &&
                    snr >= MIN_SNR

        android.util.Log.d(
            TAG,
            "Checks — " +
                    "antiSpoofScore=${"%.3f".format(antiSpoof.avgLiveScore)} " +
                    "liveRatio=${"%.3f".format(antiSpoof.liveRatio)} " +
                    "antiSpoofPass=$antiSpoofPass " +
                    "snr=${"%.2f".format(snr)} " +
                    "harmonics=$isValidHarmonics " +
                    "hr=$heartRate validHr=$isValidHr " +
                    "rppgPass=$rppgPass"
        )

        val result = antiSpoofPass && rppgPass

        android.util.Log.d(TAG, "Liveness: $result")
        android.util.Log.d(
            TAG,
            "Time total processing (excl. streaming): ${System.currentTimeMillis() - tStream}ms"
        )

        return result
    }

    enum class RoiZone { FOREHEAD, LEFT_CHEEK, RIGHT_CHEEK, NOSE, LIPS }

    private data class FftData(
        val re: DoubleArray,
        val im: DoubleArray
    )

    /**
     * Identifies Regions of Interest on the face using landmarks.
     */
    private fun detectRois(bitmap: Bitmap): Map<RoiZone, FloatArray>? {
        val mpImage = BitmapImageBuilder(bitmap).build()
        val result = faceLandmarker?.detect(mpImage) ?: return null
        if (result.faceLandmarks().isEmpty()) return null

        val lm = result.faceLandmarks()[0]
        val faceWidth = lm[338].x() - lm[109].x()
        val roiSize = faceWidth * ROI_FRACTION

        return mapOf(
            RoiZone.FOREHEAD to floatArrayOf(
                lm[10].x(),
                lm[10].y() - roiSize * 0.3f,
                roiSize
            ),
            RoiZone.RIGHT_CHEEK to floatArrayOf(lm[205].x(), lm[205].y(), roiSize),
            RoiZone.LEFT_CHEEK to floatArrayOf(lm[425].x(), lm[425].y(), roiSize),
            RoiZone.NOSE to floatArrayOf(lm[4].x(), lm[4].y(), roiSize * 0.8f),
            RoiZone.LIPS to floatArrayOf(
                (lm[0].x() + lm[17].x()) / 2f,
                (lm[0].y() + lm[17].y()) / 2f,
                roiSize
            ),
        )
    }

    /**
     * Extracts mean RGB color values from a defined region of the image.
     */
    private fun extractRgbFromRoi(bitmap: Bitmap, roi: FloatArray): FloatArray? {
        val w = bitmap.width
        val h = bitmap.height

        val cx = (roi[0] * w).toInt()
        val cy = (roi[1] * h).toInt()
        val half = ((roi[2] * w) / 2).toInt().coerceAtLeast(5)

        val x1 = (cx - half).coerceIn(0, w - 1)
        val y1 = (cy - half).coerceIn(0, h - 1)
        val x2 = (cx + half).coerceIn(0, w - 1)
        val y2 = (cy + half).coerceIn(0, h - 1)

        if (x2 <= x1 || y2 <= y1) return null

        val pixels = IntArray((x2 - x1) * (y2 - y1))
        bitmap.getPixels(pixels, 0, x2 - x1, x1, y1, x2 - x1, y2 - y1)

        var sumR = 0L
        var sumG = 0L
        var sumB = 0L

        for (p in pixels) {
            sumR += Color.red(p)
            sumG += Color.green(p)
            sumB += Color.blue(p)
        }

        val n = pixels.size.toFloat()
        return floatArrayOf(sumR / n, sumG / n, sumB / n)
    }

    /**
     * Internal service for classification-based anti-spoofing.
     * Uses two MiniFASNet models to detect non-live faces (photos, masks, etc.).
     */
    private object MiniFASNetService {
        private const val INPUT_SIZE = 80 // size 80x80 MiniFASnet requirement
        private const val SAMPLE_INTERVAL = 5
        private const val LIVE_CLASS_IDX = 1
        private const val SCALE_V2 = 2.7f

        private var interpreterV1se: Interpreter? = null
        private var interpreterV2: Interpreter? = null

        data class AntiSpoofResult(
            val avgLiveScore: Double,
            val liveRatio: Double,
            val usedFrames: Int
        )

        /**
         * Loads the TFLite models.
         */
        fun initialize(context: Context) {
            if (interpreterV1se == null) {
                interpreterV1se = loadInterpreter(context, MINIFASNET_V1SE_FILE)
            }
            if (interpreterV2 == null) {
                interpreterV2 = loadInterpreter(context, MINIFASNET_V2_FILE)
            }

            android.util.Log.d(
                TAG,
                "MiniFASNet interpreters ready: " +
                        "v1seLoaded=${interpreterV1se != null}, v2Loaded=${interpreterV2 != null}"
            )
        }

        /**
         * Analyzes multiple frames and returns an aggregated live score.
         */
        fun score(
            frames: List<Bitmap>,
            faceRois: List<Map<RoiZone, FloatArray>?>
        ): AntiSpoofResult {
            val interpreterV1se = interpreterV1se
            val interpreterV2 = interpreterV2

            if (interpreterV1se == null || interpreterV2 == null) {
                android.util.Log.d(TAG, "MiniFASNet interpreters not initialized — returning fail result")
                return AntiSpoofResult(
                    avgLiveScore = 0.0,
                    liveRatio = 0.0,
                    usedFrames = 0
                )
            }

            val shapeV1 = interpreterV1se.getInputTensor(0).shape()
            val shapeV2 = interpreterV2.getInputTensor(0).shape()

            val isNchwV1 = shapeV1.size == 4 && shapeV1[1] == 3
            val isNchwV2 = shapeV2.size == 4 && shapeV2[1] == 3

            android.util.Log.d(
                TAG,
                "MiniFASNet shapes — " +
                        "V1SE=${shapeV1.toList()} (${if (isNchwV1) "NCHW" else "NHWC"}), " +
                        "V2=${shapeV2.toList()} (${if (isNchwV2) "NCHW" else "NHWC"})"
            )

            val frameScores = mutableListOf<Double>()
            var liveFrames = 0
            var totalFramesUsed = 0

            frames.forEachIndexed { idx, frame ->
                if (idx % SAMPLE_INTERVAL != 0) return@forEachIndexed

                val rois = faceRois.getOrNull(idx) ?: return@forEachIndexed
                val bbox = faceBoxPixels(rois, frame.width, frame.height) ?: return@forEachIndexed

                val cropV1se = cropWithScale(frame, bbox, scale = null) ?: return@forEachIndexed
                val cropV2 = cropWithScale(frame, bbox, scale = SCALE_V2) ?: return@forEachIndexed

                val inputV1 = if (isNchwV1) preprocessNchw(cropV1se) else preprocessNhwc(cropV1se)
                val inputV2 = if (isNchwV2) preprocessNchw(cropV2) else preprocessNhwc(cropV2)

                val outV1 = Array(1) { FloatArray(3) }
                val outV2 = Array(1) { FloatArray(3) }

                interpreterV1se.run(inputV1, outV1)
                interpreterV2.run(inputV2, outV2)

                val smV1 = softmax(outV1[0])
                val smV2 = softmax(outV2[0])

                val combined = FloatArray(3) { i -> smV1[i] + smV2[i] }

                var label = 0
                var best = Float.NEGATIVE_INFINITY
                for (i in combined.indices) {
                    if (combined[i] > best) {
                        best = combined[i]
                        label = i
                    }
                }

                val liveConfidence = (combined[LIVE_CLASS_IDX] / 2f).toDouble()

                totalFramesUsed++
                if (label == LIVE_CLASS_IDX) liveFrames++

                val frameScore = if (label == LIVE_CLASS_IDX) liveConfidence else 0.0
                frameScores.add(frameScore)

                android.util.Log.d(
                    TAG,
                    "frame=$idx " +
                            "bbox=[${bbox.joinToString()}] " +
                            "v1=[${smV1.joinToString { "%.3f".format(it) }}] " +
                            "v2=[${smV2.joinToString { "%.3f".format(it) }}] " +
                            "combined=[${combined.joinToString { "%.3f".format(it) }}] " +
                            "label=$label liveScore=${"%.3f".format(frameScore)}"
                )
            }

            if (totalFramesUsed == 0) {
                android.util.Log.d(TAG, "No valid MiniFASNet frames — returning fail result")
                return AntiSpoofResult(
                    avgLiveScore = 0.0,
                    liveRatio = 0.0,
                    usedFrames = 0
                )
            }

            val avgLiveScore = frameScores.average()
            val liveRatio = liveFrames.toDouble() / totalFramesUsed.toDouble()

            android.util.Log.d(
                TAG,
                "MiniFASNet summary — avgLiveScore=${"%.3f".format(avgLiveScore)}, " +
                        "liveRatio=${"%.3f".format(liveRatio)}, usedFrames=$totalFramesUsed"
            )

            return AntiSpoofResult(
                avgLiveScore = avgLiveScore,
                liveRatio = liveRatio,
                usedFrames = totalFramesUsed
            )
        }

        /**
         * Closes interpreters and releases resources.
         */
        fun close() {
            interpreterV1se?.close()
            interpreterV1se = null
            interpreterV2?.close()
            interpreterV2 = null
            android.util.Log.d(TAG, "MiniFASNet interpreters released")
        }

        /**
         * Calculates a bounding box around the facial features.
         */
        private fun faceBoxPixels(
            rois: Map<RoiZone, FloatArray>,
            imgW: Int,
            imgH: Int
        ): IntArray? {
            val leftCheek = rois[RoiZone.LEFT_CHEEK] ?: return null
            val rightCheek = rois[RoiZone.RIGHT_CHEEK] ?: return null
            val forehead = rois[RoiZone.FOREHEAD] ?: return null
            val lips = rois[RoiZone.LIPS] ?: return null

            val leftXNorm = min(leftCheek[0], rightCheek[0])
            val rightXNorm = max(leftCheek[0], rightCheek[0])
            val topYNorm = min(forehead[1], lips[1])
            val bottomYNorm = max(forehead[1], lips[1])

            val x = (leftXNorm * imgW).toInt().coerceIn(0, imgW - 1)
            val y = (topYNorm * imgH).toInt().coerceIn(0, imgH - 1)
            val w = ((rightXNorm - leftXNorm) * imgW).toInt().coerceAtLeast(1)
            val h = ((bottomYNorm - topYNorm) * imgH).toInt().coerceAtLeast(1)

            if (w <= 1 || h <= 1) return null
            return intArrayOf(x, y, w, h)
        }

        /**
         * Crops and resizes the face region for model input.
         */
        private fun cropWithScale(bitmap: Bitmap, bbox: IntArray, scale: Float?): Bitmap? {
            val bmp = if (bitmap.config == Bitmap.Config.ARGB_8888) bitmap
            else bitmap.copy(Bitmap.Config.ARGB_8888, false)

            val srcW = bmp.width
            val srcH = bmp.height

            if (scale == null) {
                return Bitmap.createScaledBitmap(bmp, INPUT_SIZE, INPUT_SIZE, true)
            }

            val x = bbox[0]
            val y = bbox[1]
            val boxW = bbox[2]
            val boxH = bbox[3]

            val s = min(
                (srcH - 1f) / boxH,
                min((srcW - 1f) / boxW, scale)
            )

            val newW = boxW * s
            val newH = boxH * s
            val cx = boxW / 2f + x
            val cy = boxH / 2f + y

            var ltX = cx - newW / 2f
            var ltY = cy - newH / 2f
            var rbX = cx + newW / 2f
            var rbY = cy + newH / 2f

            if (ltX < 0f) {
                rbX -= ltX
                ltX = 0f
            }
            if (ltY < 0f) {
                rbY -= ltY
                ltY = 0f
            }
            if (rbX > srcW - 1f) {
                ltX -= rbX - srcW + 1
                rbX = srcW - 1f
            }
            if (rbY > srcH - 1f) {
                ltY -= rbY - srcH + 1
                rbY = srcH - 1f
            }

            val x1 = ltX.toInt().coerceIn(0, srcW - 1)
            val y1 = ltY.toInt().coerceIn(0, srcH - 1)
            val x2 = rbX.toInt().coerceIn(0, srcW - 1)
            val y2 = rbY.toInt().coerceIn(0, srcH - 1)

            if (x2 <= x1 || y2 <= y1) return null

            val cropped = Bitmap.createBitmap(bmp, x1, y1, x2 - x1, y2 - y1)
            return Bitmap.createScaledBitmap(cropped, INPUT_SIZE, INPUT_SIZE, true)
        }

        /**
         * Prepares buffer in NCHW format.
         */
        private fun preprocessNchw(bitmap: Bitmap): ByteBuffer {
            val pixels = IntArray(INPUT_SIZE * INPUT_SIZE)
            bitmap.getPixels(pixels, 0, INPUT_SIZE, 0, 0, INPUT_SIZE, INPUT_SIZE)

            val buf = ByteBuffer
                .allocateDirect(1 * 3 * INPUT_SIZE * INPUT_SIZE * 4)
                .order(ByteOrder.nativeOrder())

            var minVal = Float.POSITIVE_INFINITY
            var maxVal = Float.NEGATIVE_INFINITY

            for (p in pixels) {
                val v = Color.blue(p).toFloat()
                buf.putFloat(v)
                if (v < minVal) minVal = v
                if (v > maxVal) maxVal = v
            }
            for (p in pixels) {
                val v = Color.green(p).toFloat()
                buf.putFloat(v)
                if (v < minVal) minVal = v
                if (v > maxVal) maxVal = v
            }
            for (p in pixels) {
                val v = Color.red(p).toFloat()
                buf.putFloat(v)
                if (v < minVal) minVal = v
                if (v > maxVal) maxVal = v
            }

            buf.rewind()
            android.util.Log.d(TAG, "MiniFASNet NCHW input min/max = $minVal / $maxVal")
            return buf
        }

        /**
         * Prepares buffer in NHWC format.
         */
        private fun preprocessNhwc(bitmap: Bitmap): ByteBuffer {
            val pixels = IntArray(INPUT_SIZE * INPUT_SIZE)
            bitmap.getPixels(pixels, 0, INPUT_SIZE, 0, 0, INPUT_SIZE, INPUT_SIZE)

            val buf = ByteBuffer
                .allocateDirect(1 * INPUT_SIZE * INPUT_SIZE * 3 * 4)
                .order(ByteOrder.nativeOrder())

            var minVal = Float.POSITIVE_INFINITY
            var maxVal = Float.NEGATIVE_INFINITY

            for (p in pixels) {
                val b = Color.blue(p).toFloat()
                val g = Color.green(p).toFloat()
                val r = Color.red(p).toFloat()

                buf.putFloat(b)
                buf.putFloat(g)
                buf.putFloat(r)

                if (b < minVal) minVal = b
                if (g < minVal) minVal = g
                if (r < minVal) minVal = r

                if (b > maxVal) maxVal = b
                if (g > maxVal) maxVal = g
                if (r > maxVal) maxVal = r
            }

            buf.rewind()
            android.util.Log.d(TAG, "MiniFASNet NHWC input min/max = $minVal / $maxVal")
            return buf
        }

        private fun softmax(logits: FloatArray): FloatArray {
            var maxLogit = Float.NEGATIVE_INFINITY
            for (v in logits) {
                if (v > maxLogit) maxLogit = v
            }

            val exps = FloatArray(logits.size)
            var sum = 0f

            for (i in logits.indices) {
                exps[i] = exp((logits[i] - maxLogit).toDouble()).toFloat()
                sum += exps[i]
            }

            val denom = if (sum > 1e-12f) sum else 1e-12f
            return FloatArray(logits.size) { i -> exps[i] / denom }
        }

        private fun loadInterpreter(context: Context, fileName: String): Interpreter? {
            return try {
                val afd = context.assets.openFd(fileName)
                val fis = FileInputStream(afd.fileDescriptor)
                val mapped = fis.channel.map(
                    FileChannel.MapMode.READ_ONLY,
                    afd.startOffset,
                    afd.declaredLength
                )
                fis.close()

                val options = Interpreter.Options().apply {
                    setNumThreads(1)
                }

                Interpreter(mapped, options)
            } catch (e: Exception) {
                android.util.Log.d(TAG, "Failed to load $fileName: ${e.message}")
                null
            }
        }
    }

    /**
     * Plane-Orthogonal-to-Skin (POS) algorithm for rPPG.
     * Extracts pulse-induced color variations while rejecting motion and lighting artifacts.
     */
    private fun posAlgorithmWindowed(samples: List<FloatArray>, fps: Int): List<Double> {
        val n = samples.size
        val windowSize = (POS_WINDOW_SECONDS * fps).toInt().coerceIn(10, n)
        val out = DoubleArray(n)
        val count = IntArray(n)

        var sumR = 0.0
        var sumG = 0.0
        var sumB = 0.0

        for (end in samples.indices) {
            sumR += samples[end][0]
            sumG += samples[end][1]
            sumB += samples[end][2]

            val start = end - windowSize + 1
            if (start > 0) {
                sumR -= samples[start - 1][0]
                sumG -= samples[start - 1][1]
                sumB -= samples[start - 1][2]
            }

            val winStart = maxOf(0, start)
            val wLen = end - winStart + 1
            if (wLen < 2) continue

            val meanR = sumR / wLen
            val meanG = sumG / wLen
            val meanB = sumB / wLen
            if (meanR < 1e-6 || meanG < 1e-6 || meanB < 1e-6) continue

            val rN = samples[end][0] / meanR
            val gN = samples[end][1] / meanG
            val bN = samples[end][2] / meanB

            val s1 = gN - bN
            val s2 = gN + bN - 2 * rN

            val s1Arr = DoubleArray(wLen) { i ->
                val s = samples[winStart + i]
                s[1] / meanG - s[2] / meanB
            }
            val s2Arr = DoubleArray(wLen) { i ->
                val s = samples[winStart + i]
                s[1] / meanG + s[2] / meanB - 2 * s[0] / meanR
            }

            val alpha = calculateStd(s1Arr) / (calculateStd(s2Arr) + 1e-8)
            out[end] += s1 + alpha * s2
            count[end]++
        }

        return out.indices.map { i ->
            if (count[i] > 0) out[i] / count[i] else 0.0
        }
    }

    private fun movingAverage(signal: List<Double>, window: Int): List<Double> {
        if (window <= 1) return signal

        val half = window / 2
        val result = DoubleArray(signal.size)

        var sum = 0.0
        var count = 0

        for (i in 0..min(half, signal.size - 1)) {
            sum += signal[i]
            count++
        }

        for (i in signal.indices) {
            val addIdx = i + half
            if (addIdx < signal.size && addIdx > half) {
                sum += signal[addIdx]
                count++
            }

            val removeIdx = i - half - 1
            if (removeIdx >= 0) {
                sum -= signal[removeIdx]
                count--
            }

            result[i] = sum / count
        }

        return result.toList()
    }

    private fun bandpassFilter(
        signal: List<Double>,
        lowHz: Double,
        highHz: Double,
        fs: Double
    ): List<Double> {
        val smoothed = movingAverage(signal, (fs / highHz).toInt().coerceAtLeast(1))
        val trend = movingAverage(smoothed, (fs / lowHz).toInt().coerceAtLeast(1))
        return smoothed.zip(trend) { s, t -> s - t }
    }

    /**
     * Fast Fourier Transform implementation for frequency analysis.
     */
    private fun fft(signal: List<Double>): FftData {
        val n = nextPowerOfTwo(signal.size)
        val re = DoubleArray(n) { if (it < signal.size) signal[it] else 0.0 }
        val im = DoubleArray(n)

        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j and bit != 0) {
                j = j xor bit
                bit = bit shr 1
            }
            j = j xor bit

            if (i < j) {
                val tmpRe = re[i]
                re[i] = re[j]
                re[j] = tmpRe

                val tmpIm = im[i]
                im[i] = im[j]
                im[j] = tmpIm
            }
        }

        var len = 2
        while (len <= n) {
            val half = len / 2
            val wRe = cos(2 * PI / len)
            val wIm = -sin(2 * PI / len)

            var i = 0
            while (i < n) {
                var cRe = 1.0
                var cIm = 0.0

                for (k in 0 until half) {
                    val uRe = re[i + k]
                    val uIm = im[i + k]
                    val vRe = re[i + k + half] * cRe - im[i + k + half] * cIm
                    val vIm = re[i + k + half] * cIm + im[i + k + half] * cRe

                    re[i + k] = uRe + vRe
                    im[i + k] = uIm + vIm
                    re[i + k + half] = uRe - vRe
                    im[i + k + half] = uIm - vIm

                    val nextCRe = cRe * wRe - cIm * wIm
                    cIm = cRe * wIm + cIm * wRe
                    cRe = nextCRe
                }
                i += len
            }
            len = len shl 1
        }

        return FftData(re = re, im = im)
    }

    private fun nextPowerOfTwo(n: Int): Int {
        var p = 1
        while (p < n) p = p shl 1
        return p
    }

    /**
     * Calculates SNR by comparing power in the heartbeat band to total signal power.
     */
    private fun calculateSnrFromFft(fftData: FftData, fs: Double): Double {
        val re = fftData.re
        val im = fftData.im
        val n = re.size
        val half = n / 2

        var signalPower = 0.0
        var totalPower = 0.0

        for (k in 0 until half) {
            val freq = k * fs / n
            val power = (re[k] * re[k] + im[k] * im[k]) / n
            totalPower += power
            if (freq in 0.7..4.0) signalPower += power
        }

        val noisePower = totalPower - signalPower
        return if (noisePower > 0) signalPower / noisePower else 0.0
    }

    /**
     * Checks if the frequency spectrum contains a clear pulse peak and harmonic structure.
     */
    private fun checkHarmonicStructureFromFft(fftData: FftData, fs: Double): Boolean {
        val re = fftData.re
        val im = fftData.im
        val n = re.size
        val half = n / 2

        val freqs = DoubleArray(half) { k -> k * fs / n }
        val power = DoubleArray(half) { k -> (re[k] * re[k] + im[k] * im[k]) / n }

        var f0Idx = -1
        var f0Power = 0.0

        for (k in freqs.indices) {
            if (freqs[k] in 0.7..4.0 && power[k] > f0Power) {
                f0Power = power[k]
                f0Idx = k
            }
        }

        if (f0Idx < 0) return false

        val f0 = freqs[f0Idx]
        val h2Target = f0 * 2.0
        val h2Idx = freqs.indices.minByOrNull { abs(freqs[it] - h2Target) } ?: return false
        val h2Power = if (freqs[h2Idx] in (h2Target * 0.9)..(h2Target * 1.1)) power[h2Idx] else 0.0

        val harmonicRatio = if (f0Power > 0) h2Power / f0Power else 1.0
        val excludeIdx = setOf(f0Idx - 1, f0Idx, f0Idx + 1, h2Idx - 1, h2Idx, h2Idx + 1)
        val noiseSamples = freqs.indices
            .filter { freqs[it] in 0.7..4.0 && it !in excludeIdx }
            .map { power[it] }

        val noiseFloor = if (noiseSamples.isNotEmpty()) noiseSamples.average() else 0.0
        val fundamentalRatio = if (noiseFloor > 0) f0Power / noiseFloor else 0.0

        android.util.Log.d(
            TAG,
            "Harmonics: ratio=${"%.3f".format(harmonicRatio)} " +
                    "fundamental=${"%.2f".format(fundamentalRatio)}"
        )

        return harmonicRatio < MAX_HARMONIC_RATIO &&
                fundamentalRatio >= MIN_FUNDAMENTAL_RATIO
    }

    /**
     * Estimates heart rate from signal peaks in the time domain.
     */
    private fun estimateHeartRate(signal: List<Double>, fps: Int): Double? {
        val peaks = findPeaks(signal, (fps * 0.4).toInt())
        if (peaks.size < 2) return null

        val intervals = (1 until peaks.size).map { i ->
            (peaks[i] - peaks[i - 1]) / fps.toDouble()
        }

        val valid = intervals.filter { it in 0.4..1.5 }
        return if (valid.isEmpty()) null else 60.0 / valid.average()
    }

    private fun findPeaks(signal: List<Double>, minDistance: Int): List<Int> {
        val peaks = mutableListOf<Int>()

        for (i in 1 until signal.size - 1) {
            if (signal[i] > signal[i - 1] && signal[i] > signal[i + 1]) {
                if (peaks.isEmpty() || i - peaks.last() >= minDistance) {
                    peaks.add(i)
                } else if (signal[i] > signal[peaks.last()]) {
                    peaks[peaks.lastIndex] = i
                }
            }
        }

        return peaks
    }

    private fun calculateStd(arr: DoubleArray): Double {
        if (arr.isEmpty()) return 0.0
        val mean = arr.average()
        return sqrt(arr.fold(0.0) { acc, v -> acc + (v - mean).pow(2) } / arr.size)
    }

    /**
     * Releases model resources.
     */
    fun close() {
        faceLandmarker?.close()
        faceLandmarker = null
        MiniFASNetService.close()
    }

    private fun Bitmap.toArgb8888(): Bitmap =
        if (config == Bitmap.Config.ARGB_8888) this else copy(Bitmap.Config.ARGB_8888, false)
}