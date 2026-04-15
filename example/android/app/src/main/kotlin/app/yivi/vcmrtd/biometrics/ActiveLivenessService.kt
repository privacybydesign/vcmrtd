package foundation.privacybydesign.vcmrtd.biometrics

import android.graphics.Bitmap
import android.os.SystemClock
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import kotlin.math.abs
import kotlin.math.asin
import kotlin.math.sqrt
import kotlin.random.Random

class ActiveLivenessService(
    private val livenessService: LivenessService,
    private val passiveLivenessService: PassiveLivenessService
) {

    companion object {
        private const val TAG = "ActiveLivenessService"

        // ── Confirmation ──
        private const val CONFIRM_THRESHOLD = 4
        private const val CONFIRM_INCREMENT = 2
        private const val CONFIRM_DECAY = 1

        // ── Baseline ──
        private const val BASELINE_FRAMES = 6

        // ── Rest face ──
        // Number of frames the face must remain neutral/stable before the
        // next action is allowed to start (prevents false-positive rapid actions)
        private const val REST_STABLE_FRAMES = 4
        private const val REST_MAX_YAW_DEG   = 10f   // head within 10° of forward
        private const val REST_MAX_EAR       = 0.15f  // eyes not closed (no squint)
        private const val REST_MAX_MOUTH     = 0.05f  // mouth closed (gap / faceHeight ratio)
        private const val REST_MAX_SMILE     = 0.25f  // no pronounced smile

        // ── Blink ──
        private const val EAR_OPEN_THRESHOLD = 0.25f
        private const val BLEND_EYE_CLOSED_THRESHOLD = 0.45f
        private const val EAR_WEIGHT = 0.3f
        private const val BLEND_WEIGHT = 0.7f
        private const val FUSED_BLINK_CLOSED = 0.55f
        private const val FUSED_BLINK_OPEN = 0.45f
        private const val MIN_CLOSED_FRAMES = 1

        // ── Mouth open ──
        private const val MOUTH_OPEN_THRESHOLD = 0.028f
        private const val JAW_OPEN_BLEND_THRESHOLD = 0.14f
        private const val SMILE_SUPPRESSES_MOUTH_BLEND = 0.35f

        // ── Smile ──
        private const val SMILE_WIDTH_THRESHOLD = 0.018f
        private const val SMILE_LIFT_THRESHOLD = 0.010f
        private const val SMILE_BLEND_THRESHOLD = 0.32f
        private const val MOUTH_SUPPRESSES_SMILE_BLEND = 0.18f

        // ── Turn ──
        private const val YAW_THRESHOLD_DEG = 28f
        private const val LANDMARK_TURN_THRESHOLD = 0.10f
        private const val LANDMARK_TURN_RELEASE = 0.05f
        private const val YAW_RELEASE_DEG = 5f
        // ── Anti-spoof ──
        private const val ANTISPOOF_SAMPLE_RATE = 0.30f
        private const val ANTISPOOF_MAX_YAW_DEG = 15f
        private const val RPPG_FRONTAL_MAX_YAW = 10f
        private const val RPPG_SAMPLE_INTERVAL = 1 // collect every frame
        private const val RPPG_MAX_GAP_MS = 1000L    // if gap > 1000ms, reset sample sequence
        private const val RPPG_MIN_ROI_PIX = 12
        private const val RPPG_ENLARGE_FACTOR = 1.8f
        val ALL_ACTIONS = listOf(
            LivenessAction.BLINK,
            LivenessAction.TURN_LEFT,
            LivenessAction.TURN_RIGHT,
            LivenessAction.MOUTH_OPEN,
            LivenessAction.SMILE,
        )
    }
    
    enum class LivenessAction { BLINK, TURN_LEFT, TURN_RIGHT, MOUTH_OPEN, SMILE }

    private enum class BlinkPhase { OPEN, CLOSING, CLOSED, DETECTED }

    private var currentAction: LivenessAction? = null
    private var confirmCount = 0
    private var blinkPhase = BlinkPhase.OPEN
    private var blinkClosedFrames = 0

    private var neutralYawMatrix: Float? = null
    private var neutralYawLandmark: Float? = null
    private var neutralMouth: Float? = null
    private var neutralSmileLift: Float? = null
    private var neutralSmileWidth: Float? = null

    private var baselineYaw = 0
    private var baselineMouth = 0
    private var baselineSmile = 0

    private val blYawMatrix = mutableListOf<Float>()
    private val blYawLandmark = mutableListOf<Float>()
    private val blMouth = mutableListOf<Float>()
    private val blSmileLift = mutableListOf<Float>()
    private val blSmileWidth = mutableListOf<Float>()

    private var turnDetectedLatch = false

    // ── Rest face state ──
    // After an action completes we wait for the face to return to a neutral
    // baseline before starting the next action. This prevents spurious
    // detections when the user is still moving.
    private var waitingForRest = false
    private var nextActionQueued: LivenessAction? = null
    private var restStableCount = 0

    private val antiSpoofScores = mutableListOf<Double?>()
    private var totalFrames = 0
    private var antiSpoofAttempts = 0
    private val rppgSamples = mutableListOf<FloatArray>()
    private val rppgSampleTimes = mutableListOf<Long>()

    fun getTotalFrames(): Int = totalFrames
    fun getAntiSpoofAttempts(): Int = antiSpoofAttempts

    fun getAntiSpoofScore(): Double? {
        val valid = antiSpoofScores.filterNotNull()
        return if (valid.isEmpty()) null else valid.average()
    }

    fun isAntiSpoofPassed(): Boolean =
        passiveLivenessService.isAntiSpoofPassed(antiSpoofScores)

    fun startAction(action: LivenessAction) {
        currentAction = action
        confirmCount = 0
        blinkPhase = BlinkPhase.OPEN
        blinkClosedFrames = 0
        turnDetectedLatch = false
        waitingForRest = false
        nextActionQueued = null
        restStableCount = 0

        neutralYawMatrix = null; neutralYawLandmark = null
        neutralMouth = null; neutralSmileLift = null; neutralSmileWidth = null
        baselineYaw = 0; baselineMouth = 0; baselineSmile = 0

        blYawMatrix.clear(); blYawLandmark.clear()
        blMouth.clear(); blSmileLift.clear(); blSmileWidth.clear()
    }

    /**
     * Queues the next action to start after the face returns to rest.
     * Call this instead of startAction when transitioning between actions,
     * so the baseline is only measured on a truly neutral face.
     */
    fun queueNextAction(action: LivenessAction) {
        waitingForRest = true
        nextActionQueued = action
        restStableCount = 0
        android.util.Log.d(TAG, "Waiting for rest face before starting $action")
    }

    fun reset() {
        currentAction = null
        confirmCount = 0
        blinkPhase = BlinkPhase.OPEN
        blinkClosedFrames = 0
        turnDetectedLatch = false
        waitingForRest = false
        nextActionQueued = null
        restStableCount = 0

        neutralYawMatrix = null; neutralYawLandmark = null
        neutralMouth = null; neutralSmileLift = null; neutralSmileWidth = null
        baselineYaw = 0; baselineMouth = 0; baselineSmile = 0

        blYawMatrix.clear(); blYawLandmark.clear()
        blMouth.clear(); blSmileLift.clear(); blSmileWidth.clear()

        antiSpoofScores.clear()
        totalFrames = 0
        antiSpoofAttempts = 0
        rppgSamples.clear()
        rppgSampleTimes.clear()
        livenessService.resetLiveState()
    }

    fun processFrame(bitmap: Bitmap): Boolean {
        val action = currentAction ?: return false

        val t0 = SystemClock.elapsedRealtime()
        val argb = bitmap.toArgb8888()
        val convertMs = SystemClock.elapsedRealtime() - t0

        try {
            val t1 = SystemClock.elapsedRealtime()
            val result = livenessService.detectImage(argb) ?: return false
            val mediapipeMs = SystemClock.elapsedRealtime() - t1

            totalFrames++

            val lm = result.faceLandmarks()[0]

            // Anti-spoof sampling
            if (Random.nextFloat() < ANTISPOOF_SAMPLE_RATE) {
                antiSpoofAttempts++
                val yaw = matrixYaw(result)
                val isFrontal = yaw == null || abs(yaw) < ANTISPOOF_MAX_YAW_DEG
                if (isFrontal) {
                    val rois = livenessService.extractRois(result)
                    if (rois != null) {
                        val score = passiveLivenessService.scoreFrame(argb, rois)
                        antiSpoofScores.add(score)
                        if (score != null) {
                            android.util.Log.d(TAG,
                                "AntiSpoof score=${"%.3f".format(score)} " +
                                        "yaw=${yaw?.let { "%.1f".format(it) } ?: "null"} " +
                                        "samples=${antiSpoofScores.filterNotNull().size}")
                        }
                        // NOTE: rPPG sampling moved outside anti-spoof block (below)
                    }
                    } else {
                        android.util.Log.d(TAG,
                            "AntiSpoof: frame skipped (yaw=${"%.1f".format(yaw!!)}° > ${ANTISPOOF_MAX_YAW_DEG}°)")
                    }
            }

            // rPPG sampling: collect multi-ROI averaged RGB every frame when ROIs available
            try {
                val roisAll = livenessService.extractRois(result)
                if (roisAll != null && (totalFrames % RPPG_SAMPLE_INTERVAL) == 0) {
                    val now = SystemClock.elapsedRealtime()
                    if (rppgSampleTimes.isNotEmpty() && now - rppgSampleTimes.last() > RPPG_MAX_GAP_MS) {
                        rppgSamples.clear(); rppgSampleTimes.clear()
                    }

                    val yawForR = matrixYaw(result)
                    val isRppgFrontal = yawForR == null || kotlin.math.abs(yawForR) <= RPPG_FRONTAL_MAX_YAW
                    if (isRppgFrontal) {
                        val zones = listOf(
                            LivenessService.RoiZone.FOREHEAD,
                            LivenessService.RoiZone.LEFT_CHEEK,
                            LivenessService.RoiZone.RIGHT_CHEEK,
                            LivenessService.RoiZone.NOSE
                        )
                        var sumR = 0f; var sumG = 0f; var sumB = 0f; var cnt = 0
                        for (z in zones) {
                            var rroi = roisAll[z] ?: continue
                            // ensure roi pixel size is large enough; if too small, try enlarging
                            val estPix = (rroi[2] * argb.width).toInt()
                            if (estPix < RPPG_MIN_ROI_PIX) {
                                // enlarge copy
                                val enlarged = floatArrayOf(rroi[0], rroi[1], (rroi[2] * RPPG_ENLARGE_FACTOR).coerceAtMost(0.5f))
                                rroi = enlarged
                            }

                            val rgb = livenessService.extractRgbFromRoi(argb, rroi)
                            if (rgb != null) {
                                sumR += rgb[0]; sumG += rgb[1]; sumB += rgb[2]; cnt++
                            }
                        }
                        if (cnt > 0) {
                            val avg = floatArrayOf(sumR / cnt, sumG / cnt, sumB / cnt)
                            rppgSamples.add(avg)
                            rppgSampleTimes.add(now)
                            if (rppgSamples.size > 1200) { rppgSamples.removeAt(0); rppgSampleTimes.removeAt(0) }
                        } else {
                        }
                    } else {
                    }
                }
            } catch (_: Exception) {}

            // ── Rest face check ──
            // If we're waiting for a neutral face before the next action,
            // check rest state and start the queued action once stable.
            if (waitingForRest) {
                val isRest = isFaceAtRest(lm, result)
                if (isRest) {
                    restStableCount++
                    android.util.Log.d(TAG, "Rest face stable: $restStableCount/$REST_STABLE_FRAMES")
                } else {
                    restStableCount = 0
                }

                if (restStableCount >= REST_STABLE_FRAMES) {
                    val next = nextActionQueued
                    if (next != null) {
                        android.util.Log.d(TAG, "Rest detected, starting $next")
                        startAction(next)  // reset everything and start the next action
                    }
                }
                return false  // no new action completed yet
            }

            // ── Normal action detection ──
            val t2 = SystemClock.elapsedRealtime()
            val detected = when (action) {
                LivenessAction.BLINK      -> detectBlink(lm, result)
                LivenessAction.TURN_LEFT  -> detectTurn(lm, result, left = true)
                LivenessAction.TURN_RIGHT -> detectTurn(lm, result, left = false)
                LivenessAction.MOUTH_OPEN -> detectMouthOpen(lm, result)
                LivenessAction.SMILE      -> detectSmile(lm, result)
            }
            val logicMs = SystemClock.elapsedRealtime() - t2

            if (detected) {
                confirmCount = (confirmCount + CONFIRM_INCREMENT)
                    .coerceAtMost(CONFIRM_THRESHOLD + 2)
            } else if (confirmCount > 0) {
                confirmCount = (confirmCount - CONFIRM_DECAY).coerceAtLeast(0)
            }

            val done = confirmCount >= CONFIRM_THRESHOLD

            android.util.Log.d(TAG,
                "⏱ convert=${convertMs}ms mediapipe=${mediapipeMs}ms logic=${logicMs}ms | " +
                        "$action det=$detected confirm=$confirmCount/$CONFIRM_THRESHOLD done=$done")

            return done
        } finally {
            if (argb !== bitmap && !argb.isRecycled) argb.recycle()
        }
    }

    // ═══════════════════════════════════════════
    //  REST FACE
    //  Checks if face is back to neutral position after an action.
    //  All checks must pass simultaneously for REST_STABLE_FRAMES frames.
    // ═══════════════════════════════════════════

    private fun isFaceAtRest(lm: List<NormalizedLandmark>, r: FaceLandmarkerResult): Boolean {
        // Hoofd recht (yaw dicht bij nul)
        val yaw = matrixYaw(r)
        if (yaw != null && abs(yaw) > REST_MAX_YAW_DEG) {
            android.util.Log.v(TAG, "rest: yaw=${yaw} te groot")
            return false
        }

        // Eyes open
        val avgEar = (ear(lm, true) + ear(lm, false)) / 2f
        if (avgEar < REST_MAX_EAR) {
            android.util.Log.v(TAG, "rest: eyes too closed (ear=$avgEar)")
            return false
        }

        // Mouth closed
        val gap = dist(lm[13], lm[14])
        val fH  = dist(lm[10], lm[152]).coerceAtLeast(1e-6f)
        if (gap / fH > REST_MAX_MOUTH) {
            android.util.Log.v(TAG, "rest: mouth too open (${gap/fH})")
            return false
        }

        // No smile
        val sL = livenessService.getBlendshapeScore("mouthSmileLeft", r) ?: 0f
        val sR = livenessService.getBlendshapeScore("mouthSmileRight", r) ?: 0f
        if ((sL + sR) / 2f > REST_MAX_SMILE) {
            android.util.Log.v(TAG, "rest: still smiling")
            return false
        }

        return true
    }

    // ═══════════════════════════════════════════
    //  BLINK
    // ═══════════════════════════════════════════

    private fun detectBlink(lm: List<NormalizedLandmark>, r: FaceLandmarkerResult): Boolean {
        val earL = ear(lm, true); val earR = ear(lm, false)
        val avgEar = (earL + earR) / 2f

        val bL = livenessService.getBlendshapeScore("eyeBlinkLeft", r)
            ?: livenessService.getBlendshapeScore("eyeClosedLeft", r) ?: 0f
        val bR = livenessService.getBlendshapeScore("eyeBlinkRight", r)
            ?: livenessService.getBlendshapeScore("eyeClosedRight", r) ?: 0f
        val blend = (bL + bR) / 2f

        val earScore = (1f - (avgEar / EAR_OPEN_THRESHOLD).coerceIn(0f, 1f))
        val blendScore = (blend / BLEND_EYE_CLOSED_THRESHOLD).coerceIn(0f, 1f)
        val fused = EAR_WEIGHT * earScore + BLEND_WEIGHT * blendScore

        val closed = fused >= FUSED_BLINK_CLOSED
        val open   = fused <= FUSED_BLINK_OPEN

        blinkPhase = when (blinkPhase) {
            BlinkPhase.OPEN -> if (closed) {
                blinkClosedFrames = 1; BlinkPhase.CLOSING
            } else BlinkPhase.OPEN

            BlinkPhase.CLOSING -> if (closed) {
                blinkClosedFrames++
                if (blinkClosedFrames >= MIN_CLOSED_FRAMES) BlinkPhase.CLOSED
                else BlinkPhase.CLOSING
            } else { blinkClosedFrames = 0; BlinkPhase.OPEN }

            BlinkPhase.CLOSED   -> if (open) BlinkPhase.DETECTED else BlinkPhase.CLOSED
            BlinkPhase.DETECTED -> BlinkPhase.DETECTED
        }

        android.util.Log.v(TAG,
            "blink: ear=${"%.3f".format(avgEar)} blend=${"%.3f".format(blend)} " +
                    "fused=${"%.3f".format(fused)} phase=$blinkPhase")
        return blinkPhase == BlinkPhase.DETECTED
    }

    private fun ear(lm: List<NormalizedLandmark>, left: Boolean): Float {
        val p1: Int; val p2: Int; val p3: Int; val p4: Int; val p5: Int; val p6: Int
        if (left) { p1=362; p2=385; p3=387; p4=263; p5=373; p6=380 }
        else       { p1=33;  p2=160; p3=158; p4=133; p5=153; p6=144 }
        val a = dist(lm[p2], lm[p6]); val b = dist(lm[p3], lm[p5])
        val c = dist(lm[p1], lm[p4])
        return (a + b) / (2f * c + 1e-6f)
    }

    // ═══════════════════════════════════════════
    //  TURN LEFT / RIGHT
    // ═══════════════════════════════════════════

    private fun detectTurn(lm: List<NormalizedLandmark>, r: FaceLandmarkerResult, left: Boolean): Boolean {
        val matYaw = matrixYaw(r)
        val lmYaw  = landmarkYaw(lm)

        if (baselineYaw < BASELINE_FRAMES) {
            if (matYaw != null) blYawMatrix.add(matYaw)
            blYawLandmark.add(lmYaw)
            baselineYaw++
            if (baselineYaw == BASELINE_FRAMES) {
                neutralYawMatrix   = blYawMatrix.medianOrNull()
                neutralYawLandmark = blYawLandmark.median()
            }
            return false
        }

        val matD = matYaw?.let { it - (neutralYawMatrix ?: 0f) }
        val lmD  = lmYaw - (neutralYawLandmark ?: 0f)

        val detected = if (!turnDetectedLatch) {
            val matOk = matD?.let {
                if (left) it >= YAW_THRESHOLD_DEG else it <= -YAW_THRESHOLD_DEG
            } ?: false

            val lmOk = if (matYaw == null) {
                if (left) lmD <= -LANDMARK_TURN_THRESHOLD
                else      lmD >= LANDMARK_TURN_THRESHOLD
            } else {
                false
            }

            android.util.Log.v(TAG, "turn detail: matOk=$matOk lmOk=$lmOk")

            val hit = matOk || lmOk
            if (hit) turnDetectedLatch = true
            hit
        } else {
            val back = (matD?.let { abs(it) < YAW_RELEASE_DEG } ?: true) &&
                    abs(lmD) < LANDMARK_TURN_RELEASE
            if (back) { turnDetectedLatch = false; false } else true
        }

        android.util.Log.v(TAG,
            "turn: left=$left matD=${fmt(matD)} lmD=${"%.4f".format(lmD)} det=$detected")
        return detected
    }

    private fun matrixYaw(r: FaceLandmarkerResult): Float? {
        val opt = r.facialTransformationMatrixes()
        if (opt == null || !opt.isPresent) return null
        val mats = opt.get(); if (mats.isEmpty()) return null
        val m = mats[0]; if (m.size < 3) return null
        return Math.toDegrees(asin(-m[2].toDouble().coerceIn(-1.0, 1.0))).toFloat()
    }

    private fun landmarkYaw(lm: List<NormalizedLandmark>): Float {
        val lx = lm[234].x(); val rx = lm[454].x()
        val w  = abs(rx - lx).coerceAtLeast(1e-6f)
        return (lm[1].x() - (lx + rx) / 2f) / w
    }

    // ═══════════════════════════════════════════
    //  MOUTH OPEN
    // ═══════════════════════════════════════════

    private fun detectMouthOpen(lm: List<NormalizedLandmark>, r: FaceLandmarkerResult): Boolean {
        val jawBlend = livenessService.getBlendshapeScore("jawOpen", r) ?: 0f

        val sL = livenessService.getBlendshapeScore("mouthSmileLeft", r) ?: 0f
        val sR = livenessService.getBlendshapeScore("mouthSmileRight", r) ?: 0f
        if ((sL + sR) / 2f >= SMILE_SUPPRESSES_MOUTH_BLEND) return false

        val gap   = dist(lm[13], lm[14])
        val fH    = dist(lm[10], lm[152]).coerceAtLeast(1e-6f)
        val ratio = gap / fH

        if (baselineMouth < BASELINE_FRAMES) {
            blMouth.add(ratio); baselineMouth++
            if (baselineMouth == BASELINE_FRAMES) neutralMouth = blMouth.median()
            return false
        }

        val delta = ratio - (neutralMouth ?: 0f)
        val det   = jawBlend >= JAW_OPEN_BLEND_THRESHOLD || delta >= MOUTH_OPEN_THRESHOLD

        android.util.Log.v(TAG,
            "mouth: delta=${"%.3f".format(delta)} jaw=${"%.3f".format(jawBlend)} det=$det")
        return det
    }

    // ═══════════════════════════════════════════
    //  SMILE
    // ═══════════════════════════════════════════

    private fun detectSmile(lm: List<NormalizedLandmark>, r: FaceLandmarkerResult): Boolean {
        val jaw = livenessService.getBlendshapeScore("jawOpen", r) ?: 0f
        if (jaw >= MOUTH_SUPPRESSES_SMILE_BLEND) return false

        val sL     = livenessService.getBlendshapeScore("mouthSmileLeft", r) ?: 0f
        val sR     = livenessService.getBlendshapeScore("mouthSmileRight", r) ?: 0f
        val sBlend = (sL + sR) / 2f

        val fH = dist(lm[10], lm[152]).coerceAtLeast(1e-6f)
        val fW = dist(lm[234], lm[454]).coerceAtLeast(1e-6f)

        val cornerY = (lm[61].y() + lm[291].y()) / 2f
        val lift    = (lm[0].y() - cornerY) / fH
        val width   = dist(lm[61], lm[291]) / fW

        if (baselineSmile < BASELINE_FRAMES) {
            blSmileLift.add(lift); blSmileWidth.add(width); baselineSmile++
            if (baselineSmile == BASELINE_FRAMES) {
                neutralSmileLift  = blSmileLift.median()
                neutralSmileWidth = blSmileWidth.median()
            }
            return false
        }

        val liftD  = lift  - (neutralSmileLift  ?: 0f)
        val widthD = width - (neutralSmileWidth ?: 0f)

        val det = sBlend >= SMILE_BLEND_THRESHOLD ||
                (widthD >= SMILE_WIDTH_THRESHOLD && liftD >= SMILE_LIFT_THRESHOLD)

        android.util.Log.v(TAG,
            "smile: blend=${"%.3f".format(sBlend)} liftD=${"%.3f".format(liftD)} " +
                    "widthD=${"%.3f".format(widthD)} det=$det")
        return det
    }

    // ═══════════════════════════════════════════
    //  Utils
    // ═══════════════════════════════════════════

    private fun List<Float>.median(): Float {
        val s = sorted(); val m = s.size / 2
        return if (s.size % 2 == 0) (s[m-1] + s[m]) / 2f else s[m]
    }
    private fun List<Float>.medianOrNull(): Float? = if (isEmpty()) null else median()
    private fun fmt(v: Float?): String = v?.let { "%.3f".format(it) } ?: "null"

    private fun dist(a: NormalizedLandmark, b: NormalizedLandmark): Float {
        val dx = a.x()-b.x(); val dy = a.y()-b.y(); return sqrt(dx*dx+dy*dy)
    }

    /**
     * Returns rPPG evaluation computed from collected forehead samples, or null
     * if insufficient data is available.
     */
    fun getRppgResult(): PassiveLivenessService.RppgResult? {
        val minSamples = 6
        val times = rppgSampleTimes
        if (rppgSamples.size < minSamples || times.size < 2) {
            return null
        }

        val durationMs = (times.last() - times.first()).coerceAtLeast(1L)
        val fps = (((rppgSamples.size - 1) * 1000) / durationMs).coerceAtLeast(1).toInt()

        // require at least ~2.5 seconds of data for a stable rPPG estimate
        val effectiveMinDuration = 2500L
        if (durationMs < effectiveMinDuration) {
            return null
        }
        // require at least fps * POS_WINDOW_SECONDS (approx) samples for frequency resolution
        val requiredSamples = (fps * 3.0).toInt().coerceAtLeast(minSamples)
        if (rppgSamples.size < requiredSamples) {
            return null
        }

        // Try to find the best contiguous frontal segment using a sliding window
        val windowSize = requiredSamples
        if (rppgSamples.size < windowSize) {
            return null
        }

        var bestResult: PassiveLivenessService.RppgResult? = null

        for (start in 0..(rppgSamples.size - windowSize)) {
            val end = start + windowSize
            val windowTimes = times.subList(start, end)

            // check for large gaps inside window
            var hasLargeGap = false
            for (i in 1 until windowTimes.size) {
                if (windowTimes[i] - windowTimes[i - 1] > RPPG_MAX_GAP_MS) { hasLargeGap = true; break }
            }
            if (hasLargeGap) continue

            val durationWindow = (windowTimes.last() - windowTimes.first()).coerceAtLeast(1L)
            if (durationWindow < effectiveMinDuration) continue

            val windowSamples = rppgSamples.subList(start, end)
            val windowFps = (((windowSamples.size - 1) * 1000) / durationWindow).coerceAtLeast(1).toInt()

            try {
                val res = passiveLivenessService.evaluateRppg(windowSamples, windowFps)
                // prefer a passing result; otherwise keep the highest-SNR candidate
                if (res.passed) return res
                if (bestResult == null || res.snr > bestResult.snr) bestResult = res
            } catch (_: Exception) {
            }
        }

        // return best candidate (may be not passed) to surface diagnostics
        if (bestResult != null) return bestResult
        return null
    }
}