package foundation.privacybydesign.vcmrtd.biometrics

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.media.ExifInterface
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

class FaceDetectorService(private val context: Context) {

    private var pipeline: FaceLandmarkPipeline? = null

    companion object {
        private const val TARGET_SIZE = 112

        // ArcFace 5-point reference positions for 112×112, observer's perspective.
        // "left" = observer's left (low x), "right" = observer's right (high x).
        private val DST_POINTS = floatArrayOf(
            38.2946f, 51.6963f,  // observer's left eye  (= subject's right)
            73.5318f, 51.5014f,  // observer's right eye (= subject's left)
            56.0252f, 71.7366f,  // nose tip
            41.5493f, 92.3655f,  // observer's left mouth corner  (= subject's right)
            70.7299f, 92.2041f   // observer's right mouth corner (= subject's left)
        )

        // Original ArcFace 5-point source landmarks from MediaPipe FaceMesh.
        // Keep these to match previous working behavior as closely as possible.
        private const val IDX_LEFT_EYE  = 468
        private const val IDX_RIGHT_EYE = 473
        private const val IDX_NOSE      = 1
        private const val IDX_MOUTH_L   = 61
        private const val IDX_MOUTH_R   = 291
    }

    fun initialize() {
        if (pipeline != null) return
        pipeline = FaceLandmarkPipeline(context).also { it.initialize() }
    }

    /**
     * Detects face from a live camera bitmap (already ARGB_8888, no EXIF rotation needed).
     * Applies 5-point similarity transform and returns 112x112 bitmap.
     */
    fun detectAndCrop(bitmap: Bitmap): Bitmap? {
        val argb = bitmap.toArgb8888()
        return try {
            val result = pipeline?.detect(argb, runBlendshapes = false)
            if (result == null || result.faceLandmarks().isEmpty()) null
            else similarityWarp(argb, result)
        } finally {
            if (argb !== bitmap && !argb.isRecycled) argb.recycle()
        }
    }

    /**
     * Detects face from image bytes (JPEG/PNG with EXIF), applies 5-point similarity transform
     * and returns 112x112 bitmap.
     */
    fun detectAndCrop(imageBytes: ByteArray): Bitmap? {
        val decoded = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size) ?: return null
        val bitmap = decoded.toArgb8888()
        if (bitmap !== decoded) decoded.recycle()

        try {
            val corrected = correctRotation(bitmap, imageBytes)
            try {
                val result = pipeline?.detect(corrected, runBlendshapes = false)
                if (result == null || result.faceLandmarks().isEmpty()) return null
                return similarityWarp(corrected, result)
            } finally {
                if (corrected !== bitmap && !corrected.isRecycled) corrected.recycle()
            }
        } finally {
            if (!bitmap.isRecycled) bitmap.recycle()
        }
    }

    /**
     * Applies a similarity transform (rotation + scale + translation) based on
     * 5 facial landmarks, mapping them to ArcFace reference positions in 112x112.
     */
    private fun similarityWarp(bitmap: Bitmap, result: FaceLandmarkerResult): Bitmap {
        val landmarks = result.faceLandmarks()[0]
        val w = bitmap.width.toFloat()
        val h = bitmap.height.toFloat()

        val eyeAX = landmarks[IDX_LEFT_EYE].x() * w
        val eyeAY = landmarks[IDX_LEFT_EYE].y() * h
        val eyeBX = landmarks[IDX_RIGHT_EYE].x() * w
        val eyeBY = landmarks[IDX_RIGHT_EYE].y() * h

        val noseX = landmarks[IDX_NOSE].x() * w
        val noseY = landmarks[IDX_NOSE].y() * h

        val mouthAX = landmarks[IDX_MOUTH_L].x() * w
        val mouthAY = landmarks[IDX_MOUTH_L].y() * h
        val mouthBX = landmarks[IDX_MOUTH_R].x() * w
        val mouthBY = landmarks[IDX_MOUTH_R].y() * h

        // Runtime handedness guard (works for mirrored/non-mirrored feeds):
        // map lower-x to observer-left target point and higher-x to observer-right.
        val leftEyeX: Float
        val leftEyeY: Float
        val rightEyeX: Float
        val rightEyeY: Float
        if (eyeAX <= eyeBX) {
            leftEyeX = eyeAX; leftEyeY = eyeAY
            rightEyeX = eyeBX; rightEyeY = eyeBY
        } else {
            leftEyeX = eyeBX; leftEyeY = eyeBY
            rightEyeX = eyeAX; rightEyeY = eyeAY
        }

        val leftMouthX: Float
        val leftMouthY: Float
        val rightMouthX: Float
        val rightMouthY: Float
        if (mouthAX <= mouthBX) {
            leftMouthX = mouthAX; leftMouthY = mouthAY
            rightMouthX = mouthBX; rightMouthY = mouthBY
        } else {
            leftMouthX = mouthBX; leftMouthY = mouthBY
            rightMouthX = mouthAX; rightMouthY = mouthAY
        }

        val src = floatArrayOf(
            leftEyeX, leftEyeY,
            rightEyeX, rightEyeY,
            noseX, noseY,
            leftMouthX, leftMouthY,
            rightMouthX, rightMouthY
        )

        val matrix = estimateSimilarityTransform(src, DST_POINTS)
        val output = Bitmap.createBitmap(TARGET_SIZE, TARGET_SIZE, Bitmap.Config.ARGB_8888)
        Canvas(output).drawBitmap(bitmap, matrix, Paint(Paint.FILTER_BITMAP_FLAG))
        return output
    }

    /**
     * Estimates a similarity transform matrix (rotation + uniform scale + translation)
     * that maps src points to dst points using least squares (Umeyama algorithm).
     */
    private fun estimateSimilarityTransform(src: FloatArray, dst: FloatArray): Matrix {
        val n = src.size / 2

        var srcMx = 0f; var srcMy = 0f
        var dstMx = 0f; var dstMy = 0f
        for (i in 0 until n) {
            srcMx += src[i * 2]; srcMy += src[i * 2 + 1]
            dstMx += dst[i * 2]; dstMy += dst[i * 2 + 1]
        }
        srcMx /= n; srcMy /= n
        dstMx /= n; dstMy /= n

        var a = 0f; var b = 0f; var srcVar = 0f
        for (i in 0 until n) {
            val sx = src[i * 2] - srcMx;     val sy = src[i * 2 + 1] - srcMy
            val dx = dst[i * 2] - dstMx;     val dy = dst[i * 2 + 1] - dstMy
            a += sx * dx + sy * dy
            b += sx * dy - sy * dx
            srcVar += sx * sx + sy * sy
        }

        val scale = if (srcVar > 0f) sqrt((a * a + b * b).toDouble()).toFloat() / srcVar else 1f
        val cos   = if (srcVar > 0f) a / (srcVar * scale) else 1f
        val sin   = if (srcVar > 0f) b / (srcVar * scale) else 0f

        val tx = dstMx - scale * (cos * srcMx - sin * srcMy)
        val ty = dstMy - scale * (sin * srcMx + cos * srcMy)

        val matrix = Matrix()
        matrix.setValues(floatArrayOf(
            scale * cos,  -scale * sin,  tx,
            scale * sin,   scale * cos,  ty,
            0f,            0f,           1f
        ))
        return matrix
    }

    private fun correctRotation(bitmap: Bitmap, imageBytes: ByteArray): Bitmap {
        val exif = ExifInterface(imageBytes.inputStream())
        val orientation = exif.getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL
        )

        val rotation = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90  -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }

        if (rotation == 0f) return bitmap

        val matrix = Matrix().apply { postRotate(rotation) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    fun close() {
        pipeline?.close()
        pipeline = null
    }
}
