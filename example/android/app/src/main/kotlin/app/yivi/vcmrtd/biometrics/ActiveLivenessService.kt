package foundation.privacybydesign.vcmrtd.biometrics

import android.graphics.Bitmap
import android.os.SystemClock
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import kotlin.math.abs
import kotlin.math.sqrt

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

        val ALL_ACTIONS = listOf(
            LivenessAction.BLINK,
            LivenessAction.TURN_LEFT,
            LivenessAction.TURN_RIGHT,
            LivenessAction.MOUTH_OPEN,
            LivenessAction.SMILE,
        )
    }

    enum class LivenessAction { BLINK, TURN_LEFT, TURN_RIGHT, MOUTH_OPEN, SMILE }

    /**
     * Neutral-face measurements captured on a confirmed-neutral face.
     * Passed to [startAction] to skip the in-action baseline warmup and
     * start detecting immediately.
     */
    data class BaselineSnapshot(
        val yawMatrix: Float?,
        val yawLandmark: Float,
        val mouth: Float,
        val smileLift: Float,
        val smileWidth: Float
    )

    /**
     * Accumulates per-frame neutral-face measurements and computes a
     * [BaselineSnapshot] from their medians. Used for both the rest phase
     * (between actions) and the alignment phase (before the first action).
     */
    private inner class BaselineAccumulator {
        private val yawMatrix   = mutableListOf<Float>()
        private val yawLandmark = mutableListOf<Float>()
        private val mouth       = mutableListOf<Float>()
        private val smileLift   = mutableListOf<Float>()
        private val smileWidth  = mutableListOf<Float>()

        /** Number of frames accumulated so far. */
        val size: Int get() = yawLandmark.size

        /** Add measurements from one stable neutral-face frame. */
        fun add(lm: List<NormalizedLandmark>, r: FaceLandmarkerResult) {
            val fH      = dist(lm[10], lm[152]).coerceAtLeast(1e-6f)
            val fW      = dist(lm[234], lm[454]).coerceAtLeast(1e-6f)
            val cornerY = (lm[61].y() + lm[291].y()) / 2f
            val matYaw  = livenessService.matrixYaw(r)
            if (matYaw != null) yawMatrix.add(matYaw)
            yawLandmark.add(landmarkYaw(lm))
            mouth.add(dist(lm[13], lm[14]) / fH)
            smileLift.add((lm[0].y() - cornerY) / fH)
            smileWidth.add(dist(lm[61], lm[291]) / fW)
        }

        fun clear() {
            yawMatrix.clear(); yawLandmark.clear()
            mouth.clear(); smileLift.clear(); smileWidth.clear()
        }

        fun computeSnapshot(): BaselineSnapshot = BaselineSnapshot(
            yawMatrix   = yawMatrix.medianOrNull(),
            yawLandmark = yawLandmark.median(),
            mouth       = mouth.median(),
            smileLift   = smileLift.median(),
            smileWidth  = smileWidth.median()
        )
    }

    private enum class BlinkPhase { OPEN, CLOSING, CLOSED, DETECTED }

    // True until the first action starts; managed entirely by this class.
    var isAligning: Boolean = true
        private set

    private var currentAction: LivenessAction? = null
    private var confirmCount = 0
    private var blinkPhase = BlinkPhase.OPEN
    private var blinkClosedFrames = 0

    private var neutralYawMatrix: Float? = null
    private var neutralYawLandmark: Float? = null
    private var neutralMouth: Float? = null
    private var neutralSmileLift: Float? = null
    private var neutralSmileWidth: Float? = null

    private val actionAccumulator   = BaselineAccumulator()
    private var actionBaselineReady = false

    private var turnDetectedLatch = false

    // ── Rest face state ──
    // After an action completes we wait for the face to return to a neutral
    // position before starting the next action. This prevents spurious
    // detections while the user is still moving.
    private var waitingForRest = false
    private var nextActionQueued: LivenessAction? = null
    private var restStableCount = 0

    // Accumulates stable-frame measurements during the rest phase so the next
    // action can start with a pre-loaded baseline (no in-action warmup delay).
    private val restAccumulator  = BaselineAccumulator()
    // Accumulates stable-frame measurements during the pre-session alignment
    // phase to build a baseline for the first action.
    private val alignAccumulator = BaselineAccumulator()

    fun startAction(action: LivenessAction, baseline: BaselineSnapshot? = null) {
        isAligning = false
        currentAction = action
        confirmCount = 0
        blinkPhase = BlinkPhase.OPEN
        blinkClosedFrames = 0
        turnDetectedLatch = false
        waitingForRest = false
        nextActionQueued = null
        restStableCount = 0

        restAccumulator.clear()
        actionAccumulator.clear()

        neutralYawMatrix = null; neutralYawLandmark = null
        neutralMouth = null; neutralSmileLift = null; neutralSmileWidth = null

        if (baseline != null) {
            // Pre-load the neutral baseline — no in-action warmup needed.
            when (action) {
                LivenessAction.TURN_LEFT, LivenessAction.TURN_RIGHT -> {
                    neutralYawMatrix   = baseline.yawMatrix
                    neutralYawLandmark = baseline.yawLandmark
                }
                LivenessAction.MOUTH_OPEN -> neutralMouth = baseline.mouth
                LivenessAction.SMILE -> {
                    neutralSmileLift  = baseline.smileLift
                    neutralSmileWidth = baseline.smileWidth
                }
                else -> {}
            }
            actionBaselineReady = true
            android.util.Log.d(TAG, "startAction $action with preloaded baseline " +
                "(yawMatrix=${baseline.yawMatrix}, yawLm=${baseline.yawLandmark}, " +
                "mouth=${baseline.mouth})")
        } else {
            actionBaselineReady = false
        }
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
        restAccumulator.clear()
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
        actionBaselineReady = false

        restAccumulator.clear()
        actionAccumulator.clear()
        alignAccumulator.clear()
        isAligning = true

        passiveLivenessService.reset()
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

            val lm = result.faceLandmarks()[0]

            // Delegate passive liveness metrics (anti-spoof + rPPG) to PassiveLivenessService.
            passiveLivenessService.collectPassiveMetrics(argb, result)

            // ── Rest face check ──
            // If we're waiting for a neutral face before the next action,
            // check rest state and start the queued action once stable.
            // While stable, also collect baseline measurements so the next
            // action can start with a pre-loaded baseline (no warmup delay).
            if (waitingForRest) {
                val isRest = isFaceAtRest(lm, result)
                if (isRest) {
                    restStableCount++
                    restAccumulator.add(lm, result)
                    android.util.Log.d(TAG, "Rest face stable: $restStableCount/$REST_STABLE_FRAMES")
                } else {
                    restStableCount = 0
                    restAccumulator.clear()
                }

                if (restStableCount >= REST_STABLE_FRAMES) {
                    val next = nextActionQueued
                    if (next != null) {
                        android.util.Log.d(TAG, "Rest detected, starting $next with fresh baseline")
                        startAction(next, restAccumulator.computeSnapshot())
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
        // Head facing forward (yaw close to zero)
        val yaw = livenessService.matrixYaw(r)
        if (yaw != null && abs(yaw) > REST_MAX_YAW_DEG) {
            android.util.Log.v(TAG, "rest: yaw=$yaw exceeds limit")
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
        val matYaw = livenessService.matrixYaw(r)
        val lmYaw  = landmarkYaw(lm)

        if (!actionBaselineReady) { accumulateActionBaseline(lm, r); return false }

        val matD = matYaw?.let { it - (neutralYawMatrix ?: 0f) }
        val lmD  = lmYaw - (neutralYawLandmark ?: 0f)
        val detected = isTurnDetected(matYaw, matD, lmD, left)

        android.util.Log.v(TAG,
            "turn: left=$left matD=${fmt(matD)} lmD=${"%.4f".format(lmD)} det=$detected")
        return detected
    }

    private fun isTurnDetected(matYaw: Float?, matD: Float?, lmD: Float, left: Boolean): Boolean {
        return if (!turnDetectedLatch) {
            val matOk = matD?.let {
                if (left) it >= YAW_THRESHOLD_DEG else it <= -YAW_THRESHOLD_DEG
            } ?: false
            val lmOk = matYaw == null && if (left) lmD <= -LANDMARK_TURN_THRESHOLD else lmD >= LANDMARK_TURN_THRESHOLD
            android.util.Log.v(TAG, "turn detail: matOk=$matOk lmOk=$lmOk")
            val hit = matOk || lmOk
            if (hit) turnDetectedLatch = true
            hit
        } else {
            val back = (matD?.let { abs(it) < YAW_RELEASE_DEG } ?: true) && abs(lmD) < LANDMARK_TURN_RELEASE
            if (back) { turnDetectedLatch = false; false } else true
        }
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

        if (!actionBaselineReady) { accumulateActionBaseline(lm, r); return false }

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

        if (!actionBaselineReady) { accumulateActionBaseline(lm, r); return false }

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
    //  Alignment phase
    //  Called each frame before the first action starts.
    //  Manages its own state via isAligning and alignAccumulator.
    // ═══════════════════════════════════════════

    /**
     * Process one frame during the pre-liveness alignment phase.
     *
     * Runs face detection internally and accumulates measurements from stable
     * neutral-face frames. Returns true once the phase is complete — either
     * because [BASELINE_FRAMES] consecutive stable frames were collected (first
     * [action] is started with a preloaded baseline) or because [timedOut] is
     * true (first action is started without a preloaded baseline as a fallback).
     * Returns false while still collecting.
     */
    fun processAlignmentFrame(
        bitmap: Bitmap,
        action: LivenessAction,
        timedOut: Boolean
    ): Boolean {
        if (!isAligning) return false

        if (timedOut) {
            android.util.Log.w(TAG,
                "Alignment timed out after ${alignAccumulator.size} stable frames, " +
                "starting $action without preloaded baseline")
            alignAccumulator.clear()
            startAction(action)   // sets isAligning = false
            return true
        }

        val argb = bitmap.toArgb8888()
        try {
            val result = livenessService.detectImage(argb)
            if (result == null || result.faceLandmarks().isEmpty()) {
                alignAccumulator.clear(); return false
            }
            val lm = result.faceLandmarks()[0]

            if (!isFaceAtRest(lm, result)) {
                alignAccumulator.clear(); return false
            }

            passiveLivenessService.collectPassiveMetrics(argb, result)
            alignAccumulator.add(lm, result)
            android.util.Log.d(TAG, "Alignment stable: ${alignAccumulator.size}/$BASELINE_FRAMES")

            if (alignAccumulator.size >= BASELINE_FRAMES) {
                val snapshot = alignAccumulator.computeSnapshot()
                alignAccumulator.clear()
                startAction(action, snapshot)   // sets isAligning = false
                return true
            }
            return false
        } finally {
            if (argb !== bitmap && !argb.isRecycled) argb.recycle()
        }
    }

    // ═══════════════════════════════════════════
    //  Utils
    // ═══════════════════════════════════════════

    private fun accumulateActionBaseline(lm: List<NormalizedLandmark>, r: FaceLandmarkerResult) {
        actionAccumulator.add(lm, r)
        if (actionAccumulator.size >= BASELINE_FRAMES) {
            val snap = actionAccumulator.computeSnapshot()
            when (currentAction) {
                LivenessAction.TURN_LEFT, LivenessAction.TURN_RIGHT -> {
                    neutralYawMatrix   = snap.yawMatrix
                    neutralYawLandmark = snap.yawLandmark
                }
                LivenessAction.MOUTH_OPEN -> neutralMouth = snap.mouth
                LivenessAction.SMILE -> {
                    neutralSmileLift  = snap.smileLift
                    neutralSmileWidth = snap.smileWidth
                }
                else -> {}
            }
            actionBaselineReady = true
        }
    }

    private fun List<Float>.median(): Float {
        val s = sorted(); val m = s.size / 2
        return if (s.size % 2 == 0) (s[m-1] + s[m]) / 2f else s[m]
    }
    private fun List<Float>.medianOrNull(): Float? = if (isEmpty()) null else median()
    private fun fmt(v: Float?): String = v?.let { "%.3f".format(it) } ?: "null"

    private fun dist(a: NormalizedLandmark, b: NormalizedLandmark): Float {
        val dx = a.x()-b.x(); val dy = a.y()-b.y(); return sqrt(dx*dx+dy*dy)
    }

}