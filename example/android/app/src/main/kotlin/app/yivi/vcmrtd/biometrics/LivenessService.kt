package foundation.privacybydesign.vcmrtd.biometrics

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.components.containers.Category
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs
import kotlin.math.asin

/**
 * Synchronous MediaPipe face landmark detector (IMAGE mode).
 *
 * Each [detectImage] call blocks until MediaPipe completes and returns
 * the result directly. No frame drops, no race conditions.
 *
 * GPU gets used first. If it fails, we switch to CPU and retry the detection once.
 *
 * Threading: not thread-safe. Call [detectImage] from a single thread at a time.
 */
class LivenessService(private val context: Context) {

    internal var faceLandmarker: FaceLandmarker? = null

    companion object {
        internal const val TAG = "LivenessService"
        internal const val MODEL_FILE = "face_landmarker.task"
        internal const val ROI_FRACTION = 0.15f
    }

    enum class RoiZone { FOREHEAD, LEFT_CHEEK, RIGHT_CHEEK, NOSE, LIPS }

    @Volatile private var latestResult: FaceLandmarkerResult? = null
    @Volatile private var usingGpu = false
    private val switchingToCpu = AtomicBoolean(false)

    fun initialize() {
        if (faceLandmarker != null) return
        android.util.Log.d(TAG, "Initializing LivenessService (IMAGE mode)")

        try {
            faceLandmarker = createFaceLandmarker(Delegate.GPU)
            usingGpu = true
            android.util.Log.d(TAG, "Initialized with GPU")
        } catch (e: Exception) {
            android.util.Log.w(TAG, "GPU init failed, falling back to CPU", e)
            faceLandmarker = createFaceLandmarker(Delegate.CPU)
            usingGpu = false
            android.util.Log.d(TAG, "Initialized with CPU")
        }
    }

    private fun createFaceLandmarker(delegate: Delegate): FaceLandmarker {
        val baseOpts = BaseOptions.builder()
            .setModelAssetPath(MODEL_FILE)
            .setDelegate(delegate)
            .build()

        val opts = FaceLandmarker.FaceLandmarkerOptions.builder()
            .setBaseOptions(baseOpts)
            .setMinFaceDetectionConfidence(0.5f)
            .setMinFacePresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .setNumFaces(1)
            .setOutputFaceBlendshapes(true)
            .setOutputFacialTransformationMatrixes(true)
            .setRunningMode(RunningMode.IMAGE)
            .build()

        return FaceLandmarker.createFromOptions(context, opts)
    }

    /**
     * Synchronous detection — blocks until MediaPipe completes.
     * Returns null if no face is found.
     */
    fun detectImage(bitmap: Bitmap): FaceLandmarkerResult? {
        // Local reference so switchToCpu() can swap out faceLandmarker concurrently
        // without crashing this call.
        val lm = faceLandmarker ?: return null
        val mpImg = BitmapImageBuilder(bitmap).build()

        return try {
            val r = lm.detect(mpImg)
            latestResult = r
            if (r.faceLandmarks().isEmpty()) null else r
        } catch (e: Exception) {
            if (usingGpu && switchToCpu()) {
                try {
                    val cpuLm = faceLandmarker ?: return null
                    val r = cpuLm.detect(mpImg)
                    latestResult = r
                    if (r.faceLandmarks().isNotEmpty()) r else null
                } catch (e2: Exception) {
                    android.util.Log.e(TAG, "CPU retry failed", e2)
                    null
                }
            } else {
                android.util.Log.e(TAG, "detect failed", e)
                null
            }
        }
    }

    fun getBlendshapeScore(name: String, result: FaceLandmarkerResult): Float? {
        val lists = result.faceBlendshapes()
        if (!lists.isPresent) return null
        val face = lists.get().firstOrNull() ?: return null
        return face.firstOrNull { it.categoryName() == name }?.score()
    }

    /**
     * Detects face and computes ROI zones in a single MediaPipe call.
     * Use [extractRois] instead when a result is already available.
     */
    fun detectRois(bitmap: Bitmap): Map<RoiZone, FloatArray>? {
        val result = detectImage(bitmap) ?: return null
        return extractRois(result)
    }

    /**
     * Computes ROI zones from an already-existing FaceLandmarkerResult.
     * Use this during active liveness to avoid a redundant MediaPipe call —
     * the result is already available from [detectImage].
     */
    fun extractRois(result: FaceLandmarkerResult): Map<RoiZone, FloatArray>? {
        if (result.faceLandmarks().isEmpty()) return null
        val lm = result.faceLandmarks()[0]
        val fw = abs(lm[338].x() - lm[109].x())
        val s = fw * ROI_FRACTION

        return mapOf(
            RoiZone.FOREHEAD    to floatArrayOf(lm[10].x(), lm[10].y() - s * 0.3f, s),
            RoiZone.RIGHT_CHEEK to floatArrayOf(lm[205].x(), lm[205].y(), s),
            RoiZone.LEFT_CHEEK  to floatArrayOf(lm[425].x(), lm[425].y(), s),
            RoiZone.NOSE        to floatArrayOf(lm[4].x(), lm[4].y(), s * 0.8f),
            RoiZone.LIPS        to floatArrayOf(
                (lm[0].x() + lm[17].x()) / 2f,
                (lm[0].y() + lm[17].y()) / 2f, s
            ),
        )
    }

    fun extractRgbFromRoi(bitmap: Bitmap, roi: FloatArray): FloatArray? {
        val w = bitmap.width; val h = bitmap.height
        val cx = (roi[0] * w).toInt(); val cy = (roi[1] * h).toInt()
        val half = ((roi[2] * w) / 2).toInt().coerceAtLeast(5)
        val x1 = (cx - half).coerceIn(0, w - 1)
        val y1 = (cy - half).coerceIn(0, h - 1)
        val x2 = (cx + half).coerceIn(0, w - 1)
        val y2 = (cy + half).coerceIn(0, h - 1)
        if (x2 <= x1 || y2 <= y1) return null

        val rw = x2 - x1; val rh = y2 - y1
        val px = IntArray(rw * rh)
        bitmap.getPixels(px, 0, rw, x1, y1, rw, rh)

        var sR = 0L; var sG = 0L; var sB = 0L
        for (p in px) { sR += Color.red(p); sG += Color.green(p); sB += Color.blue(p) }
        val n = px.size.toFloat()
        return floatArrayOf(sR / n, sG / n, sB / n)
    }

    /**
     * Extracts the yaw angle (degrees) from the facial transformation matrix.
     * Positive = turned right, negative = turned left.
     * Returns null if no transformation matrix is present in the result.
     */
    fun matrixYaw(result: FaceLandmarkerResult): Float? {
        val opt = result.facialTransformationMatrixes()
        if (opt == null || !opt.isPresent) return null
        val mats = opt.get(); if (mats.isEmpty()) return null
        val m = mats[0]; if (m.size < 3) return null
        return Math.toDegrees(asin(-m[2].toDouble().coerceIn(-1.0, 1.0))).toFloat()
    }

    fun resetLiveState() { latestResult = null }

    fun close() {
        try { faceLandmarker?.close() } catch (e: Exception) { android.util.Log.w(TAG, "close: faceLandmarker close failed", e) }
        faceLandmarker = null; usingGpu = false; resetLiveState()
    }

    private fun switchToCpu(): Boolean {
        if (!switchingToCpu.compareAndSet(false, true)) return false
        return try {
            try { faceLandmarker?.close() } catch (e: Exception) { android.util.Log.w(TAG, "switchToCpu: close failed", e) }
            faceLandmarker = createFaceLandmarker(Delegate.CPU)
            usingGpu = false; resetLiveState()
            android.util.Log.w(TAG, "Switched to CPU after GPU failure")
            true
        } catch (e: Exception) {
            android.util.Log.e(TAG, "CPU switch failed", e)
            false
        } finally { switchingToCpu.set(false) }
    }
}

internal fun Bitmap.toArgb8888(): Bitmap =
    if (config == Bitmap.Config.ARGB_8888) this else copy(Bitmap.Config.ARGB_8888, false)