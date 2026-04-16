package foundation.privacybydesign.vcmrtd.biometrics

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.os.SystemClock
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import kotlin.math.PI
import kotlin.math.abs
import kotlin.random.Random
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

class PassiveLivenessService(
    private val context: Context,
    private val livenessService: LivenessService
) {
    companion object {
        private const val TAG = "PassiveLivenessService"
        private const val MINIFASNET_V1SE = "minifasnet_v1se.tflite"
        private const val MINIFASNET_V2 = "minifasnet_v2.tflite"
        private const val MIN_SNR = 2.0
        private const val VALID_HR_MIN = 45.0
        private const val VALID_HR_MAX = 110.0
        private const val MAX_HARMONIC_RATIO = 0.8
        private const val MIN_FUNDAMENTAL = 2.0
        private const val POS_WINDOW_SECONDS = 3.0
        private const val RPPG_ALLOW_HARMONICS_FALLBACK = true
        private const val MIN_ANTISPOOF = 0.95
        private const val MIN_LIVE_RATIO = 0.95

        // Placeholder: thresholds may need adjustment after real-device testing
        // Current behaviour: null scores (no face detected) are treated as pass
        const val ANTISPOOF_MIN_SCORE = 0.65

        // ── Per-session passive metric collection ──
        private const val ANTISPOOF_SAMPLE_RATE = 0.30f  // fraction of frames scored
        private const val ANTISPOOF_MAX_YAW_DEG = 15f    // skip non-frontal frames
        private const val RPPG_FRONTAL_MAX_YAW  = 10f    // only collect rPPG when nearly frontal
        private const val RPPG_MAX_GAP_MS       = 1000L  // reset if gap between frames > 1 s
        private const val RPPG_MIN_ROI_PIX      = 12     // minimum ROI width in pixels
        private const val RPPG_ENLARGE_FACTOR   = 1.8f   // enlarge tiny ROIs before sampling
    }

    private data class FftData(val re: DoubleArray, val im: DoubleArray)

    data class RppgResult(
        val hr: Double?,
        val snr: Double,
        val harmonicsOk: Boolean,
        val passed: Boolean,
        val sampleCount: Int = 0,
        val durationMs: Long = 0L
    )

    // ── Per-session accumulated passive metrics ──
    // Populated by collectPassiveMetrics() during the active liveness session.
    // Cleared by reset() between sessions.
    private val antiSpoofScores  = mutableListOf<Double?>()
    private var antiSpoofAttempts = 0
    private var totalFrames       = 0
    private val rppgSamples      = mutableListOf<FloatArray>()
    private val rppgSampleTimes  = mutableListOf<Long>()

    fun initialize() {
        MiniFASNetService.initialize(context)
        android.util.Log.d(TAG, "PassiveLivenessService initialized")
    }

    /**
     * Scores a single frame for liveness using MiniFASNet.
     * Returns a score in [0.0, 1.0] where higher = more likely live.
     * Returns null if the frame could not be scored (no face box, model not loaded).
     *
     * Designed for use during active liveness — pass the bitmap and ROIs
     * already computed from the active liveness MediaPipe result to avoid
     * redundant processing.
     */
    fun scoreFrame(bitmap: Bitmap, rois: Map<LivenessService.RoiZone, FloatArray>): Double? {
        val result = MiniFASNetService.score(listOf(bitmap), listOf(rois))
        return if (result.usedFrames == 0) null else result.avgLiveScore
    }

    /**
     * Determine whether the average MiniFASNet score passes the threshold.
     * Frames with null scores (no face detected) are allowed through — no score
     * is treated as no evidence of spoofing (fail-open for UX).
     * Returns true if there are no valid scores, or if the mean >= ANTISPOOF_MIN_SCORE.
     */
    private fun isAntiSpoofPassed(scores: List<Double?>): Boolean {
        val valid = scores.filterNotNull()
        if (valid.isEmpty()) {
            android.util.Log.w(TAG, "isAntiSpoofPassed: no valid scores, allowing pass (fail-open)")
            return true
        }
        val avg = valid.average()
        val passed = avg >= ANTISPOOF_MIN_SCORE
        android.util.Log.d(TAG,
            "isAntiSpoofPassed: avg=${"%.3f".format(avg)} threshold=$ANTISPOOF_MIN_SCORE " +
                    "passed=$passed (${valid.size} of ${scores.size} scores valid)")
        return passed
    }


    fun close() {
        MiniFASNetService.close()
        android.util.Log.d(TAG, "PassiveLivenessService closed")
    }

    // ═══════════════════════════════════════════
    //  Per-session state — public API
    // ═══════════════════════════════════════════

    /** Clears all accumulated passive metrics. Call between sessions. */
    fun reset() {
        antiSpoofScores.clear()
        antiSpoofAttempts = 0
        totalFrames = 0
        rppgSamples.clear()
        rppgSampleTimes.clear()
    }

    /** Returns the running mean anti-spoof score, or null if no frames scored yet. */
    fun getAntiSpoofScore(): Double? {
        val valid = antiSpoofScores.filterNotNull()
        return if (valid.isEmpty()) null else valid.average()
    }

    /** Returns whether the accumulated anti-spoof scores pass the liveness threshold. */
    fun isAntiSpoofPassed(): Boolean = isAntiSpoofPassed(antiSpoofScores)

    fun getAntiSpoofAttempts(): Int = antiSpoofAttempts

    /** Total frames processed via [collectPassiveMetrics] in this session. */
    fun getTotalFrames(): Int = totalFrames

    /**
     * Collects passive liveness metrics (anti-spoof + rPPG) from one active-session frame.
     *
     * Must be called with an ARGB_8888 [bitmap] and the already-computed MediaPipe [result]
     * for that frame — reuses the existing detection result to avoid a redundant model call.
     */
    fun collectPassiveMetrics(bitmap: Bitmap, result: FaceLandmarkerResult) {
        totalFrames++
        val yaw = livenessService.matrixYaw(result)
        sampleAntiSpoof(bitmap, result, yaw)
        try {
            sampleRppg(bitmap, result, yaw)
        } catch (e: Exception) { android.util.Log.w(TAG, "collectPassiveMetrics: rPPG sampling error", e) }
    }

    private fun sampleAntiSpoof(bitmap: Bitmap, result: FaceLandmarkerResult, yaw: Float?) {
        if (Random.nextFloat() >= ANTISPOOF_SAMPLE_RATE) return
        antiSpoofAttempts++
        val isFrontal = yaw == null || abs(yaw) < ANTISPOOF_MAX_YAW_DEG
        if (!isFrontal) {
            android.util.Log.d(TAG,
                "AntiSpoof: frame skipped (yaw=${"%.1f".format(yaw ?: 0f)}° > ${ANTISPOOF_MAX_YAW_DEG}°)")
            return
        }
        val rois = livenessService.extractRois(result) ?: return
        val score = scoreFrame(bitmap, rois)
        antiSpoofScores.add(score)
        if (score != null) {
            android.util.Log.d(TAG,
                "AntiSpoof score=${"%.3f".format(score)} " +
                "yaw=${yaw?.let { "%.1f".format(it) } ?: "null"} " +
                "samples=${antiSpoofScores.filterNotNull().size}")
        }
    }

    private fun sampleRppg(bitmap: Bitmap, result: FaceLandmarkerResult, yaw: Float?) {
        val roisAll = livenessService.extractRois(result) ?: return
        val now = SystemClock.elapsedRealtime()
        if (rppgSampleTimes.isNotEmpty() && now - rppgSampleTimes.last() > RPPG_MAX_GAP_MS) {
            rppgSamples.clear(); rppgSampleTimes.clear()
        }
        if (yaw != null && abs(yaw) > RPPG_FRONTAL_MAX_YAW) return
        val zones = listOf(
            LivenessService.RoiZone.FOREHEAD,
            LivenessService.RoiZone.LEFT_CHEEK,
            LivenessService.RoiZone.RIGHT_CHEEK,
            LivenessService.RoiZone.NOSE
        )
        var sumR = 0f; var sumG = 0f; var sumB = 0f; var cnt = 0
        for (z in zones) {
            var rroi = roisAll[z] ?: continue
            if ((rroi[2] * bitmap.width).toInt() < RPPG_MIN_ROI_PIX) {
                rroi = floatArrayOf(rroi[0], rroi[1], (rroi[2] * RPPG_ENLARGE_FACTOR).coerceAtMost(0.5f))
            }
            val rgb = livenessService.extractRgbFromRoi(bitmap, rroi)
            if (rgb != null) { sumR += rgb[0]; sumG += rgb[1]; sumB += rgb[2]; cnt++ }
        }
        if (cnt > 0) {
            rppgSamples.add(floatArrayOf(sumR / cnt, sumG / cnt, sumB / cnt))
            rppgSampleTimes.add(now)
            if (rppgSamples.size > 1200) {
                rppgSamples.removeAt(0); rppgSampleTimes.removeAt(0)
            }
        }
    }

    /**
     * Returns rPPG evaluation computed from accumulated samples, or null if insufficient data.
     * Uses a sliding window to find the best contiguous frontal segment.
     */
    fun getRppgResult(): RppgResult? {
        val minSamples = 6
        val times = rppgSampleTimes
        if (rppgSamples.size < minSamples || times.size < 2) return null

        val durationMs = (times.last() - times.first()).coerceAtLeast(1L)
        val fps = (((rppgSamples.size - 1) * 1000) / durationMs).coerceAtLeast(1).toInt()
        val effectiveMinDuration = 2500L
        if (durationMs < effectiveMinDuration) return null

        val requiredSamples = (fps * 3.0).toInt().coerceAtLeast(minSamples)
        if (rppgSamples.size < requiredSamples) return null

        var bestResult: RppgResult? = null
        for (start in 0..(rppgSamples.size - requiredSamples)) {
            val windowTimes = times.subList(start, start + requiredSamples)
            if (hasWindowGap(windowTimes)) continue
            val durationWindow = (windowTimes.last() - windowTimes.first()).coerceAtLeast(1L)
            if (durationWindow < effectiveMinDuration) continue
            val windowSamples = rppgSamples.subList(start, start + requiredSamples)
            val windowFps = (((windowSamples.size - 1) * 1000) / durationWindow).coerceAtLeast(1).toInt()
            try {
                val res = evaluateRppg(windowSamples, windowFps)
                if (res.passed) return res
                if (bestResult == null || res.snr > bestResult.snr) bestResult = res
            } catch (e: Exception) { android.util.Log.w(TAG, "getRppgResult: window evaluation error", e) }
        }
        return bestResult
    }

    private fun hasWindowGap(windowTimes: List<Long>): Boolean {
        for (i in 1 until windowTimes.size) {
            if (windowTimes[i] - windowTimes[i - 1] > RPPG_MAX_GAP_MS) return true
        }
        return false
    }

    /**
     * Computes rPPG metrics (HR, SNR, harmonic-structure) from a list of RGB samples
     * (as returned by [LivenessService.extractRgbFromRoi]) and an estimated frame rate.
     * Returns a result with a boolean `passed` according to the internal thresholds.
     */
    fun evaluateRppg(samples: List<FloatArray>, fps: Int): RppgResult {
        if (samples.isEmpty() || fps <= 0) return RppgResult(null, 0.0, false, false)


        val raw = posAlgorithmWindowed(samples, fps)
        val filtered = bandpassFilter(raw, 0.7, 4.0, fps.toDouble())
        val fftData = fft(filtered)
        val snr = calculateSnrFromFft(fftData, fps.toDouble())
        val hr = estimateHeartRate(filtered, fps)
        val harmonics = checkHarmonicStructureFromFft(fftData, fps.toDouble())

        val validHr = hr != null && hr in VALID_HR_MIN..VALID_HR_MAX

        // Primary decision: require harmonics, valid HR and SNR
        var passed = harmonics && validHr && snr >= MIN_SNR
        var fallbackUsed = false
        // Fallback: allow passes when harmonics check fails but HR+SNR are good
        if (!passed && RPPG_ALLOW_HARMONICS_FALLBACK && validHr && snr >= MIN_SNR) {
            passed = true
            fallbackUsed = true
        }

        android.util.Log.d(TAG,
            "rPPG eval — HR=${hr?.let { "%.1f".format(it) } ?: "null"} SNR=${"%.2f".format(snr)} " +
                    "harmonics=$harmonics fallback=$fallbackUsed validHr=$validHr passed=$passed")


        // approximate sample/duration metadata (caller may override with exact values)
        val sampleCount = samples.size
        val durationMs = if (fps > 0) (((sampleCount - 1) * 1000) / fps).toLong() else 0L

        return RppgResult(hr, snr, harmonics, passed, sampleCount = sampleCount, durationMs = durationMs)
    }

    private object MiniFASNetService {
        private const val INPUT_SIZE = 80
        internal const val SAMPLE_INTERVAL = 5
        private const val LIVE_CLASS_IDX = 1
        private const val SCALE_V2 = 2.7f

        private var interpreterV1se: Interpreter? = null
        private var interpreterV2: Interpreter? = null

        data class AntiSpoofResult(
            val avgLiveScore: Double,
            val liveRatio: Double,
            val usedFrames: Int
        )

        fun initialize(context: Context) {
            if (interpreterV1se == null) interpreterV1se = loadInterpreter(context, MINIFASNET_V1SE)
            if (interpreterV2 == null) interpreterV2 = loadInterpreter(context, MINIFASNET_V2)
            android.util.Log.d(TAG,
                "MiniFASNet ready: v1se=${interpreterV1se != null} v2=${interpreterV2 != null}")
        }

        fun score(
            frames: List<Bitmap>,
            faceRois: List<Map<LivenessService.RoiZone, FloatArray>?>
        ): AntiSpoofResult {
            val v1 = interpreterV1se ?: return AntiSpoofResult(0.0, 0.0, 0)
            val v2 = interpreterV2 ?: return AntiSpoofResult(0.0, 0.0, 0)
            if (frames.isEmpty() || faceRois.isEmpty()) return AntiSpoofResult(0.0, 0.0, 0)

            val isNchwV1 = v1.getInputTensor(0).shape().let { it.size == 4 && it[1] == 3 }
            val isNchwV2 = v2.getInputTensor(0).shape().let { it.size == 4 && it[1] == 3 }

            val frameScores = mutableListOf<Double>()
            var liveFrames = 0
            var totalUsed = 0

            frames.forEachIndexed { idx, frame ->
                val rois = faceRois.getOrNull(idx) ?: return@forEachIndexed
                val scored = scoreFrame(frame, rois, v1, v2, isNchwV1, isNchwV2, idx) ?: return@forEachIndexed
                totalUsed++
                if (scored.first == LIVE_CLASS_IDX) liveFrames++
                frameScores.add(scored.second)
            }

            if (totalUsed == 0) return AntiSpoofResult(0.0, 0.0, 0)
            return AntiSpoofResult(
                avgLiveScore = frameScores.average(),
                liveRatio    = liveFrames.toDouble() / totalUsed,
                usedFrames   = totalUsed
            )
        }

        // Returns (label, liveConf) or null if the frame cannot be scored.
        private fun scoreFrame(
            frame: Bitmap,
            rois: Map<LivenessService.RoiZone, FloatArray>,
            v1: Interpreter, v2: Interpreter,
            isNchwV1: Boolean, isNchwV2: Boolean,
            idx: Int
        ): Pair<Int, Double>? {
            val cropV1 = cropWithScale(frame, intArrayOf(0, 0, frame.width, frame.height), null)
                ?: return null
            val bbox = faceBoxPixels(rois, frame.width, frame.height) ?: run {
                if (!cropV1.isRecycled) cropV1.recycle(); return null
            }
            val cropV2 = cropWithScale(frame, bbox, SCALE_V2) ?: run {
                if (!cropV1.isRecycled) cropV1.recycle(); return null
            }
            try {
                val inV1 = if (isNchwV1) preprocessNchw(cropV1) else preprocessNhwc(cropV1)
                val inV2 = if (isNchwV2) preprocessNchw(cropV2) else preprocessNhwc(cropV2)
                val outV1 = Array(1) { FloatArray(3) }; val outV2 = Array(1) { FloatArray(3) }
                v1.run(inV1, outV1); v2.run(inV2, outV2)
                val smV1 = softmax(outV1[0]); val smV2 = softmax(outV2[0])
                val combined = FloatArray(3) { i -> smV1[i] + smV2[i] }
                var label = 0; var best = Float.NEGATIVE_INFINITY
                combined.forEachIndexed { i, v -> if (v > best) { best = v; label = i } }
                val liveConf = (combined[LIVE_CLASS_IDX] / 2f).toDouble()
                android.util.Log.d(TAG,
                    "MiniFASNet frame $idx: label=$label liveConf=${"%.3f".format(liveConf)} " +
                    "v1=[${smV1.joinToString { "%.3f".format(it) }}] " +
                    "v2=[${smV2.joinToString { "%.3f".format(it) }}]")
                return Pair(label, if (label == LIVE_CLASS_IDX) liveConf else 0.0)
            } finally {
                if (!cropV1.isRecycled) cropV1.recycle()
                if (!cropV2.isRecycled) cropV2.recycle()
            }
        }

        fun close() {
            interpreterV1se?.close(); interpreterV1se = null
            interpreterV2?.close();   interpreterV2 = null
        }

        private fun faceBoxPixels(
            rois: Map<LivenessService.RoiZone, FloatArray>,
            imgW: Int, imgH: Int
        ): IntArray? {
            val l = rois[LivenessService.RoiZone.LEFT_CHEEK]  ?: return null
            val r = rois[LivenessService.RoiZone.RIGHT_CHEEK] ?: return null
            val f = rois[LivenessService.RoiZone.FOREHEAD]    ?: return null
            val p = rois[LivenessService.RoiZone.LIPS]        ?: return null

            val minX = min(l[0], r[0]); val maxX = max(l[0], r[0])
            val minY = min(f[1], p[1]); val maxY = max(f[1], p[1])

            val x = (minX * imgW).toInt().coerceIn(0, imgW - 1)
            val y = (minY * imgH).toInt().coerceIn(0, imgH - 1)
            val w = ((maxX - minX) * imgW).toInt().coerceAtLeast(1)
            val h = ((maxY - minY) * imgH).toInt().coerceAtLeast(1)

            android.util.Log.d(TAG,
                "faceBoxPixels: imgW=$imgW imgH=$imgH " +
                        "minX=${"%.3f".format(minX)} maxX=${"%.3f".format(maxX)} " +
                        "minY=${"%.3f".format(minY)} maxY=${"%.3f".format(maxY)} " +
                        "→ x=$x y=$y w=$w h=$h result=${if (w <= 1 || h <= 1) "NULL" else "OK"}")

            return if (w <= 1 || h <= 1) null else intArrayOf(x, y, w, h)
        }

        private fun cropWithScale(bitmap: Bitmap, bbox: IntArray, scale: Float?): Bitmap? {
            var bmp: Bitmap? = null
            val source = if (bitmap.config == Bitmap.Config.ARGB_8888) bitmap
            else bitmap.copy(Bitmap.Config.ARGB_8888, false)?.also { bmp = it } ?: return null
            return try {
                if (scale == null) {
                    Bitmap.createScaledBitmap(source, INPUT_SIZE, INPUT_SIZE, true)
                } else {
                    scaledCrop(source, bbox, scale)
                }
            } finally {
                if (bmp != null && bmp !== bitmap && !bmp.isRecycled) bmp.recycle()
            }
        }

        private fun scaledCrop(source: Bitmap, bbox: IntArray, scale: Float): Bitmap? {
            val srcW = source.width; val srcH = source.height
            val s = min((srcH - 1f) / bbox[3], min((srcW - 1f) / bbox[2], scale))
            val cx = bbox[2] / 2f + bbox[0]; val cy = bbox[3] / 2f + bbox[1]
            var ltX = cx - bbox[2] * s / 2f; var ltY = cy - bbox[3] * s / 2f
            var rbX = cx + bbox[2] * s / 2f; var rbY = cy + bbox[3] * s / 2f

            if (ltX < 0f) { rbX -= ltX; ltX = 0f }
            if (ltY < 0f) { rbY -= ltY; ltY = 0f }
            if (rbX > srcW - 1f) { ltX -= rbX - srcW + 1; rbX = srcW - 1f }
            if (rbY > srcH - 1f) { ltY -= rbY - srcH + 1; rbY = srcH - 1f }

            val x1 = ltX.toInt().coerceIn(0, srcW - 1)
            val y1 = ltY.toInt().coerceIn(0, srcH - 1)
            val x2 = rbX.toInt().coerceIn(0, srcW - 1)
            val y2 = rbY.toInt().coerceIn(0, srcH - 1)
            if (x2 <= x1 || y2 <= y1) return null

            val cropped = Bitmap.createBitmap(source, x1, y1, x2 - x1, y2 - y1)
            return Bitmap.createScaledBitmap(cropped, INPUT_SIZE, INPUT_SIZE, true).also {
                if (cropped !== it && !cropped.isRecycled) cropped.recycle()
            }
        }

        private fun preprocessNchw(bmp: Bitmap): ByteBuffer {
            val px = IntArray(INPUT_SIZE * INPUT_SIZE).also {
                bmp.getPixels(it, 0, INPUT_SIZE, 0, 0, INPUT_SIZE, INPUT_SIZE)
            }
            val buf = ByteBuffer.allocateDirect(1 * 3 * INPUT_SIZE * INPUT_SIZE * 4)
                .order(ByteOrder.nativeOrder())
            for (p in px) buf.putFloat(Color.blue(p).toFloat())
            for (p in px) buf.putFloat(Color.green(p).toFloat())
            for (p in px) buf.putFloat(Color.red(p).toFloat())
            return buf.apply { rewind() }
        }

        private fun preprocessNhwc(bmp: Bitmap): ByteBuffer {
            val px = IntArray(INPUT_SIZE * INPUT_SIZE).also {
                bmp.getPixels(it, 0, INPUT_SIZE, 0, 0, INPUT_SIZE, INPUT_SIZE)
            }
            val buf = ByteBuffer.allocateDirect(1 * INPUT_SIZE * INPUT_SIZE * 3 * 4)
                .order(ByteOrder.nativeOrder())
            for (p in px) {
                buf.putFloat(Color.blue(p).toFloat())
                buf.putFloat(Color.green(p).toFloat())
                buf.putFloat(Color.red(p).toFloat())
            }
            return buf.apply { rewind() }
        }

        private fun softmax(logits: FloatArray): FloatArray {
            val max = logits.max()
            val exps = FloatArray(logits.size) { exp((logits[it] - max).toDouble()).toFloat() }
            val sum = exps.sum().let { if (it > 1e-12f) it else 1e-12f }
            return FloatArray(logits.size) { exps[it] / sum }
        }

        private fun loadInterpreter(context: Context, file: String): Interpreter? = try {
            context.assets.openFd(file).use { afd ->
                FileInputStream(afd.fileDescriptor).use { fis ->
                    val buf = fis.channel.map(
                        FileChannel.MapMode.READ_ONLY, afd.startOffset, afd.declaredLength)
                    Interpreter(buf, Interpreter.Options().apply { setNumThreads(1) })
                }
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to load $file: ${e.message}", e)
            null
        }
    }

    private fun posAlgorithmWindowed(samples: List<FloatArray>, fps: Int): List<Double> {
        if (samples.isEmpty()) return emptyList()
        val n = samples.size
        val windowSize = (POS_WINDOW_SECONDS * fps).toInt().coerceIn(10, max(10, n))
        val out = DoubleArray(n); val count = IntArray(n)
        var sumR = 0.0; var sumG = 0.0; var sumB = 0.0

        for (end in samples.indices) {
            sumR += samples[end][0]; sumG += samples[end][1]; sumB += samples[end][2]
            val start = end - windowSize + 1
            if (start > 0) {
                sumR -= samples[start - 1][0]
                sumG -= samples[start - 1][1]
                sumB -= samples[start - 1][2]
            }
            val winStart = maxOf(0, start); val wLen = end - winStart + 1
            if (wLen < 2) continue
            val meanR = sumR / wLen; val meanG = sumG / wLen; val meanB = sumB / wLen
            if (meanR < 1e-6 || meanG < 1e-6 || meanB < 1e-6) continue

            val s1 = samples[end][1] / meanG - samples[end][2] / meanB
            val s2 = samples[end][1] / meanG + samples[end][2] / meanB - 2 * samples[end][0] / meanR
            val s1Arr = DoubleArray(wLen) { i -> samples[winStart + i].let { it[1] / meanG - it[2] / meanB } }
            val s2Arr = DoubleArray(wLen) { i -> samples[winStart + i].let { it[1] / meanG + it[2] / meanB - 2 * it[0] / meanR } }
            val alpha = calcStd(s1Arr) / (calcStd(s2Arr) + 1e-8)
            out[end] += s1 + alpha * s2; count[end]++
        }
        return out.indices.map { if (count[it] > 0) out[it] / count[it] else 0.0 }
    }

    private fun movingAverage(signal: List<Double>, window: Int): List<Double> {
        if (signal.isEmpty()) return emptyList()
        if (window <= 1) return signal
        val half = window / 2; val res = DoubleArray(signal.size)
        var sum = 0.0; var cnt = 0
        for (i in 0..min(half, signal.size - 1)) { sum += signal[i]; cnt++ }
        for (i in signal.indices) {
            val add = i + half
            if (add < signal.size && add > half) { sum += signal[add]; cnt++ }
            val rem = i - half - 1
            if (rem >= 0) { sum -= signal[rem]; cnt-- }
            res[i] = if (cnt > 0) sum / cnt else 0.0
        }
        return res.toList()
    }

    private fun bandpassFilter(signal: List<Double>, lowHz: Double, highHz: Double, fs: Double): List<Double> {
        if (signal.isEmpty()) return emptyList()
        val smoothed = movingAverage(signal, (fs / highHz).toInt().coerceAtLeast(1))
        val trend = movingAverage(smoothed, (fs / lowHz).toInt().coerceAtLeast(1))
        return smoothed.zip(trend) { s, t -> s - t }
    }

    private fun fft(signal: List<Double>): FftData {
        val n = nextPow2(max(1, signal.size))
        val re = DoubleArray(n) { if (it < signal.size) signal[it] else 0.0 }
        val im = DoubleArray(n)
        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j and bit != 0) { j = j xor bit; bit = bit shr 1 }
            j = j xor bit
            if (i < j) {
                val tR = re[i]; re[i] = re[j]; re[j] = tR
                val tI = im[i]; im[i] = im[j]; im[j] = tI
            }
        }
        var len = 2
        while (len <= n) {
            val half = len / 2; val wRe = cos(2 * PI / len); val wIm = -sin(2 * PI / len)
            var i = 0
            while (i < n) {
                var cRe = 1.0; var cIm = 0.0
                for (k in 0 until half) {
                    val uRe = re[i+k]; val uIm = im[i+k]
                    val vRe = re[i+k+half] * cRe - im[i+k+half] * cIm
                    val vIm = re[i+k+half] * cIm + im[i+k+half] * cRe
                    re[i+k] = uRe + vRe; im[i+k] = uIm + vIm
                    re[i+k+half] = uRe - vRe; im[i+k+half] = uIm - vIm
                    val nRe = cRe * wRe - cIm * wIm; cIm = cRe * wIm + cIm * wRe; cRe = nRe
                }
                i += len
            }
            len = len shl 1
        }
        return FftData(re, im)
    }

    private fun nextPow2(n: Int): Int { var p = 1; while (p < n) p = p shl 1; return p }

    private fun calculateSnrFromFft(fft: FftData, fs: Double): Double {
        val n = fft.re.size; val half = n / 2
        var sig = 0.0; var total = 0.0
        for (k in 0 until half) {
            val freq = k * fs / n
            val power = (fft.re[k].pow(2) + fft.im[k].pow(2)) / n
            total += power; if (freq in 0.7..4.0) sig += power
        }
        val noise = total - sig
        return if (noise > 0) sig / noise else 0.0
    }

    private fun checkHarmonicStructureFromFft(fft: FftData, fs: Double): Boolean {
        val n = fft.re.size; val half = n / 2
        val freqs = DoubleArray(half) { k -> k * fs / n }
        val power = DoubleArray(half) { k -> (fft.re[k].pow(2) + fft.im[k].pow(2)) / n }
        var f0Idx = -1; var f0Power = 0.0
        freqs.indices.forEach { k -> if (freqs[k] in 0.7..4.0 && power[k] > f0Power) { f0Power = power[k]; f0Idx = k } }
        if (f0Idx < 0) return false
        val h2Target = freqs[f0Idx] * 2.0
        val h2Idx = freqs.indices.minByOrNull { abs(freqs[it] - h2Target) } ?: return false
        val h2Power = if (freqs[h2Idx] in h2Target * 0.9..h2Target * 1.1) power[h2Idx] else 0.0
        val harmRatio = if (f0Power > 0) h2Power / f0Power else 1.0
        val excl = setOf(f0Idx-1, f0Idx, f0Idx+1, h2Idx-1, h2Idx, h2Idx+1)
        val noiseFloor = freqs.indices.filter { freqs[it] in 0.7..4.0 && it !in excl }
            .map { power[it] }.average().takeIf { it.isFinite() } ?: 0.0
        val fundRatio = if (noiseFloor > 0) f0Power / noiseFloor else 0.0
        android.util.Log.d(TAG, "Harmonics: ratio=${"%.3f".format(harmRatio)} fundamental=${"%.2f".format(fundRatio)}")
        return harmRatio < MAX_HARMONIC_RATIO && fundRatio >= MIN_FUNDAMENTAL
    }

    private fun estimateHeartRate(signal: List<Double>, fps: Int): Double? {
        if (signal.size < 3) return null
        val peaks = findPeaks(signal, (fps * 0.4).toInt().coerceAtLeast(1))
        if (peaks.size < 2) return null
        val valid = (1 until peaks.size)
            .map { (peaks[it] - peaks[it-1]) / fps.toDouble() }
            .filter { it in 0.4..1.5 }
        return if (valid.isEmpty()) null else 60.0 / valid.average()
    }

    private fun findPeaks(signal: List<Double>, minDist: Int): List<Int> {
        val peaks = mutableListOf<Int>()
        for (i in 1 until signal.size - 1) {
            if (signal[i] > signal[i-1] && signal[i] > signal[i+1]) {
                if (peaks.isEmpty() || i - peaks.last() >= minDist) peaks.add(i)
                else if (signal[i] > signal[peaks.last()]) peaks[peaks.lastIndex] = i
            }
        }
        return peaks
    }

    private fun calcStd(arr: DoubleArray): Double {
        if (arr.isEmpty()) return 0.0
        val mean = arr.average()
        return sqrt(arr.fold(0.0) { acc, v -> acc + (v - mean).pow(2) } / arr.size)
    }
}