package foundation.privacybydesign.vcmrtd.biometrics

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.util.Log
import android.os.SystemClock
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.CancellationException

class PassiveLivenessService(
    private val context: Context,
    private val livenessService: LivenessService
) {
    companion object {
        private const val TAG = "PassiveLivenessService"
        private const val VALID_HR_MIN   = 45.0
        private const val VALID_HR_MAX   = 110.0
        const val ANTISPOOF_MIN_SCORE    = 0.65

        private const val ANTISPOOF_SAMPLE_RATE = 0.70f
        private const val ANTISPOOF_MAX_YAW_DEG = 20f
        private const val MIN_ANTISPOOF_SAMPLES = 4
        private const val RPPG_FRONTAL_MAX_YAW  = 15f
        private const val RPPG_MAX_GAP_MS       = 1000L
        private const val RPPG_MIN_DURATION_MS  = 2000L
        private const val MIN_BVP_SAMPLES       = 15
        private const val BIGSMALL_CHANNEL_CAPACITY = 3
    }

    data class RppgResult(
        val hr: Double?,
        val passed: Boolean,
        val sampleCount: Int = 0,
        val durationMs: Long = 0L
    )

    private val antiSpoofScores  = mutableListOf<Double?>()
    private var antiSpoofAttempts = 0
    private var totalFrames       = 0

    // rPPG: buffer of face crops waiting to be inferred, plus accumulated BVP output
    private data class RppgFrame(
        val appearance: Bitmap,
        val motion: Bitmap,
        val timestampMs: Long
    )
    private val rppgFrameBuffer  = ArrayDeque<RppgFrame>() // (appearance 144x144, motion 9x9)
    private var lastFrameBufferedMs = 0L   // timestamp of the last frame added to rppgFrameBuffer
    private val bvpSamples       = ArrayDeque<Float>()
    private val bvpSampleTimes   = ArrayDeque<Long>()
    private var rppgSessionId = 0
    private var pendingBigSmallBatches = 0

    private data class BigSmallBatch(
        val sessionId: Int,
        val frames: List<RppgFrame>
    )

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val bigSmallChannel = Channel<BigSmallBatch>(capacity = BIGSMALL_CHANNEL_CAPACITY)
    private var bigSmallJob: Job? = null

    private val metricsLock = Any()


    fun initialize() {
        MiniFASNetService.initialize(context)
        BigSmallService.initialize(context)
        startBigSmallLoop()
    }

    fun scoreFrame(bitmap: Bitmap, rois: Map<LivenessService.RoiZone, FloatArray>): Double? =
        MiniFASNetService.score(bitmap, rois)

    private fun isAntiSpoofPassed(scores: List<Double?>): Boolean {
        val valid = scores.filterNotNull()
        if (valid.isEmpty()) return false
        if (valid.size < MIN_ANTISPOOF_SAMPLES) return false
        val avg = valid.average()
        return avg >= ANTISPOOF_MIN_SCORE
    }

fun close() {
    bigSmallJob?.cancel()
    bigSmallJob = null

    var pending = bigSmallChannel.tryReceive()
    while (pending.isSuccess) {
        pending.getOrNull()?.frames?.forEach { frame ->
            if (!frame.appearance.isRecycled) frame.appearance.recycle()
            if (!frame.motion.isRecycled) frame.motion.recycle()
        }
        markBigSmallBatchDone()
        pending = bigSmallChannel.tryReceive()
    }

    scope.cancel()

    MiniFASNetService.close()
    BigSmallService.close()
    clearRppgBuffer()
}

    // ═══════════════════════════════════════════
    //  Per-session state
    // ═══════════════════════════════════════════

    fun reset() {
        synchronized(metricsLock) {
            antiSpoofScores.clear()
            antiSpoofAttempts = 0
            totalFrames = 0
            rppgSessionId++
            clearRppgBuffer()
        }

        var pending = bigSmallChannel.tryReceive()
        while (pending.isSuccess) {
            pending.getOrNull()?.frames?.forEach { frame ->
                if (!frame.appearance.isRecycled) frame.appearance.recycle()
                if (!frame.motion.isRecycled) frame.motion.recycle()
            }
            markBigSmallBatchDone()
            pending = bigSmallChannel.tryReceive()
        }
    }

    fun getAntiSpoofScore(): Double? = synchronized(metricsLock) {
        val valid = antiSpoofScores.filterNotNull()
        if (valid.isEmpty()) null else valid.average()
    }

    fun isAntiSpoofPassed(): Boolean = synchronized(metricsLock) {
        isAntiSpoofPassed(antiSpoofScores)
    }

    fun getAntiSpoofAttempts(): Int = synchronized(metricsLock) {
        antiSpoofAttempts
    }

    fun getTotalFrames(): Int = synchronized(metricsLock) {
        totalFrames
    }

    suspend fun awaitRppgIdle() {
        while (true) {
            val idle = synchronized(metricsLock) { pendingBigSmallBatches == 0 }
            if (idle) return
            delay(25)
        }
    }

    fun collectPassiveMetrics(bitmap: Bitmap, result: FaceLandmarkerResult) {
        synchronized(metricsLock) { totalFrames++ }
        val yaw = livenessService.matrixYaw(result)
        sampleAntiSpoof(bitmap, result, yaw)
        try {
            sampleRppg(bitmap, result, yaw)
        } catch (e: Exception) {
            Log.w(TAG, "rPPG sampling failed", e)
        }
    }

    private fun sampleAntiSpoof(bitmap: Bitmap, result: FaceLandmarkerResult, yaw: Float?) {
        if (Random.nextFloat() >= ANTISPOOF_SAMPLE_RATE) return
        synchronized(metricsLock) { antiSpoofAttempts++ }
        val isFrontal = yaw == null || abs(yaw) < ANTISPOOF_MAX_YAW_DEG
        if (!isFrontal) return
        val rois = livenessService.extractRois(result) ?: return
        val score = scoreFrame(bitmap, rois)
        synchronized(metricsLock) { antiSpoofScores.add(score) }
    }

    private fun sampleRppg(bitmap: Bitmap, result: FaceLandmarkerResult, yaw: Float?) {
        if (yaw != null && abs(yaw) > RPPG_FRONTAL_MAX_YAW) return

        val rois = livenessService.extractRois(result) ?: return
        val now  = SystemClock.elapsedRealtime()

        val crops = cropFaceForBigSmall(bitmap, rois) ?: return

        var batchToSend: List<RppgFrame>? = null
        var batchSessionId = 0

        synchronized(metricsLock) {
            if (rppgFrameBuffer.isNotEmpty() && now - lastFrameBufferedMs > RPPG_MAX_GAP_MS) {
                discardFrameBuffer()
            }

            rppgFrameBuffer.addLast(
                RppgFrame(
                    appearance = crops.first,
                    motion = crops.second,
                    timestampMs = now
                )
            )
            lastFrameBufferedMs = now

            if (rppgFrameBuffer.size >= BigSmallService.BUFFER_FRAMES) {
                batchToSend = rppgFrameBuffer.toList()
                rppgFrameBuffer.clear()
                batchSessionId = rppgSessionId
                pendingBigSmallBatches++
            }
        }

        val batch = batchToSend ?: return

        val sent = bigSmallChannel.trySend(BigSmallBatch(batchSessionId, batch)).isSuccess
        if (!sent) {
            batch.forEach { frame ->
                if (!frame.appearance.isRecycled) frame.appearance.recycle()
                if (!frame.motion.isRecycled) frame.motion.recycle()
            }
            markBigSmallBatchDone()
        }
    }

    private fun markBigSmallBatchDone() {
        synchronized(metricsLock) {
            if (pendingBigSmallBatches > 0) pendingBigSmallBatches--
        }
    }

    private fun discardFrameBuffer() {
        rppgFrameBuffer.forEach { frame ->
            if (!frame.appearance.isRecycled) frame.appearance.recycle()
            if (!frame.motion.isRecycled) frame.motion.recycle()
        }
        rppgFrameBuffer.clear()
        lastFrameBufferedMs = 0L
    }

    private fun clearRppgBuffer() {
        discardFrameBuffer()
        bvpSamples.clear()
        bvpSampleTimes.clear()
    }

    private fun cropFaceForBigSmall(
        bitmap: Bitmap,
        rois: Map<LivenessService.RoiZone, FloatArray>
    ): Pair<Bitmap, Bitmap>? {
        val l = rois[LivenessService.RoiZone.LEFT_CHEEK]  ?: return null
        val r = rois[LivenessService.RoiZone.RIGHT_CHEEK] ?: return null
        val f = rois[LivenessService.RoiZone.FOREHEAD]    ?: return null
        val p = rois[LivenessService.RoiZone.LIPS]        ?: return null

        val imgW = bitmap.width; val imgH = bitmap.height
        val x1 = ((min(l[0], r[0]) - l[2]) * imgW).toInt().coerceIn(0, imgW - 1)
        val x2 = ((max(l[0], r[0]) + r[2]) * imgW).toInt().coerceIn(0, imgW - 1)
        val y1 = ((f[1] - f[2]) * imgH).toInt().coerceIn(0, imgH - 1)
        val y2 = ((p[1] + p[2]) * imgH).toInt().coerceIn(0, imgH - 1)

        if (x2 <= x1 || y2 <= y1) return null

        val cropped = Bitmap.createBitmap(bitmap, x1, y1, x2 - x1, y2 - y1)
        return try {
            val appearance = Bitmap.createScaledBitmap(cropped, BigSmallService.APPEARANCE_SIZE, BigSmallService.APPEARANCE_SIZE, true)
            val motion     = Bitmap.createScaledBitmap(cropped, BigSmallService.MOTION_SIZE,     BigSmallService.MOTION_SIZE,     true)
            Pair(appearance, motion)
        } finally {
            if (!cropped.isRecycled) cropped.recycle()
        }
    }

    fun getRppgResult(): RppgResult? {
        val samples: List<Float>
        val times: List<Long>

        synchronized(metricsLock) {
            if (bvpSamples.size < MIN_BVP_SAMPLES || bvpSampleTimes.size < 2) return null
            samples = bvpSamples.toList()
            times = bvpSampleTimes.toList()
        }

        val durationMs = (times.last() - times.first()).coerceAtLeast(1L)
        if (durationMs < RPPG_MIN_DURATION_MS) return null

        val fps = (((samples.size - 1) * 1000) / durationMs).coerceAtLeast(1).toInt()
        return evaluateBvp(samples, fps)
    }

    fun evaluateBvp(samples: List<Float>, fps: Int): RppgResult {
        if (samples.isEmpty() || fps <= 0) return RppgResult(null, false)
        val signal  = samples.map { it.toDouble() }
        val hr      = estimateHeartRate(signal, fps)
        val validHr = hr != null && hr in VALID_HR_MIN..VALID_HR_MAX
        val durationMs = if (fps > 0) (((samples.size - 1) * 1000) / fps).toLong() else 0L
        return RppgResult(hr, validHr, samples.size, durationMs)
    }

    private fun processBigSmallBatch(batch: BigSmallBatch) {
        val bvp = BigSmallService.runInference(batch.frames) ?: return
        synchronized(metricsLock) {
            if (batch.sessionId != rppgSessionId) return@synchronized
            val sampleCount = min(bvp.size, batch.frames.size - 1)
            for (i in 0 until sampleCount) {
                bvpSamples.addLast(bvp[i])
                val t0 = batch.frames[i].timestampMs
                val t1 = batch.frames[i + 1].timestampMs
                bvpSampleTimes.addLast(t0 + (t1 - t0) / 2L)
            }
            while (bvpSamples.size > 900) {
                bvpSamples.removeFirst()
                bvpSampleTimes.removeFirst()
            }
        }
    }

    private fun startBigSmallLoop() {
        if (bigSmallJob != null) return

        bigSmallJob = scope.launch {
            while (isActive) {
                val batch = try {
                    bigSmallChannel.receive()
                } catch (_: CancellationException) {
                    break
                }

                try {
                    processBigSmallBatch(batch)
                } catch (e: Exception) {
                    Log.w(TAG, "BigSmall inference failed", e)
                } finally {
                    batch.frames.forEach { frame ->
                        if (!frame.appearance.isRecycled) frame.appearance.recycle()
                        if (!frame.motion.isRecycled) frame.motion.recycle()
                    }
                    markBigSmallBatchDone()
                }
            }
        }
    }

    // ═══════════════════════════════════════════
    //  MiniFASNet anti-spoof service
    // ═══════════════════════════════════════════

    private object MiniFASNetService {
        private const val INPUT_SIZE     = 80
        private const val LIVE_CLASS_IDX = 1
        private const val SCALE_V2       = 2.7f
        private const val MINIFASNET_V1SE = "minifasnet_v1se.tflite"
        private const val MINIFASNET_V2   = "minifasnet_v2.tflite"

        private var interpreterV1se: Interpreter? = null
        private var interpreterV2: Interpreter?   = null

        private var isNchwV1 = false
        private var isNchwV2 = false

        private val inputBufV1   = ByteBuffer.allocateDirect(3 * INPUT_SIZE * INPUT_SIZE * 4).order(ByteOrder.nativeOrder())
        private val inputBufV2   = ByteBuffer.allocateDirect(3 * INPUT_SIZE * INPUT_SIZE * 4).order(ByteOrder.nativeOrder())
        private val pixelScratch = IntArray(INPUT_SIZE * INPUT_SIZE)
        private val outV1Scratch = Array(1) { FloatArray(3) }
        private val outV2Scratch = Array(1) { FloatArray(3) }

        fun initialize(context: Context) {
            if (interpreterV1se == null) {
                interpreterV1se = loadInterpreter(context, MINIFASNET_V1SE)
                isNchwV1 = interpreterV1se?.getInputTensor(0)?.shape()?.let { it.size == 4 && it[1] == 3 } ?: false
            }
            if (interpreterV2 == null) {
                interpreterV2 = loadInterpreter(context, MINIFASNET_V2)
                isNchwV2 = interpreterV2?.getInputTensor(0)?.shape()?.let { it.size == 4 && it[1] == 3 } ?: false
            }
        }

        fun score(frame: Bitmap, rois: Map<LivenessService.RoiZone, FloatArray>): Double? {
            val v1 = interpreterV1se ?: return null
            val v2 = interpreterV2   ?: return null

            val cropV1 = cropWithScale(frame, intArrayOf(0, 0, frame.width, frame.height), null)
                ?: return null
            val bbox = faceBoxPixels(rois, frame.width, frame.height) ?: run {
                if (!cropV1.isRecycled) cropV1.recycle(); return null
            }
            val cropV2 = cropWithScale(frame, bbox, SCALE_V2) ?: run {
                if (!cropV1.isRecycled) cropV1.recycle(); return null
            }
            try {
                val inV1 = if (isNchwV1) preprocessNchw(cropV1, inputBufV1) else preprocessNhwc(cropV1, inputBufV1)
                val inV2 = if (isNchwV2) preprocessNchw(cropV2, inputBufV2) else preprocessNhwc(cropV2, inputBufV2)
                v1.run(inV1, outV1Scratch); v2.run(inV2, outV2Scratch)
                val smV1 = softmax(outV1Scratch[0]); val smV2 = softmax(outV2Scratch[0])
                val combined = FloatArray(3) { i -> smV1[i] + smV2[i] }
                var label = 0; var best = Float.NEGATIVE_INFINITY
                combined.forEachIndexed { i, v -> if (v > best) { best = v; label = i } }
                val liveConf = (combined[LIVE_CLASS_IDX] / 2f).toDouble()
                return if (label == LIVE_CLASS_IDX) liveConf else 0.0
            } finally {
                if (!cropV1.isRecycled) cropV1.recycle()
                if (!cropV2.isRecycled) cropV2.recycle()
            }
        }

        fun close() {
            interpreterV1se?.close(); interpreterV1se = null
            interpreterV2?.close();   interpreterV2   = null
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

            return if (w <= 1 || h <= 1) null else intArrayOf(x, y, w, h)
        }

        private fun cropWithScale(bitmap: Bitmap, bbox: IntArray, scale: Float?): Bitmap? {
            var bmp: Bitmap? = null
            val source = if (bitmap.config == Bitmap.Config.ARGB_8888) bitmap
            else bitmap.copy(Bitmap.Config.ARGB_8888, false)?.also { bmp = it } ?: return null
            return try {
                if (scale == null) Bitmap.createScaledBitmap(source, INPUT_SIZE, INPUT_SIZE, true)
                else scaledCrop(source, bbox, scale)
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

        private fun preprocessNchw(bmp: Bitmap, buf: ByteBuffer): ByteBuffer {
            bmp.getPixels(pixelScratch, 0, INPUT_SIZE, 0, 0, INPUT_SIZE, INPUT_SIZE)
            buf.clear()
            for (p in pixelScratch) buf.putFloat(Color.blue(p).toFloat())
            for (p in pixelScratch) buf.putFloat(Color.green(p).toFloat())
            for (p in pixelScratch) buf.putFloat(Color.red(p).toFloat())
            return buf.apply { rewind() }
        }

        private fun preprocessNhwc(bmp: Bitmap, buf: ByteBuffer): ByteBuffer {
            bmp.getPixels(pixelScratch, 0, INPUT_SIZE, 0, 0, INPUT_SIZE, INPUT_SIZE)
            buf.clear()
            for (p in pixelScratch) {
                buf.putFloat(Color.blue(p).toFloat())
                buf.putFloat(Color.green(p).toFloat())
                buf.putFloat(Color.red(p).toFloat())
            }
            return buf.apply { rewind() }
        }

        private fun softmax(logits: FloatArray): FloatArray {
            val max  = logits.max()
            val exps = FloatArray(logits.size) { exp((logits[it] - max).toDouble()).toFloat() }
            val sum  = exps.sum().let { if (it > 1e-12f) it else 1e-12f }
            return FloatArray(logits.size) { exps[it] / sum }
        }

        private fun loadInterpreter(context: Context, file: String): Interpreter? = try {
            context.assets.openFd(file).use { afd ->
                FileInputStream(afd.fileDescriptor).use { fis ->
                    val buf = fis.channel.map(FileChannel.MapMode.READ_ONLY, afd.startOffset, afd.declaredLength)
                    Interpreter(buf, Interpreter.Options().apply { setNumThreads(1) })
                }
            }
        } catch (e: Exception) { Log.e(TAG, "Failed to load $file", e); null }
    }

    // ═══════════════════════════════════════════
    //  BigSmall rPPG service
    // ═══════════════════════════════════════════

    private object BigSmallService {
        private val MODEL_FILES    = listOf("bigsmall_1.tflite", "bigsmall_2.tflite", "bigsmall_3.tflite")
        const val FRAMES           = 3
        const val BUFFER_FRAMES    = FRAMES + 1  // 4 frames → 3 appearance frames + 3 DiffNorm motion pairs
        const val APPEARANCE_SIZE  = 144
        const val MOTION_SIZE      = 9

        private val interpreters = arrayOfNulls<Interpreter>(MODEL_FILES.size)

        private val appearanceBuf   = ByteBuffer
            .allocateDirect(FRAMES * 3 * APPEARANCE_SIZE * APPEARANCE_SIZE * 4)
            .order(ByteOrder.nativeOrder())
        private val motionBuf       = ByteBuffer
            .allocateDirect(FRAMES * 3 * MOTION_SIZE * MOTION_SIZE * 4)
            .order(ByteOrder.nativeOrder())
        private val pixelScratch    = IntArray(APPEARANCE_SIZE * APPEARANCE_SIZE)
        private val pixelScratchSm  = IntArray(MOTION_SIZE * MOTION_SIZE)  // frame t
        private val pixelScratchSm1 = IntArray(MOTION_SIZE * MOTION_SIZE)  // frame t+1
        private val outputScratches = Array(MODEL_FILES.size) { Array(FRAMES) { FloatArray(1) } }

        fun initialize(context: Context) {
            MODEL_FILES.forEachIndexed { i, file ->
                if (interpreters[i] == null) interpreters[i] = loadInterpreter(context, file)
            }
        }

        private fun fillAppearanceBuf(frames: List<RppgFrame>) {
            appearanceBuf.clear()
            for (fi in 1..FRAMES) {
                frames[fi].appearance.getPixels(pixelScratch, 0, APPEARANCE_SIZE, 0, 0, APPEARANCE_SIZE, APPEARANCE_SIZE)
                for (px in pixelScratch) appearanceBuf.putFloat(Color.red(px)   / 255f)
                for (px in pixelScratch) appearanceBuf.putFloat(Color.green(px) / 255f)
                for (px in pixelScratch) appearanceBuf.putFloat(Color.blue(px)  / 255f)
            }
        }

        private fun fillMotionBuf(frames: List<RppgFrame>) {
            motionBuf.clear()
            val eps = 1e-7f
            for (fi in 0 until FRAMES) {
                frames[fi].motion.getPixels(pixelScratchSm,  0, MOTION_SIZE, 0, 0, MOTION_SIZE, MOTION_SIZE)
                frames[fi + 1].motion.getPixels(pixelScratchSm1, 0, MOTION_SIZE, 0, 0, MOTION_SIZE, MOTION_SIZE)
                for (k in pixelScratchSm.indices) {
                    val curr = Color.red(pixelScratchSm[k]).toFloat()
                    val next = Color.red(pixelScratchSm1[k]).toFloat()
                    motionBuf.putFloat((next - curr) / (next + curr + eps))
                }
                for (k in pixelScratchSm.indices) {
                    val curr = Color.green(pixelScratchSm[k]).toFloat()
                    val next = Color.green(pixelScratchSm1[k]).toFloat()
                    motionBuf.putFloat((next - curr) / (next + curr + eps))
                }
                for (k in pixelScratchSm.indices) {
                    val curr = Color.blue(pixelScratchSm[k]).toFloat()
                    val next = Color.blue(pixelScratchSm1[k]).toFloat()
                    motionBuf.putFloat((next - curr) / (next + curr + eps))
                }
            }
        }

        fun runInference(frames: List<RppgFrame>): FloatArray? {
            if (frames.size != BUFFER_FRAMES) return null
            if (interpreters.none { it != null }) return null

            fillAppearanceBuf(frames)
            fillMotionBuf(frames)
            val inputs = arrayOf<Any>(appearanceBuf, motionBuf)

            val sum = FloatArray(FRAMES)
            var count = 0
            interpreters.forEachIndexed { i, interp ->
                if (interp == null) return@forEachIndexed
                appearanceBuf.rewind(); motionBuf.rewind()
                try {
                    val outputs = hashMapOf<Int, Any>(0 to outputScratches[i])
                    interp.runForMultipleInputsOutputs(inputs, outputs)
                    for (f in 0 until FRAMES) sum[f] += outputScratches[i][f][0]
                    count++
                } catch (e: Exception) { Log.w(TAG, "Model ${MODEL_FILES[i]} inference failed", e); return@forEachIndexed }
            }
            if (count == 0) return null
            return FloatArray(FRAMES) { sum[it] / count }
        }

        fun close() { interpreters.forEachIndexed { i, it -> it?.close(); interpreters[i] = null } }

        private fun loadInterpreter(context: Context, file: String): Interpreter? = try {
            context.assets.openFd(file).use { afd ->
                FileInputStream(afd.fileDescriptor).use { fis ->
                    val buf = fis.channel.map(FileChannel.MapMode.READ_ONLY, afd.startOffset, afd.declaredLength)
                    Interpreter(buf, Interpreter.Options().apply { setNumThreads(2) })
                }
            }
        } catch (e: Exception) { Log.e(TAG, "Failed to load $file", e); null }
    }

    // ═══════════════════════════════════════════
    //  Signal analysis (HR estimation on BVP output)
    // ═══════════════════════════════════════════

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
}
