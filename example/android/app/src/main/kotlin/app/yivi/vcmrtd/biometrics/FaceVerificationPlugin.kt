package foundation.privacybydesign.vcmrtd.biometrics

import android.content.Context
import android.graphics.Bitmap
import android.os.SystemClock
import foundation.privacybydesign.vcmrtd.ImageUtil
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicReference

class FaceVerificationPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private var engine: FaceVerificationEngine? = null
    private var livenessService: LivenessService? = null
    private var passiveLivenessService: PassiveLivenessService? = null
    private var activeLivenessService: ActiveLivenessService? = null
    private var appContext: Context? = null

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val initMutex = Mutex()
    private val activeFlowMutex = Mutex()

    private var eventSink: EventChannel.EventSink? = null

    companion object {
        private const val METHOD_CHANNEL = "foundation.privacybydesign.vcmrtd/face_verification"
        private const val EVENT_CHANNEL  = "foundation.privacybydesign.vcmrtd/liveness_events"
        private const val TAG = "FaceVerificationPlugin"

        private const val REQUIRED_ACTIONS      = 3
        private const val ACTIONS_NEEDED_TO_PASS = 2
        private const val ACTION_TIMEOUT_FRAMES  = 150
    }

    private var activeRunId = 0
    private var sessionFinished = true
    private var sessionStopping = false

    private var pendingActions       = mutableListOf<ActiveLivenessService.LivenessAction>()
    private var completedCount       = 0
    private var currentActionIndex   = 0
    private var extraActionMode      = false
    private var framesSinceLastAction = 0
    private var nfcImageForMatch: ByteArray? = null
    private var firstFrameDeferred: CompletableDeferred<Bitmap>? = null
    private var matchScoreResult: Double? = null
    private var faceMatchJob: Job? = null

    @Volatile private var isShuttingDown = false

    private val latestFrameData = AtomicReference<ByteArray?>(null)
    private var frameLoopJob: Job? = null

    @Volatile private var latestFrameReceivedMs = 0L

    private var decodeArgbBuffer: IntArray? = null
    private var decodeBufferWidth  = 0
    private var decodeBufferHeight = 0

    private var sessionStartMs = 0L

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        android.util.Log.d(TAG, "onAttachedToEngine")
        isShuttingDown = false
        appContext = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) { eventSink = sink }
            override fun onCancel(arguments: Any?) { eventSink = null }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        android.util.Log.d(TAG, "onDetachedFromEngine")
        isShuttingDown = true

        scope.launch { stopActiveRun() }

        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        scope.cancel()

        try { engine?.close() } catch (_: Exception) {}
        try { passiveLivenessService?.close() } catch (_: Exception) {}
        try { livenessService?.close() } catch (_: Exception) {}

        engine = null; passiveLivenessService = null
        activeLivenessService = null; livenessService = null
        appContext = null; eventSink = null
        decodeArgbBuffer = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "verifyFace"          -> handleVerifyFace(call, result)
            "startActiveLiveness" -> handleStartActiveLiveness(call, result)
            "processFrame"        -> handleProcessFrame(call, result)
            "stopActiveLiveness"  -> handleStopActiveLiveness(result)
            else                  -> result.notImplemented()
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  Start / Stop
    // ═══════════════════════════════════════════════════════════

    private fun handleStopActiveLiveness(result: MethodChannel.Result) {
        scope.launch {
            try { stopActiveRun(); result.success(null) }
            catch (e: Exception) { result.error("ERROR", e.message, null) }
        }
    }

    private suspend fun stopActiveRun() {
        frameLoopJob?.cancel(); frameLoopJob = null
        latestFrameData.set(null)

        activeFlowMutex.withLock {
            sessionStopping = true; sessionFinished = true; activeRunId++

            try { faceMatchJob?.cancel() } catch (_: Exception) {}
            faceMatchJob = null

            firstFrameDeferred?.let { if (!it.isCompleted) it.cancel() }
            firstFrameDeferred = null

            pendingActions.clear(); completedCount = 0; currentActionIndex = 0
            extraActionMode = false; framesSinceLastAction = 0
            nfcImageForMatch = null; matchScoreResult = null

            try { activeLivenessService?.reset() } catch (_: Exception) {}
            sessionStopping = false
        }
    }

    private suspend fun initServices(ctx: Context) {
        initMutex.withLock {
            if (engine != null && livenessService != null &&
                passiveLivenessService != null && activeLivenessService != null) return

            val e  = FaceVerificationEngine(ctx).also { it.initialize() }
            val ls = LivenessService(ctx).also { it.initialize() }
            val ps = PassiveLivenessService(ctx, ls).also { it.initialize() }
            val als = ActiveLivenessService(ls, ps)

            engine = e; livenessService = ls
            passiveLivenessService = ps; activeLivenessService = als
        }
    }

    private fun handleStartActiveLiveness(call: MethodCall, result: MethodChannel.Result) {
        val nfcImageBytes = call.argument<ByteArray>("nfcImage")
        if (nfcImageBytes == null || nfcImageBytes.isEmpty()) {
            result.error("INVALID_ARGS", "nfcImage is required", null); return
        }

        scope.launch {
            try {
                val ctx = appContext ?: throw IllegalStateException("Plugin not attached")
                withContext(Dispatchers.IO) { initServices(ctx) }

                val runId = resetActiveLivenessState(nfcImageBytes)

                val currentActions = activeFlowMutex.withLock { pendingActions.toList() }
                val deferred = activeFlowMutex.withLock { firstFrameDeferred }
                    ?: throw IllegalStateException("Session not initialized")
                val nfc = activeFlowMutex.withLock { nfcImageForMatch }
                    ?: throw IllegalStateException("NFC image failed")
                val localEngine   = engine               ?: throw IllegalStateException("Engine unavailable")
                val activeService = activeLivenessService ?: throw IllegalStateException("ActiveLivenessService unavailable")

                faceMatchJob?.cancel()
                faceMatchJob = scope.launch(Dispatchers.IO) {
                    var bmp: Bitmap? = null
                    try {
                        bmp = deferred.await()
                        if (isShuttingDown) return@launch

                        val jpeg  = bitmapToJpeg(bmp, 95)
                        val score = localEngine.verify(nfc, jpeg)

                        activeFlowMutex.withLock {
                            if (runId == activeRunId && !isShuttingDown) {
                                matchScoreResult = score.toDouble()
                            }
                        }
                    } catch (_: CancellationException) { return@launch }
                    catch (e: Exception) {
                        activeFlowMutex.withLock {
                            if (runId == activeRunId && !isShuttingDown) {
                                android.util.Log.e(TAG, "Face match error", e)
                                matchScoreResult = 0.0
                            }
                        }
                    } finally {
                        if (bmp != null && !bmp.isRecycled) bmp.recycle()
                    }
                }

                // startAction is called by the alignment phase once the face is
                // stable in frame (see processFrameInternal alignment block).
                startFrameLoop(runId)

                android.util.Log.d(TAG, "Active liveness started: $currentActions")
                result.success(currentActions.map { it.name })
            } catch (e: Exception) {
                android.util.Log.e(TAG, "startActiveLiveness error", e)
                result.error("ERROR", e.message, null)
            }
        }
    }

    private suspend fun resetActiveLivenessState(nfcImageBytes: ByteArray): Int {
        frameLoopJob?.cancel(); frameLoopJob = null
        latestFrameData.set(null)

        return activeFlowMutex.withLock {
            stopActiveRunInternalLocked()
            activeRunId++
            sessionFinished = false; sessionStopping = false
            sessionStartMs = SystemClock.elapsedRealtime()

            pendingActions = ActiveLivenessService.ALL_ACTIONS
                .shuffled().take(REQUIRED_ACTIONS).toMutableList()

            completedCount = 0; currentActionIndex = 0
            extraActionMode = false; framesSinceLastAction = 0
            nfcImageForMatch = prepareNfcImage(nfcImageBytes)
            firstFrameDeferred = CompletableDeferred()
            matchScoreResult = null

            activeRunId
        }
    }

    private fun stopActiveRunInternalLocked() {
        sessionFinished = true; sessionStopping = true

        try { faceMatchJob?.cancel() } catch (_: Exception) {}
        faceMatchJob = null

        firstFrameDeferred?.let { if (!it.isCompleted) it.cancel() }
        firstFrameDeferred = null

        pendingActions.clear(); completedCount = 0; currentActionIndex = 0
        extraActionMode = false; framesSinceLastAction = 0
        nfcImageForMatch = null; matchScoreResult = null

        try { activeLivenessService?.reset() } catch (_: Exception) {}
        sessionStopping = false
    }

    // ═══════════════════════════════════════════════════════════
    //  Frame processing
    // ═══════════════════════════════════════════════════════════

    private fun startFrameLoop(runId: Int) {
        frameLoopJob?.cancel()
        frameLoopJob = scope.launch(Dispatchers.IO) {
            android.util.Log.d(TAG, "Frame loop started (runId=$runId)")

            while (isActive && !isShuttingDown) {
                val active = activeFlowMutex.withLock {
                    !sessionFinished && !sessionStopping && runId == activeRunId
                }
                if (!active) break

                val data = latestFrameData.getAndSet(null)
                if (data == null) { delay(8); continue }

                try {
                    processFrameInternal(runId, data)
                } catch (_: CancellationException) {
                    break
                } catch (e: Exception) {
                    android.util.Log.e(TAG, "Frame loop error", e)
                    abortActiveRun(runId, "Liveness processing failed. Please try again.")
                    break
                }
            }

            android.util.Log.d(TAG, "Frame loop ended (runId=$runId)")
        }
    }

    private fun handleProcessFrame(call: MethodCall, result: MethodChannel.Result) {
        val data = call.argument<ByteArray>("frame")
        if (data == null || data.isEmpty()) {
            result.error("INVALID_ARGS", "frame is required", null); return
        }
        if (!isShuttingDown && !sessionFinished && !sessionStopping) {
            latestFrameData.set(data)
            latestFrameReceivedMs = SystemClock.elapsedRealtime()
        }
        result.success(null)
    }

    private suspend fun processFrameInternal(runId: Int, data: ByteArray) {
        if (isShuttingDown) return

        val pickupMs  = SystemClock.elapsedRealtime()
        val waitMs    = pickupMs - latestFrameReceivedMs
        val decodeStartMs = SystemClock.elapsedRealtime()
        val bitmap    = decodeNv21Frame(data) ?: return
        val decodeMs  = SystemClock.elapsedRealtime() - decodeStartMs

        try {
            activeFlowMutex.withLock {
                if (isShuttingDown || sessionFinished || sessionStopping || runId != activeRunId) return@withLock
                if (currentActionIndex >= pendingActions.size) return@withLock

                framesSinceLastAction++

                val service = activeLivenessService
                    ?: throw IllegalStateException("ActiveLivenessService unavailable")

                // ── Alignment phase ──
                // Delegated entirely to ActiveLivenessService — it owns isAligning,
                // accumulates measurements, and calls startAction internally once ready.
                if (service.isAligning) {
                    val timedOut = framesSinceLastAction > ACTION_TIMEOUT_FRAMES
                    val done = service.processAlignmentFrame(
                        bitmap, pendingActions[currentActionIndex], timedOut
                    )
                    if (done) {
                        framesSinceLastAction = 0
                        val deferred = firstFrameDeferred
                        if (deferred != null && !deferred.isCompleted) {
                            deferred.complete(bitmap.copy(bitmap.config ?: Bitmap.Config.ARGB_8888, false))
                        }
                        sendEvent(runId, mapOf("type" to "nextAction",
                            "action" to pendingActions[currentActionIndex].name))
                    }
                    return@withLock
                }

                if (framesSinceLastAction > ACTION_TIMEOUT_FRAMES) {
                    handleTimeoutLocked(runId); return@withLock
                }

                val detectStartMs = SystemClock.elapsedRealtime()
                val actionDone    = service.processFrame(bitmap)
                val detectMs      = SystemClock.elapsedRealtime() - detectStartMs
                val totalMs       = SystemClock.elapsedRealtime() - latestFrameReceivedMs

                android.util.Log.d(TAG,
                    "⏱ wait=${waitMs}ms decode=${decodeMs}ms detect=${detectMs}ms total=${totalMs}ms")

                val deferred = firstFrameDeferred
                if (deferred != null && !deferred.isCompleted ) {
                    deferred.complete(bitmap.copy(bitmap.config ?: Bitmap.Config.ARGB_8888, false))
                }

                if (!actionDone) return@withLock

                val completed = pendingActions[currentActionIndex]
                completedCount++; currentActionIndex++; framesSinceLastAction = 0

                android.util.Log.d(TAG,
                    "Action $completed done — $completedCount completed, index=$currentActionIndex/${pendingActions.size}")

                sendEvent(runId, mapOf("type" to "actionDetected", "action" to completed.name))

                if (currentActionIndex >= pendingActions.size) {
                    if (shouldStartExtra()) { startExtraLocked(runId); return@withLock }
                    val passed = if (extraActionMode) completedCount >= ACTIONS_NEEDED_TO_PASS + 1
                    else completedCount >= REQUIRED_ACTIONS
                    finishSessionLocked(runId, passed); return@withLock
                }

                val next = pendingActions[currentActionIndex]
                service.queueNextAction(next) // queue with rest-phase baseline instead of starting immediately
                sendEvent(runId, mapOf("type" to "nextAction", "action" to next.name))
            }
        } finally {
            if (!bitmap.isRecycled) bitmap.recycle()
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  Timeout / Extra / Finish
    // ═══════════════════════════════════════════════════════════

    private suspend fun handleTimeoutLocked(runId: Int) {
        val timedOut = pendingActions.getOrNull(currentActionIndex)
        android.util.Log.w(TAG, "Timeout after $framesSinceLastAction frames")
        framesSinceLastAction = 0

        sendEvent(runId, mapOf("type" to "timeout", "action" to timedOut?.name))
        currentActionIndex++

        if (currentActionIndex >= pendingActions.size) {
            if (shouldStartExtra()) { startExtraLocked(runId); return }
            val passed = if (extraActionMode) completedCount >= ACTIONS_NEEDED_TO_PASS + 1
            else completedCount >= REQUIRED_ACTIONS
            finishSessionLocked(runId, passed); return
        }

        val service = activeLivenessService ?: throw IllegalStateException("ActiveLivenessService unavailable")
        val next = pendingActions[currentActionIndex]
        service.startAction(next)
        sendEvent(runId, mapOf("type" to "nextAction", "action" to next.name))
    }

    private fun shouldStartExtra(): Boolean =
        !extraActionMode &&
                pendingActions.size == REQUIRED_ACTIONS &&
                currentActionIndex >= REQUIRED_ACTIONS &&
                completedCount == ACTIONS_NEEDED_TO_PASS

    private suspend fun startExtraLocked(runId: Int) {
        val service = activeLivenessService ?: throw IllegalStateException("ActiveLivenessService unavailable")
        val extra = ActiveLivenessService.ALL_ACTIONS
            .filter { it !in pendingActions }.randomOrNull()
            ?: ActiveLivenessService.ALL_ACTIONS.random()

        pendingActions.add(extra)
        extraActionMode = true; framesSinceLastAction = 0
        service.startAction(extra)
        sendEvent(runId, mapOf("type" to "extraAction", "action" to extra.name))
    }

    private fun finishSessionLocked(runId: Int, passed: Boolean) {
        if (sessionFinished || sessionStopping || runId != activeRunId) return
        sessionFinished = true

        frameLoopJob?.cancel(); frameLoopJob = null
        latestFrameData.set(null)

        sendEvent(runId, mapOf("type" to "processing"))

        scope.launch(Dispatchers.IO) {
            var score = 0.0
            try {
                while (isActive && !isShuttingDown) {
                    val s = activeFlowMutex.withLock {
                        if (runId != activeRunId || sessionStopping) return@launch
                        matchScoreResult
                    }
                    if (s != null) { score = s; break }
                    delay(50)
                }
            } catch (_: CancellationException) { return@launch }

            val antiSpoofScore    = passiveLivenessService?.getAntiSpoofScore()
            val antiSpoofPassed   = passiveLivenessService?.isAntiSpoofPassed() ?: true
            val totalFrames       = passiveLivenessService?.getTotalFrames() ?: 0
            val antiSpoofAttempts = passiveLivenessService?.getAntiSpoofAttempts() ?: 0
            val sessionDurationMs = SystemClock.elapsedRealtime() - sessionStartMs

            val rppgResult = passiveLivenessService?.getRppgResult()
            val rppgPassed = rppgResult?.passed ?: false

            val finalPassed = passed && antiSpoofPassed && rppgPassed


            val shouldSend = activeFlowMutex.withLock {
                runId == activeRunId && !isShuttingDown && !sessionStopping
            }

            if (shouldSend) {
                android.util.Log.d(TAG,
                    "✅ SESSION RESULT: livenessPassed=$passed antiSpoofPassed=$antiSpoofPassed rppgPassed=$rppgPassed " +
                            "finalPassed=$finalPassed matchScore=$score " +
                            "antiSpoofScore=$antiSpoofScore actions=$completedCount " +
                            "duration=${sessionDurationMs}ms frames=$totalFrames " +
                            "antiSpoofAttempts=$antiSpoofAttempts " +
                            "effectiveFps=${"%.1f".format(totalFrames / (sessionDurationMs / 1000.0))}")
                sendEvent(runId, mapOf(
                    "type"            to "complete",
                    "passed"          to finalPassed,
                    "matchScore"      to score,
                    "antiSpoofScore"  to antiSpoofScore,
                    "antiSpoofPassed" to antiSpoofPassed,
                    "rppg"            to mapOf(
                        "hr" to rppgResult?.hr,
                        "snr" to rppgResult?.snr,
                        "harmonicsOk" to rppgResult?.harmonicsOk,
                        "passed" to rppgResult?.passed,
                        "sampleCount" to rppgResult?.sampleCount,
                        "durationMs" to rppgResult?.durationMs
                    ),
                ))
            }

            activeFlowMutex.withLock {
                if (runId == activeRunId) {
                    pendingActions.clear(); currentActionIndex = 0
                    completedCount = 0; extraActionMode = false
                    framesSinceLastAction = 0; nfcImageForMatch = null
                    matchScoreResult = null; firstFrameDeferred = null
                    faceMatchJob = null
                    try { activeLivenessService?.reset() } catch (_: Exception) {}
                }
            }
        }
    }

    private suspend fun abortActiveRun(runId: Int, message: String) {
        frameLoopJob?.cancel(); frameLoopJob = null
        latestFrameData.set(null)

        val shouldNotify = activeFlowMutex.withLock {
            if (runId != activeRunId || sessionStopping) return@withLock false
            sessionStopping = true; sessionFinished = true; activeRunId++

            try { faceMatchJob?.cancel() } catch (_: Exception) {}
            faceMatchJob = null

            firstFrameDeferred?.let { if (!it.isCompleted) it.cancel() }
            firstFrameDeferred = null

            pendingActions.clear(); completedCount = 0; currentActionIndex = 0
            extraActionMode = false; framesSinceLastAction = 0
            nfcImageForMatch = null; matchScoreResult = null

            try { activeLivenessService?.reset() } catch (_: Exception) {}
            sessionStopping = false
            true
        }

        if (shouldNotify) sendTerminalError(message)
    }

    // ═══════════════════════════════════════════════════════════
    //  NV21 decode
    // ═══════════════════════════════════════════════════════════

    private fun decodeNv21Frame(data: ByteArray): Bitmap? {
        if (data.size < 8) return null
        val w = ((data[0].toInt() and 0xFF) shl 24) or ((data[1].toInt() and 0xFF) shl 16) or
                ((data[2].toInt() and 0xFF) shl 8)  or  (data[3].toInt() and 0xFF)
        val h = ((data[4].toInt() and 0xFF) shl 24) or ((data[5].toInt() and 0xFF) shl 16) or
                ((data[6].toInt() and 0xFF) shl 8)  or  (data[7].toInt() and 0xFF)

        val expected = w * h + w * h / 2
        if (w <= 0 || h <= 0 || data.size - 8 < expected) return null

        val needed = w * h
        if (decodeArgbBuffer == null || decodeBufferWidth != w || decodeBufferHeight != h) {
            decodeArgbBuffer = IntArray(needed)
            decodeBufferWidth = w; decodeBufferHeight = h
        }
        val argb = decodeArgbBuffer!!
        nv21ToArgb(data, 8, w, h, argb)
        return Bitmap.createBitmap(argb, w, h, Bitmap.Config.ARGB_8888)
    }

    private fun nv21ToArgb(src: ByteArray, off: Int, w: Int, h: Int, out: IntArray) {
        val frameSize = w * h
        val uvStart   = off + frameSize
        var yp        = off

        for (j in 0 until h) {
            val uvp = uvStart + (j shr 1) * w
            var u = 0; var v = 0

            for (i in 0 until w) {
                val y = (src[yp].toInt() and 0xFF) - 16
                if ((i and 1) == 0) {
                    v = (src[uvp + i].toInt()     and 0xFF) - 128
                    u = (src[uvp + i + 1].toInt() and 0xFF) - 128
                }
                val y1192 = 1192 * if (y < 0) 0 else y
                var r = y1192 + 1634 * v
                var g = y1192 - 833  * v - 400 * u
                var b = y1192 + 2066 * u

                r = r.coerceIn(0, 262143); g = g.coerceIn(0, 262143); b = b.coerceIn(0, 262143)

                out[j * w + i] = -0x1000000 or
                        ((r shl 6)  and 0x00FF0000) or
                        ((g shr 2)  and 0x0000FF00) or
                        ((b shr 10) and 0x000000FF)
                yp++
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  Events
    // ═══════════════════════════════════════════════════════════

    private fun sendEvent(runId: Int, data: Map<String, Any?>) {
        if (isShuttingDown) return
        scope.launch(Dispatchers.Main) {
            if (isShuttingDown) return@launch
            val ok = activeFlowMutex.withLock { runId == activeRunId && !sessionStopping }
            if (!ok) return@launch
            try { eventSink?.success(data) } catch (_: Exception) {}
        }
    }

    private fun sendTerminalError(message: String) {
        if (isShuttingDown) return
        scope.launch(Dispatchers.Main) {
            if (isShuttingDown) return@launch
            try { eventSink?.success(mapOf("type" to "error", "message" to message)) }
            catch (_: Exception) {}
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  verifyFace (standalone)
    // ═══════════════════════════════════════════════════════════

    private fun handleVerifyFace(call: MethodCall, result: MethodChannel.Result) {
        val nfc    = call.argument<ByteArray>("nfcImage")
        val selfie = call.argument<ByteArray>("selfieImage")
        if (nfc == null || selfie == null) {
            result.error("INVALID_ARGS", "nfcImage and selfieImage required", null); return
        }

        scope.launch {
            try {
                val ctx = appContext ?: throw IllegalStateException("Plugin not attached")
                val score = withContext(Dispatchers.IO) {
                    initServices(ctx)
                    engine!!.verify(prepareNfcImage(nfc), selfie)
                }
                result.success(mapOf("matchScore" to score.toDouble()))
            } catch (e: IllegalStateException) { result.error("NO_FACE", e.message, null) }
            catch (e: Exception) { result.error("ERROR", e.message, null) }
        }
    }

    private fun bitmapToJpeg(bmp: Bitmap, quality: Int = 95): ByteArray {
        val baos = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.JPEG, quality, baos)
        return baos.toByteArray()
    }

    private fun prepareNfcImage(bytes: ByteArray): ByteArray {
        if (!isJP2(bytes)) return bytes
        val bmp  = ImageUtil.decodeImage(null, "image/jp2", bytes.inputStream())
        val baos = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.JPEG, 100, baos)
        if (!bmp.isRecycled) bmp.recycle()
        return baos.toByteArray()
    }

    private fun isJP2(b: ByteArray): Boolean =
        b.size > 4 && b[0] == 0x00.toByte() && b[1] == 0x00.toByte() &&
                b[2] == 0x00.toByte() && b[3] == 0x0C.toByte()
}