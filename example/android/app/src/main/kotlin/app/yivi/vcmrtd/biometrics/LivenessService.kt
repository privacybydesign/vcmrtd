package foundation.privacybydesign.vcmrtd.biometrics

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import kotlin.math.abs
import kotlin.math.asin

/**
 * Synchronous face landmark detector backed by [FaceLandmarkPipeline] (TFLite direct).
 *
 * Drop-in replacement for the previous MediaPipe-based implementation.
 * Public API is unchanged: initialize / detectImage / getBlendshapeScore /
 * extractRois / extractRgbFromRoi / matrixYaw / close.
 */
class LivenessService(private val context: Context) {

    internal var pipeline: FaceLandmarkPipeline? = null

    companion object {
        internal const val ROI_FRACTION = 0.15f
    }

    enum class RoiZone { FOREHEAD, LEFT_CHEEK, RIGHT_CHEEK, NOSE, LIPS }

    fun initialize() {
        if (pipeline != null) return
        pipeline = FaceLandmarkPipeline(context).also { it.initialize() }
    }

    fun detectImage(bitmap: Bitmap, runBlendshapes: Boolean = true): FaceLandmarkerResult? {
        val p = pipeline ?: return null
        val argb = bitmap.toArgb8888()
        return try {
            p.detect(argb, runBlendshapes)
        } finally {
            if (argb !== bitmap && !argb.isRecycled) argb.recycle()
        }
    }

    fun getBlendshapeScore(name: String, result: FaceLandmarkerResult): Float? {
        val lists = result.faceBlendshapes()
        if (!lists.isPresent) return null
        val face = lists.get().firstOrNull() ?: return null
        return face.firstOrNull { it.categoryName() == name }?.score()
    }

    fun extractRois(result: FaceLandmarkerResult): Map<RoiZone, FloatArray>? {
        if (result.faceLandmarks().isEmpty()) return null
        val lm = result.faceLandmarks()[0]
        val fw = abs(lm[338].x() - lm[109].x())
        val s  = fw * ROI_FRACTION

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
     * Extracts yaw angle (degrees) from the facial transformation matrix.
     * Positive = turned right, negative = turned left.
     * Returns null when no transformation matrix is present.
     */
    fun matrixYaw(result: FaceLandmarkerResult): Float? {
        val opt = result.facialTransformationMatrixes()
        if (!opt.isPresent) return null
        val mats = opt.get(); if (mats.isEmpty()) return null
        val m = mats[0]; if (m.size < 3) return null
        return Math.toDegrees(asin(-m[2].toDouble().coerceIn(-1.0, 1.0))).toFloat()
    }

    fun close() {
        pipeline?.close()
        pipeline = null
    }
}

internal fun Bitmap.toArgb8888(): Bitmap =
    if (config == Bitmap.Config.ARGB_8888) this else copy(Bitmap.Config.ARGB_8888, false)
