package foundation.privacybydesign.vcmrtd.biometrics

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.util.Log
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import kotlin.math.*


/**
 * TFLite-based replacement for com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker.
 *
 * Runs the same three models that MediaPipe bundles in face_landmarker.task:
 *   face_detector.tflite           — BlazeFace short-range (128×128)
 *   face_landmarks_detector.tflite — 478-point face mesh  (256×256)
 *   face_blendshapes.tflite        — 52 blendshape scores
 *
 * Zero per frame heap allocations after initialize(): all bitmaps, byte buffers,
 * and output arrays are pre allocated and reused across calls.
 */
class FaceLandmarkPipeline(private val context: Context) {

    private var detectorInterp: Interpreter? = null
    private var landmarkInterp: Interpreter? = null
    private var blendshapeInterp: Interpreter? = null

    companion object {
        private const val TAG = "FaceLandmarkPipeline"
        private const val DETECTOR_SIZE = 128
        private const val LANDMARK_SIZE = 256
        private const val NUM_ANCHORS = 896
        private const val NUM_LANDMARKS = 478
        private const val NUM_BLENDSHAPES = 52
        private const val DETECTOR_KEYPOINTS = 6
        private const val SCORE_THRESHOLD = 0.5f
        private const val IOU_THRESHOLD = 0.3f
        // MediaPipe face_detection_front_detections_to_roi.pbtxt:
        // RectTransformationCalculator { scale_x: 2.0, scale_y: 2.0, shift_y: -0.1, square_long: true }
        private const val FIXED_CROP_MARGIN   = 2.0f
        private const val FIXED_CROP_SHIFT_Y  = -0.10f // Shift ROI slightly up (face vs shoulders bias)
        private const val PRESENCE_THRESHOLD  = 0.5f

        val BLENDSHAPE_NAMES = arrayOf(
            "_neutral", "browDownLeft", "browDownRight", "browInnerUp",
            "browOuterUpLeft", "browOuterUpRight", "cheekPuff", "cheekSquintLeft",
            "cheekSquintRight", "eyeBlinkLeft", "eyeBlinkRight", "eyeLookDownLeft",
            "eyeLookDownRight", "eyeLookInLeft", "eyeLookInRight", "eyeLookOutLeft",
            "eyeLookOutRight", "eyeLookUpLeft", "eyeLookUpRight", "eyeSquintLeft",
            "eyeSquintRight", "eyeWideLeft", "eyeWideRight", "jawForward",
            "jawLeft", "jawOpen", "jawRight", "mouthClose", "mouthDimpleLeft",
            "mouthDimpleRight", "mouthFrownLeft", "mouthFrownRight", "mouthFunnel",
            "mouthLeft", "mouthLowerDownLeft", "mouthLowerDownRight", "mouthPressLeft",
            "mouthPressRight", "mouthPucker", "mouthRight", "mouthRollLower",
            "mouthRollUpper", "mouthShrugLower", "mouthShrugUpper", "mouthSmileLeft",
            "mouthSmileRight", "mouthStretchLeft", "mouthStretchRight", "mouthUpperUpLeft",
            "mouthUpperUpRight", "noseSneerLeft", "noseSneerRight"
        )

        val BLENDSHAPE_LANDMARK_INDICES = intArrayOf(
            0,   1,   4,   5,   6,   7,   8,   10,  13,  14,  17,  21,  33,  37,  39,
            40,  46,  52,  53,  54,  55,  58,  61,  63,  65,  66,  67,  70,  78,  80,
            81,  82,  84,  87,  88,  91,  93,  95,  103, 105, 107, 109, 127, 132, 133,
            136, 144, 145, 146, 148, 149, 150, 152, 153, 154, 155, 157, 158, 159, 160,
            161, 162, 163, 168, 172, 173, 176, 178, 181, 185, 191, 195, 197, 234, 246,
            249, 251, 263, 267, 269, 270, 276, 282, 283, 284, 285, 288, 291, 293, 295,
            296, 297, 300, 308, 310, 311, 312, 314, 317, 318, 321, 323, 324, 332, 334,
            336, 338, 356, 361, 362, 365, 373, 374, 375, 377, 378, 379, 380, 381, 382,
            384, 385, 386, 387, 388, 389, 390, 397, 398, 400, 402, 405, 409, 415, 454,
            466, 468, 469, 470, 471, 472, 473, 474, 475, 476, 477
        )

        // 896 BlazeFace short-range anchors: strides [8,16,16,16], 2 anchors per cell
        val ANCHORS: Array<FloatArray> by lazy {
            val strides = intArrayOf(8, 16, 16, 16)
            val list = ArrayList<FloatArray>(NUM_ANCHORS)
            for (stride in strides) {
                val featSize = DETECTOR_SIZE / stride
                for (y in 0 until featSize)
                    for (x in 0 until featSize)
                        repeat(2) { list.add(floatArrayOf((x + 0.5f) / featSize, (y + 0.5f) / featSize)) }
            }
            list.toTypedArray()
        }
    }

    // Pre allocated bitmaps (reused every frame, zero per frame allocation)
    private val detectorBmp = Bitmap.createBitmap(DETECTOR_SIZE, DETECTOR_SIZE, Bitmap.Config.ARGB_8888)
    private val landmarkBmp = Bitmap.createBitmap(LANDMARK_SIZE, LANDMARK_SIZE, Bitmap.Config.ARGB_8888)
    private val detectorCanvas = Canvas(detectorBmp)
    private val landmarkCanvas = Canvas(landmarkBmp)
    private val detectorPaint = Paint(
        Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG or Paint.DITHER_FLAG
    )
    private val landmarkPaint = Paint(
        Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG or Paint.DITHER_FLAG
    )

    private val detectorDstRect = RectF()

    private var detectorPadX = 0f
    private var detectorPadY = 0f
    private var detectorScaleX = 1f
    private var detectorScaleY = 1f

    // Configurable presence threshold (sigmoid-space); default = MediaPipe default 0.5
    var presenceThreshold: Float = PRESENCE_THRESHOLD

    // Face tracking: null = run BlazeFace; set by updateTrackingCrop, consumed once per frame
    private val trackingLock = Any()
    private var lastCrop: DetectorStageOutput? = null

    //  Pre-allocated pixel scratch arrays
    private val detectorPixels = IntArray(DETECTOR_SIZE * DETECTOR_SIZE)
    private val landmarkPixels = IntArray(LANDMARK_SIZE * LANDMARK_SIZE)

    //  Pre-allocated input byte buffers 
    private val detectorBuf = ByteBuffer
        .allocateDirect(DETECTOR_SIZE * DETECTOR_SIZE * 3 * 4)
        .order(ByteOrder.nativeOrder())
    private val landmarkBuf = ByteBuffer
        .allocateDirect(LANDMARK_SIZE * LANDMARK_SIZE * 3 * 4)
        .order(ByteOrder.nativeOrder())

    //  Pre-allocated detector output arrays 
    private val detRegressors = Array(1) { Array(NUM_ANCHORS) { FloatArray(16) } }
    private val detScores     = Array(1) { Array(NUM_ANCHORS) { FloatArray(1) } }

    //  Output arrays allocated dynamically in initialize() to match actual model shapes 
    private var lmOutRaw:       Any = FloatArray(0)
    private var presenceOutRaw: Any = FloatArray(0)
    private var blendshapeRaw:  Any = FloatArray(0)
    private var blendshapeInBuf: ByteBuffer = ByteBuffer.allocate(0)
    private var blendshapeInputElements = 0
    private var landmarkOutputElements = NUM_LANDMARKS * 3
    
    //  Lifecycle 

    fun initialize() {
        val numThreads = (Runtime.getRuntime().availableProcessors() / 2).coerceIn(1, 4)
        val opts = Interpreter.Options().apply { setNumThreads(numThreads) }
        detectorInterp   = loadInterpreter("face_detector.tflite", opts)
        landmarkInterp   = loadInterpreter("face_landmarks_detector.tflite", opts)
        blendshapeInterp = loadInterpreter("face_blendshapes.tflite", opts)
        initializeLandmarker()
        initializeBlendshapes()
        runWarmUp()
    }

    private fun initializeLandmarker() {
        val interp = landmarkInterp ?: return
        val lmShape = interp.getOutputTensor(0).shape()
        val prShape = interp.getOutputTensor(1).shape()
        landmarkOutputElements = lmShape.fold(1, Int::times)
        lmOutRaw       = makeOutputArray(lmShape)
        presenceOutRaw = makeOutputArray(prShape)
    }

    private fun initializeBlendshapes() {
        val interp = blendshapeInterp ?: return
        val inShape  = interp.getInputTensor(0).shape()
        val outShape = interp.getOutputTensor(0).shape()
        blendshapeInputElements = inShape.fold(1, Int::times)
        blendshapeInBuf = ByteBuffer
            .allocateDirect(blendshapeInputElements * 4)
            .order(ByteOrder.nativeOrder())
        blendshapeRaw = makeOutputArray(outShape)
    }

    private fun runWarmUp() {
        try { warmUpDetector()    } catch (e: Exception) { Log.e(TAG, "Detector warm-up failed", e) }
        try { warmUpLandmarker()  } catch (e: Exception) { Log.e(TAG, "Landmarker warm-up failed", e) }
        try { warmUpBlendshapes() } catch (e: Exception) { Log.e(TAG, "Blendshapes warm-up failed", e) }
    }

    private fun warmUpDetector() {
        detectorBuf.rewind()
        repeat(DETECTOR_SIZE * DETECTOR_SIZE * 3) { detectorBuf.putFloat(0f) }
        detectorBuf.rewind()
        detectorInterp?.runForMultipleInputsOutputs(
            arrayOf(detectorBuf),
            hashMapOf<Int, Any>(0 to detRegressors, 1 to detScores)
        )
    }

    private fun warmUpLandmarker() {
        landmarkBuf.rewind()
        repeat(LANDMARK_SIZE * LANDMARK_SIZE * 3) { landmarkBuf.putFloat(0f) }
        landmarkBuf.rewind()
        landmarkInterp?.runForMultipleInputsOutputs(
            arrayOf(landmarkBuf),
            hashMapOf<Int, Any>(0 to lmOutRaw, 1 to presenceOutRaw)
        )
    }

    private fun warmUpBlendshapes() {
        if (blendshapeInputElements <= 0) return
        blendshapeInBuf.rewind()
        repeat(blendshapeInputElements) { blendshapeInBuf.putFloat(0f) }
        blendshapeInBuf.rewind()
        blendshapeInterp?.run(blendshapeInBuf, blendshapeRaw)
    }

    fun close() {
        resetTracking()
        detectorInterp?.close();   detectorInterp   = null
        landmarkInterp?.close();   landmarkInterp   = null
        blendshapeInterp?.close(); blendshapeInterp = null
        detectorBmp.recycle()
        landmarkBmp.recycle()
    }

    //  Single-call API

    fun detect(bitmap: Bitmap, runBlendshapes: Boolean = true): FaceLandmarkerResult? {
        detectorInterp ?: return null
        landmarkInterp ?: return null

        val box  = detectFace(bitmap) ?: return null
        val crop = cropRegion(box, bitmap.width, bitmap.height)
        val cropX1 = crop[0]; val cropY1 = crop[1]; val cropW = crop[2]; val cropH = crop[3]; val angle = crop[4]

        if (!fillLandmarkBitmap(bitmap, cropX1, cropY1, cropW, cropH, angle)) return null

        val presence = runLandmarks() ?: return null
        if (presence < presenceThreshold) return null

        val raw       = flatFloatArray(lmOutRaw)
        val landmarks = remapLandmarks(raw, cropX1, cropY1, cropW, cropH, angle)
        if (landmarks.size < NUM_LANDMARKS) return null
        val blendshapes = if (runBlendshapes) runBlendshapes(landmarks, bitmap.width, bitmap.height) else null
        val matrix      = computePoseMatrix(landmarks)

        return FaceLandmarkerResult(
            listOf(landmarks),
            blendshapes?.let { listOf(it) },
            matrix?.let { listOf(it) }
        )
    }

    private fun detectFace(bitmap: Bitmap): FloatArray? {
        drawDetectorLetterboxed(bitmap)
        detectorBmp.getPixels(detectorPixels, 0, DETECTOR_SIZE, 0, 0, DETECTOR_SIZE, DETECTOR_SIZE)

        detectorBuf.rewind()
        for (px in detectorPixels) {
            detectorBuf.putFloat((Color.red(px) / 127.5f) - 1f)
            detectorBuf.putFloat((Color.green(px) / 127.5f) - 1f)
            detectorBuf.putFloat((Color.blue(px) / 127.5f) - 1f)
        }
        detectorBuf.rewind()

        detectorInterp!!.runForMultipleInputsOutputs(
            arrayOf(detectorBuf),
            hashMapOf<Int, Any>(0 to detRegressors, 1 to detScores)
        )
        return decodeAndNms()
    }

    /** Decodes a single anchor [i] into a box array, or null if below threshold / degenerate. */
    private fun decodeBox(i: Int, scale: Float, boxSize: Int): FloatArray? {
        val score = sigmoid(detScores[0][i][0])
        if (score < SCORE_THRESHOLD) return null

        val a  = ANCHORS[i]
        val cx = a[0] + detRegressors[0][i][0] / scale
        val cy = a[1] + detRegressors[0][i][1] / scale
        val w  = detRegressors[0][i][2] / scale
        val h  = detRegressors[0][i][3] / scale

        val x1 = unletterboxX(cx - w * 0.5f)
        val y1 = unletterboxY(cy - h * 0.5f)
        val x2 = unletterboxX(cx + w * 0.5f)
        val y2 = unletterboxY(cy + h * 0.5f)
        if (x2 <= x1 || y2 <= y1) return null

        val box = FloatArray(boxSize)
        box[0] = x1; box[1] = y1; box[2] = x2; box[3] = y2; box[4] = score
        for (k in 0 until DETECTOR_KEYPOINTS) {
            val rx = 4 + k * 2
            val kx = a[0] + detRegressors[0][i][rx] / scale
            val ky = a[1] + detRegressors[0][i][rx + 1] / scale
            box[5 + k * 2]     = unletterboxX(kx)
            box[5 + k * 2 + 1] = unletterboxY(ky)
        }
        return box
    }

    /** Returns score-weighted average of [group]; winner confidence in index 4. */
    private fun weightedMerge(group: List<FloatArray>, boxSize: Int): FloatArray {
        val totalScore = group.sumOf { it[4].toDouble() }.toFloat()
        val merged = FloatArray(boxSize)
        for (box in group) {
            val w = box[4] / totalScore
            for (j in 0 until 4)        merged[j] += box[j] * w
            for (j in 5 until boxSize)  merged[j] += box[j] * w
        }
        merged[4] = group[0][4]
        return merged
    }

    /** MediaPipe-style soft-NMS: weighted merge per overlapping cluster, return first winner. */
    private fun softNms(sorted: List<FloatArray>, boxSize: Int): FloatArray? {
        val suppressed = BooleanArray(sorted.size)
        for (i in sorted.indices) {
            if (suppressed[i]) continue
            val base  = sorted[i]
            val group = mutableListOf(base)
            for (j in i + 1 until sorted.size) {
                if (!suppressed[j] && iou(base, sorted[j]) > IOU_THRESHOLD) {
                    group.add(sorted[j])
                    suppressed[j] = true
                }
            }
            val totalScore = group.sumOf { it[4].toDouble() }.toFloat()
            if (totalScore <= 1e-6f) return base
            return weightedMerge(group, boxSize)
        }
        return null
    }

    private fun decodeAndNms(): FloatArray? {
        val scale   = DETECTOR_SIZE.toFloat()
        val boxSize = 5 + DETECTOR_KEYPOINTS * 2
        val boxes   = (0 until NUM_ANCHORS).mapNotNull { decodeBox(it, scale, boxSize) }
        if (boxes.isEmpty()) return null
        return softNms(boxes.sortedByDescending { it[4] }, boxSize)
    }

    private fun iou(a: FloatArray, b: FloatArray): Float {
        val ix1 = max(a[0], b[0]); val iy1 = max(a[1], b[1])
        val ix2 = min(a[2], b[2]); val iy2 = min(a[3], b[3])
        if (ix2 <= ix1 || iy2 <= iy1) return 0f
        val inter = (ix2 - ix1) * (iy2 - iy1)
        return inter / ((a[2]-a[0])*(a[3]-a[1]) + (b[2]-b[0])*(b[3]-b[1]) - inter + 1e-6f)
    }

    private fun drawDetectorLetterboxed(bitmap: Bitmap) {
        detectorCanvas.drawColor(Color.BLACK)

        val srcW = bitmap.width.toFloat()
        val srcH = bitmap.height.toFloat()

        val scale = min(DETECTOR_SIZE / srcW, DETECTOR_SIZE / srcH)
        val drawW = srcW * scale
        val drawH = srcH * scale

        val left = (DETECTOR_SIZE - drawW) * 0.5f
        val top  = (DETECTOR_SIZE - drawH) * 0.5f

        detectorDstRect.set(left, top, left + drawW, top + drawH)

        detectorPadX   = left / DETECTOR_SIZE
        detectorPadY   = top / DETECTOR_SIZE
        detectorScaleX = drawW / DETECTOR_SIZE
        detectorScaleY = drawH / DETECTOR_SIZE

        detectorCanvas.drawBitmap(bitmap, null, detectorDstRect, detectorPaint)
    }

    private fun unletterboxX(x: Float): Float =
        ((x - detectorPadX) / detectorScaleX).coerceIn(0f, 1f)

    private fun unletterboxY(y: Float): Float =
        ((y - detectorPadY) / detectorScaleY).coerceIn(0f, 1f)

    // ═══════════════════════════════════════════
    //  Crop region 
    // ═══════════════════════════════════════════

    /**
     * Returns the keypoint-blended center [cx, cy] when the keypoint cloud is usable,
     * or null to fall back to the box center. Size is always taken from the box.
     *
     * Keypoints improve vertical centering on document photos (NFC/test) while keeping
     * selfie behavior stable; box size avoids oversized/unstable crops.
     */
    private fun keypointBlendedCenter(box: FloatArray, boxCx: Float, boxCy: Float): FloatArray? {
        if (box.size < 17) return null

        var minKx = Float.MAX_VALUE; var minKy = Float.MAX_VALUE
        var maxKx = -Float.MAX_VALUE; var maxKy = -Float.MAX_VALUE
        var count = 0
        for (k in 0 until DETECTOR_KEYPOINTS) {
            val x = box[5 + k * 2]; val y = box[6 + k * 2]
            if (x.isFinite() && y.isFinite() && x in 0f..1f && y in 0f..1f) {
                if (x < minKx) minKx = x; if (y < minKy) minKy = y
                if (x > maxKx) maxKx = x; if (y > maxKy) maxKy = y
                count++
            }
        }
        if (count < 4) return null

        val kpW = max(maxKx - minKx, 1e-6f)
        val kpH = max(maxKy - minKy, 1e-6f)
        if (kpW <= 0.05f || kpH <= 0.03f) return null

        val kpCx = (minKx + maxKx) * 0.5f
        val kpCy = (minKy + maxKy) * 0.5f
        return floatArrayOf(
            (kpCx * 0.7f + boxCx * 0.3f).coerceIn(0f, 1f),
            (kpCy * 0.7f + boxCy * 0.3f).coerceIn(0f, 1f)
        )
    }

    /**
     * RectTransformationCalculator equivalent (square_long + scale + shift_y).
     * Returns [x1, y1, normW, normH, angle] in normalized image coordinates.
     */
    private fun buildSquareCrop(
        cx: Float, cy: Float,
        w: Float,  h: Float,
        angle: Float,
        imgW: Int,  imgH: Int
    ): FloatArray {
        val pxSize = max(w * imgW, h * imgH) * FIXED_CROP_MARGIN
        val normW  = pxSize / imgW
        val normH  = pxSize / imgH
        val cosA   = cos(angle.toDouble()).toFloat()
        val sinA   = sin(angle.toDouble()).toFloat()
        val shiftPx   = FIXED_CROP_SHIFT_Y * pxSize
        val shiftedCx = (cx - sinA * shiftPx / imgW).coerceIn(0f, 1f)
        val shiftedCy = (cy + cosA * shiftPx / imgH).coerceIn(0f, 1f)
        return floatArrayOf(shiftedCx - normW / 2f, shiftedCy - normH / 2f, normW, normH, angle)
    }

    // Square ROI in pixel space derived from detector keypoints (preferred) with
    // fallback to detector box. This avoids low box centers on static document
    // photos (NFC/test) while keeping selfie behavior stable.
    private fun cropRegion(box: FloatArray, imgW: Int, imgH: Int): FloatArray {
        val boxCx = (box[0] + box[2]) * 0.5f
        val boxCy = (box[1] + box[3]) * 0.5f
        val boxW  = max(box[2] - box[0], 1e-6f).coerceIn(0.05f, 0.95f)
        val boxH  = max(box[3] - box[1], 1e-6f).coerceIn(0.05f, 0.95f)

        val blended = keypointBlendedCenter(box, boxCx, boxCy)
        val cx      = blended?.get(0) ?: boxCx
        val cy      = blended?.get(1) ?: boxCy

        val angle = if (box.size >= 9) computeRotation(box[5], box[6], box[7], box[8], imgW = imgW, imgH = imgH) else 0f
        return buildSquareCrop(cx, cy, boxW, boxH, angle, imgW, imgH)
    }

    /**
     * Samples the rotated face ROI from [bitmap] into the pre-allocated 256×256 [landmarkBmp].
     *
     * Uses a source-transform matrix equivalent to MediaPipe's ImageToTensor /
     * GetRotatedSubRectToRectTransformMatrix: the crop centre maps to the canvas centre
     * and the rotation is applied in source space, so [remapLandmarks] only needs the
     * inverse (which it already performs correctly).
     */
    private fun fillLandmarkBitmap(
        bitmap: Bitmap,
        normX: Float, normY: Float,
        normW: Float, normH: Float,
        angle: Float = 0f
    ): Boolean {
        val imgW = bitmap.width.toFloat()
        val imgH = bitmap.height.toFloat()

        val cropPxW = normW * imgW
        val cropPxH = normH * imgH
        if (cropPxW < 1f || cropPxH < 1f) return false

        val srcCx = (normX + normW * 0.5f) * imgW
        val srcCy = (normY + normH * 0.5f) * imgH

        val m = Matrix()
        m.setTranslate(-srcCx, -srcCy)
        m.postRotate(-Math.toDegrees(angle.toDouble()).toFloat())
        m.postScale(LANDMARK_SIZE / cropPxW, LANDMARK_SIZE / cropPxH)
        m.postTranslate(LANDMARK_SIZE * 0.5f, LANDMARK_SIZE * 0.5f)

        landmarkCanvas.drawColor(Color.BLACK)
        landmarkCanvas.drawBitmap(bitmap, m, landmarkPaint)
        return true
    }

    //═══════════════════════════════════════════
    //  Landmark inference 
    // ═══════════════════════════════════════════

    /** Returns presence score, or null if inference failed. Result is in [lmOutRaw]. */
    private fun runLandmarks(): Float? {
        val interp = landmarkInterp ?: return null
        landmarkBmp.getPixels(landmarkPixels, 0, LANDMARK_SIZE, 0, 0, LANDMARK_SIZE, LANDMARK_SIZE)

        landmarkBuf.rewind()
        for (px in landmarkPixels) {
            landmarkBuf.putFloat(Color.red(px)   / 255f)
            landmarkBuf.putFloat(Color.green(px) / 255f)
            landmarkBuf.putFloat(Color.blue(px)  / 255f)
        }
        landmarkBuf.rewind()

        interp.runForMultipleInputsOutputs(
            arrayOf(landmarkBuf),
            hashMapOf<Int, Any>(0 to lmOutRaw, 1 to presenceOutRaw)
        )
        val rawPresence = flatFloatArray(presenceOutRaw).firstOrNull() ?: return null
        return sigmoid(rawPresence).takeIf { it >= 0f }
    }

    private fun remapLandmarks(
        raw: FloatArray,
        cropX1: Float, cropY1: Float,
        cropW:  Float, cropH:  Float,
        angle:  Float = 0f
    ): List<NormalizedLandmark> {
        val n      = raw.size / 3
        val result = ArrayList<NormalizedLandmark>(n)
        val cropCx = cropX1 + cropW * 0.5f
        val cropCy = cropY1 + cropH * 0.5f
        val cosA   = cos(angle.toDouble()).toFloat()
        val sinA   = sin(angle.toDouble()).toFloat()

        for (i in 0 until n) {
            val lx = raw[i * 3]     / LANDMARK_SIZE - 0.5f
            val ly = raw[i * 3 + 1] / LANDMARK_SIZE - 0.5f
            val sx = lx * cropW
            val sy = ly * cropH
            result.add(
                NormalizedLandmark(
                    cropCx + cosA * sx - sinA * sy,
                    cropCy + sinA * sx + cosA * sy,
                    raw[i * 3 + 2] / LANDMARK_SIZE * cropW
                )
            )
        }
        return result
    }

    // ═══════════════════════════════════════════
    //  Blendshape inference 
    // ═══════════════════════════════════════════

    private fun runBlendshapes(landmarks: List<NormalizedLandmark>, imgW: Int, imgH: Int): List<Category>? {
        val interp = blendshapeInterp ?: return null
        if (blendshapeInputElements <= 0) return null

        blendshapeInBuf.rewind()
        for (idx in BLENDSHAPE_LANDMARK_INDICES) {
            val lm = landmarks[idx]
            blendshapeInBuf.putFloat(lm.x() * imgW)
            blendshapeInBuf.putFloat(lm.y() * imgH)
        }
        blendshapeInBuf.rewind()

        return try {
            interp.run(blendshapeInBuf, blendshapeRaw)
            flatFloatArray(blendshapeRaw).mapIndexed { i, score ->
                Category(BLENDSHAPE_NAMES.getOrElse(i) { "blend_$i" }, score)
            }
        } catch (e: Exception) { Log.e(TAG, "Blendshapes inference failed", e); null }
    }

    // ═══════════════════════════════════════════
    //  Pose matrix 
    // ═══════════════════════════════════════════

    /**
     * Builds a 4×4 face-to-camera rotation matrix from image-space landmarks.
     *
     * The three face axes are derived directly from stable landmarks:
     *   right  = P[454] − P[234]  (viewer's left→right cheek edge)
     *   up     = P[10]  − P[152]  (chin→forehead)
     *   normal = right × up       (Gram-Schmidt orthogonalized)
     *
     * Matrix layout (4×4 row-major): columns are [right, up, normal].
     * m[2] = R[0][2] = normal.x, so LivenessService.matrixYaw() = asin(−m[2])
     * gives positive degrees when the subject turns to their right.
     *
     * Must receive image-space [remapLandmarks] output, NOT raw 256-pixel coords.
     */
    private fun computePoseMatrix(lm: List<NormalizedLandmark>): FloatArray? {
        if (lm.size < 455) return null

        // Right vector: viewer's-left cheek (234) → viewer's-right cheek (454)
        var rX = lm[454].x() - lm[234].x()
        var rY = lm[454].y() - lm[234].y()
        var rZ = lm[454].z() - lm[234].z()

        // Up vector: chin (152) → forehead (10)
        var uX = lm[10].x() - lm[152].x()
        var uY = lm[10].y() - lm[152].y()
        var uZ = lm[10].z() - lm[152].z()

        val rLen = sqrt((rX*rX + rY*rY + rZ*rZ).toDouble()).toFloat()
        if (rLen < 1e-6f) return null
        rX /= rLen; rY /= rLen; rZ /= rLen

        // Gram-Schmidt: remove right component from up, then normalize
        val dot = uX*rX + uY*rY + uZ*rZ
        uX -= dot*rX; uY -= dot*rY; uZ -= dot*rZ
        val uLen = sqrt((uX*uX + uY*uY + uZ*uZ).toDouble()).toFloat()
        if (uLen < 1e-6f) return null
        uX /= uLen; uY /= uLen; uZ /= uLen

        // Normal = right × up
        val nX = rY*uZ - rZ*uY
        val nY = rZ*uX - rX*uZ
        val nZ = rX*uY - rY*uX

        return floatArrayOf(
            rX, uX, nX, 0f,
            rY, uY, nY, 0f,
            rZ, uZ, nZ, 0f,
            0f, 0f, 0f, 1f
        )
    }

    //  Pipelined two stage
    //
    // Stage 1 (detector thread): BlazeFace only.
    // Stage 2 (landmark thread): landmarks + blendshapes.
    //
    // The two stages use disjoint pre-allocated buffers and separate TFLite
    // Interpreter instances, so they can safely run concurrently on different
    // threads — as long as each stage is called from at most one thread at a time.

    /**
     * Crop parameters produced by [runDetectorStage] and consumed by [runLandmarkStage].
     * Holds no Bitmap reference — the caller keeps the original frame alive.
     */
    data class DetectorStageOutput(
        val cropX1: Float, val cropY1: Float,
        val cropW:  Float, val cropH:  Float,
        val angle:  Float
    )

    /**
     * Stage 1: return the landmark-derived tracking crop if available, otherwise run BlazeFace.
     *
     * [updateTrackingCrop] sets [lastCrop] every frame a face is detected in stage 2, so
     * BlazeFace only runs on the first frame or after tracking is explicitly lost via
     * [resetTracking]. This gives one-shot detection latency (BlazeFace) on acquisition
     * and near-zero overhead on subsequent frames (landmark bbox feedback).
     */
    fun runDetectorStage(bitmap: Bitmap): DetectorStageOutput? {
        detectorInterp ?: return null
        // Consume the tracking crop produced by the previous frame's updateTrackingCrop().
        // If null, fall back to BlazeFace. updateTrackingCrop() repopulates lastCrop on
        // every successful landmark frame; resetTracking() clears it on loss.
        val cached = synchronized(trackingLock) {
            val crop = lastCrop
            lastCrop = null
            crop
        }
        if (cached != null) return cached

        val box  = detectFace(bitmap) ?: return null
        val crop = cropRegion(box, bitmap.width, bitmap.height)
        return DetectorStageOutput(crop[0], crop[1], crop[2], crop[3], crop[4])
    }

    /** Returns the axis-aligned bounding box of [lms] as [minX, maxX, minY, maxY]. */
    private fun landmarkBounds(lms: List<NormalizedLandmark>): FloatArray {
        var minX = Float.MAX_VALUE; var maxX = -Float.MAX_VALUE
        var minY = Float.MAX_VALUE; var maxY = -Float.MAX_VALUE
        for (lm in lms) {
            if (lm.x() < minX) minX = lm.x(); if (lm.x() > maxX) maxX = lm.x()
            if (lm.y() < minY) minY = lm.y(); if (lm.y() > maxY) maxY = lm.y()
        }
        return floatArrayOf(minX, maxX, minY, maxY)
    }

    /**
     * Updates [lastCrop] from the 478-landmark bounding box so the next call to
     * [runDetectorStage] skips BlazeFace entirely and uses this tighter, fresher crop.
     * Must be called after every successful [runLandmarkStage].
     */
    fun updateTrackingCrop(result: FaceLandmarkerResult, imgW: Int, imgH: Int) {
        val lms = result.faceLandmarks().firstOrNull() ?: return
        if (lms.size < NUM_LANDMARKS) return

        val bounds = landmarkBounds(lms)
        val minX = bounds[0]; val maxX = bounds[1]; val minY = bounds[2]; val maxY = bounds[3]
        val cx = (minX + maxX) / 2f
        val cy = (minY + maxY) / 2f
        val w  = maxX - minX
        val h  = maxY - minY

        // MediaPipe tracking uses landmarks 33 (right eye) and 263 (left eye) for rotation.
        val angle = computeRotation(lms[33].x(), lms[33].y(), lms[263].x(), lms[263].y(), imgW = imgW, imgH = imgH)
        val crop  = buildSquareCrop(cx, cy, w, h, angle, imgW, imgH)

        synchronized(trackingLock) {
            lastCrop = DetectorStageOutput(crop[0], crop[1], crop[2], crop[3], crop[4])
        }
    }

    /**
     * Clears [lastCrop] and One Euro Filter state. Call when the face is lost
     * (landmark stage returns null) so the next frame triggers a fresh BlazeFace run.
     */
    fun resetTracking() {
        synchronized(trackingLock) { lastCrop = null }
    }

    /**
     * Stage 2: fill landmark crop, run landmark + blendshape models, apply One Euro Filter.
     * [bitmap] must be the same frame that was passed to [runDetectorStage].
     * Must be called from a single dedicated thread (never concurrently with itself).
     */
    fun runLandmarkStage(
        bitmap: Bitmap,
        crop: DetectorStageOutput,
        runBlendshapes: Boolean = true
    ): FaceLandmarkerResult? {
        landmarkInterp ?: return null
        if (!fillLandmarkBitmap(bitmap, crop.cropX1, crop.cropY1, crop.cropW, crop.cropH, crop.angle)) return null
        val presence = runLandmarks() ?: return null
        if (presence < presenceThreshold) return null
        val raw       = flatFloatArray(lmOutRaw)
        val landmarks = remapLandmarks(raw, crop.cropX1, crop.cropY1, crop.cropW, crop.cropH, crop.angle)
        if (landmarks.size < NUM_LANDMARKS) return null
        val blendshapes = if (runBlendshapes) runBlendshapes(landmarks, bitmap.width, bitmap.height) else null
        val matrix      = computePoseMatrix(landmarks)
        return FaceLandmarkerResult(
            listOf(landmarks),
            blendshapes?.let { listOf(it) },
            matrix?.let { listOf(it) }
        )
    }

    // ═══════════════════════════════════════════
    //  Utilities
    // ═══════════════════════════════════════════

    private fun makeOutputArray(shape: IntArray): Any = when (shape.size) {
        1    -> FloatArray(shape[0])
        2    -> Array(shape[0]) { FloatArray(shape[1]) }
        3    -> Array(shape[0]) { Array(shape[1]) { FloatArray(shape[2]) } }
        else -> Array(shape[0]) { Array(shape[1]) { Array(shape[2]) { FloatArray(shape.drop(3).fold(1, Int::times)) } } }
    }

    private fun flatFloatArray(arr: Any): FloatArray = when (arr) {
        is FloatArray -> arr
        is Array<*>   -> {
            val parts = arr.map { flatFloatArray(it ?: return@map FloatArray(0)) }
            val total = parts.sumOf { it.size }
            val out   = FloatArray(total)
            var pos   = 0
            for (part in parts) { part.copyInto(out, pos); pos += part.size }
            out
        }
        else -> FloatArray(0)
    }

    private fun sigmoid(x: Float) = (1f / (1f + exp(-x.toDouble()))).toFloat()

    private fun normalizeAngle(angle: Float): Float {
        val twoPi = 2f * PI.toFloat()
        var a = angle % twoPi
        if (a > PI.toFloat()) a -= twoPi
        if (a < -PI.toFloat()) a += twoPi
        return a
    }

    /**
     * MediaPipe rotation formula: normalizeAngle(targetAngle - atan2(-(endY-startY), endX-startX))
     * For BlazeFace: start = right-eye keypoint, end = left-eye keypoint, targetAngle = 0.
     * For tracking: start = lm[33] (right eye), end = lm[263] (left eye), targetAngle = 0.
     *
     * [imgW]/[imgH]: pixel dimensions of the source image. Supplying them converts the
     * normalized coordinate deltas to pixel-space before atan2, which gives a correct
     * angle on non-square images (e.g. 240×320 portrait frames).
     */
    private fun computeRotation(
        startX: Float, startY: Float,
        endX:   Float, endY:   Float,
        targetAngle: Float = 0f,
        imgW: Int = 1, imgH: Int = 1
    ): Float = normalizeAngle(targetAngle - atan2(
        -(endY - startY) * imgH,
        (endX - startX)  * imgW
    ))

    private fun loadInterpreter(file: String, opts: Interpreter.Options): Interpreter? = try {
        context.assets.openFd(file).use { afd ->
            FileInputStream(afd.fileDescriptor).use { fis ->
                val buf = fis.channel.map(FileChannel.MapMode.READ_ONLY, afd.startOffset, afd.declaredLength)
                Interpreter(buf, opts)
            }
        }
    } catch (e: Exception) { Log.e(TAG, "Failed to load model $file", e); null }
}
