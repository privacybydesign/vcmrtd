package foundation.privacybydesign.vcmrtd.biometrics

import android.content.Context
import android.graphics.Bitmap
import android.os.SystemClock
import android.util.Log
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
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import kotlinx.coroutines.channels.Channel

class FaceVerificationPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private var engine: FaceVerificationEngine? = null
    private var livenessService: LivenessService? = null
    private var passiveLivenessService: PassiveLivenessService? = null
    private var activeLivenessService: ActiveLivenessService? = null
    private var appContext: Context? = null

    private fun newScope() = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var scope = newScope()
    private val initMutex = Mutex()
    private val activeFlowMutex = Mutex()
    private val passiveInFlightLock = Object()

    private var eventSink: EventChannel.EventSink? = null

    companion object {
        private const val TAG = "FaceVerificationPlugin"
        private const val METHOD_CHANNEL = "foundation.privacybydesign.vcmrtd/face_verification"
        private const val EVENT_CHANNEL  = "foundation.privacybydesign.vcmrtd/liveness_events"

        private const val REQUIRED_ACTIONS      = 3
        private const val ACTIONS_NEEDED_TO_PASS = 2
        private const val ACTION_TIMEOUT_FRAMES  = 240

        private const val ERR_ACTIVE_SERVICE   = "ActiveLivenessService unavailable"

        // ITU-R BT.601 YCbCr→RGB matrix coefficients, pre-multiplied by 1024 so
        // the entire conversion uses integer arithmetic (no floats in the pixel loop).
        // The floating-point formula for studio-swing YUV (Y∈[16,235], UV∈[16,240]) is:
        //   R = 1.164*(Y-16)              + 1.596*(V-128)
        //   G = 1.164*(Y-16) - 0.813*(V-128) - 0.391*(U-128)
        //   B = 1.164*(Y-16)              + 2.018*(U-128)
        // Each intermediate R/G/B value is therefore ~1024× the final 8-bit value.
        // The output packing divides by 1024 implicitly via bit shifts (see nv21ToArgb).
        private const val YUV_Y  = 1192  // 1.164 × 1024
        private const val YUV_VR = 1634  // 1.596 × 1024  (V  → R)
        private const val YUV_VG = 833   // 0.813 × 1024  (V  → G, subtracted)
        private const val YUV_UG = 400   // 0.391 × 1024  (U  → G, subtracted)
        private const val YUV_UB = 2066  // 2.018 × 1024  (U  → B)
    }

    private var activeRunId = 0
    @Volatile private var sessionFinished = true
    @Volatile private var sessionStopping = false

    private var pendingActions       = mutableListOf<ActiveLivenessService.LivenessAction>()
    private var completedCount       = 0
    private var currentActionIndex   = 0
    private var extraActionMode      = false
    private var framesSinceLastAction = 0
    private var firstFrameDeferred: CompletableDeferred<Bitmap>? = null
    private var matchScoreDeferred: CompletableDeferred<Double>? = null
    private var faceMatchJob: Job? = null

    @Volatile private var isShuttingDown = false
    @Volatile private var cameraRotationDegrees = 0

    private val frameChannel = Channel<RawFrame>(Channel.CONFLATED)

    // Three-stage pipeline: detector → landmark → passive metrics.
    // Stage 1 (detectorJob):      NV21 decode + BlazeFace.
    // Stage 2 (landmarkJob):      landmarks + blendshapes + action detection.
    // Stage 3 (passiveMetricsJob): MiniFASNet anti-spoof + BigSmall rPPG — runs concurrently
    //                              with stage 1+2 so heavy inference never blocks liveness.
    private data class RawFrame(
        val data: ByteArray,
        val rotationDegrees: Int
    )
    private data class PipelineFrame(
        val bitmap: Bitmap,                                     // recycled by landmark or passive stage
        val crop:   FaceLandmarkPipeline.DetectorStageOutput?,  // null = no face detected
        val runId:  Int
    )
    private data class PassiveFrame(
        val bitmap: Bitmap,           // recycled by passive metrics job
        val result: FaceLandmarkerResult,
        val runId:  Int
    )
    private val detectorOutputChannel = Channel<PipelineFrame>(capacity = 1)
    private val passiveChannel        = Channel<PassiveFrame>(capacity = 1)
    private var detectorJob:      Job? = null
    private var landmarkJob:      Job? = null
    private var passiveMetricsJob: Job? = null
    private var passiveFramesInFlight = 0

    @Volatile private var latestFrameReceivedMs = 0L

    private var decodeArgbBuffer: IntArray? = null
    private var decodeBufferWidth  = 0
    private var decodeBufferHeight = 0

    private var sessionStartMs = 0L

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        if (!scope.isActive) scope = newScope()
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
        isShuttingDown = true

        try { runBlocking { stopActiveRun() } } catch (e: Exception) { Log.w(TAG, "stopActiveRun during detach failed", e) }

        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        scope.cancel()

        try { engine?.close() } catch (e: Exception) { Log.w(TAG, "engine close failed", e) }
        try { passiveLivenessService?.close() } catch (e: Exception) { Log.w(TAG, "passiveLivenessService close failed", e) }
        try { livenessService?.close() } catch (e: Exception) { Log.w(TAG, "livenessService close failed", e) }

        engine = null; passiveLivenessService = null
        activeLivenessService = null; livenessService = null
        appContext = null; eventSink = null
        decodeArgbBuffer = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize"          -> handleInitialize(call, result)
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

    private fun handleInitialize(call: MethodCall, result: MethodChannel.Result) {
        val sensorOrientation = call.argument<Int>("sensorOrientation") ?: 0
        val isFront           = call.argument<Boolean>("isFrontCamera") ?: true
        cameraRotationDegrees = if (isFront) (360 - sensorOrientation) % 360 else sensorOrientation
        scope.launch {
            try {
                val ctx = appContext ?: return@launch
                withContext(Dispatchers.IO) { initServices(ctx) }
                result.success(null)
            } catch (e: Exception) {
                Log.w(TAG, "Service pre-warm failed", e)
                result.success(null)
            }
        }
    }

    /** Cancels all three pipeline jobs and drains all channels, recycling any queued bitmaps. */
    private fun cancelPipelineJobs() {
        detectorJob?.cancel();      detectorJob      = null
        landmarkJob?.cancel();      landmarkJob      = null
        passiveMetricsJob?.cancel(); passiveMetricsJob = null
        livenessService?.pipeline?.resetTracking()
        frameChannel.tryReceive()
        var det = detectorOutputChannel.tryReceive()
        while (det.isSuccess) {
            det.getOrNull()?.let { if (!it.bitmap.isRecycled) it.bitmap.recycle() }
            det = detectorOutputChannel.tryReceive()
        }
        var pas = passiveChannel.tryReceive()
        while (pas.isSuccess) {
            pas.getOrNull()?.let { if (!it.bitmap.isRecycled) it.bitmap.recycle() }
            pas = passiveChannel.tryReceive()
        }
    }

    private fun handleStopActiveLiveness(result: MethodChannel.Result) {
        scope.launch {
            try { stopActiveRun(); result.success(null) }
            catch (e: Exception) { result.error("ERROR", e.message, null) }
        }
    }

    private suspend fun stopActiveRun() {
        cancelPipelineJobs()
        activeFlowMutex.withLock {
            sessionStopping = true; sessionFinished = true; activeRunId++
            clearSessionStateLocked()
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
                val preparedNfc = withContext(Dispatchers.IO) {
                    initServices(ctx)
                    prepareNfcImage(nfcImageBytes)
                }

                val runId = resetActiveLivenessState()

                val (currentActions, deferred) = activeFlowMutex.withLock {
                    Pair(
                        pendingActions.toList(),
                        firstFrameDeferred ?: throw IllegalStateException("Session not initialized")
                    )
                }
                val localEngine = engine ?: throw IllegalStateException("Engine unavailable")
                activeLivenessService ?: throw IllegalStateException(ERR_ACTIVE_SERVICE)

                launchFaceMatchJob(runId, deferred, localEngine, preparedNfc)
                startFrameLoop(runId)

                result.success(currentActions.map { it.name })
            } catch (e: Exception) {
                Log.e(TAG, "startActiveLiveness failed", e)
                result.error("ERROR", e.message, null)
            }
        }
    }

    private fun launchFaceMatchJob(
        runId: Int,
        deferred: CompletableDeferred<Bitmap>,
        engine: FaceVerificationEngine,
        nfc: ByteArray
    ) {
        faceMatchJob?.cancel()
        faceMatchJob = scope.launch(Dispatchers.Default) {
            var bmp: Bitmap? = null
            try {
                bmp = deferred.await()
                if (isShuttingDown) return@launch
                val score = engine.verify(nfc, bmp)
                storeMatchScore(runId, score.toDouble())
            } catch (_: CancellationException) { return@launch }
            catch (e: Exception) { storeMatchError(runId, e) }
            finally {
                if (bmp != null && !bmp.isRecycled) bmp.recycle()
            }
        }
    }

    private suspend fun storeMatchScore(runId: Int, score: Double) {
        activeFlowMutex.withLock {
            if (runId == activeRunId && !isShuttingDown) matchScoreDeferred?.complete(score)
        }
    }

    private suspend fun storeMatchError(runId: Int, e: Exception) {
        Log.e(TAG, "Face match error", e)
        activeFlowMutex.withLock {
            if (runId == activeRunId && !isShuttingDown) {
                matchScoreDeferred?.complete(0.0)
            }
        }
    }

    private suspend fun resetActiveLivenessState(): Int {
        cancelPipelineJobs()
        return activeFlowMutex.withLock {
            stopActiveRunInternalLocked()
            activeRunId++
            sessionFinished = false; sessionStopping = false
            sessionStartMs = SystemClock.elapsedRealtime()

            pendingActions = ActiveLivenessService.ALL_ACTIONS
                .shuffled().take(REQUIRED_ACTIONS).toMutableList()

            completedCount = 0; currentActionIndex = 0
            extraActionMode = false; framesSinceLastAction = 0
            firstFrameDeferred = CompletableDeferred()
            matchScoreDeferred = CompletableDeferred()

            activeRunId
        }
    }

    private fun stopActiveRunInternalLocked() {
        sessionFinished = true; sessionStopping = true
        clearSessionStateLocked()
    }

    // ═══════════════════════════════════════════════════════════
    //  Frame processing — two-stage pipeline
    //
    //  detectorJob  (Dispatchers.Default):
    //    NV21 decode → BlazeFace detection → send PipelineFrame to detectorOutputChannel
    //
    //  landmarkJob  (Dispatchers.Default):
    //    receive PipelineFrame → landmark + blendshape inference (outside mutex)
    //    → acquire mutex → action detection / event emission
    //
    //  The channel capacity of 1 lets the detector start on frame N+1 while the
    //  landmark stage is still processing frame N, without unbounded buffering.
    // ═══════════════════════════════════════════════════════════

    private suspend fun runDetectorIteration(runId: Int): Boolean {
        val active = activeFlowMutex.withLock {
            !sessionFinished && !sessionStopping && runId == activeRunId
        }
        if (!active) return false

        val frame = try { frameChannel.receive() }
        catch (_: CancellationException) { return false }

        val bitmap = decodeNv21Frame(frame.data, frame.rotationDegrees) ?: return true

        val pipeline = livenessService?.pipeline
        val crop = try { pipeline?.runDetectorStage(bitmap) }
        catch (_: CancellationException) { if (!bitmap.isRecycled) bitmap.recycle(); return false }
        catch (_: Exception) { if (!bitmap.isRecycled) bitmap.recycle(); return true }

        try { detectorOutputChannel.send(PipelineFrame(bitmap, crop, runId)) }
        catch (_: CancellationException) { if (!bitmap.isRecycled) bitmap.recycle(); return false }

        return true
    }

    private suspend fun runPassiveIteration(passive: PassiveFrame) {
        markPassiveFrameStarted()
        try {
            val active = activeFlowMutex.withLock {
                passive.runId == activeRunId && !sessionFinished && !sessionStopping
            }
            if (!passive.bitmap.isRecycled && active) {
                passiveLivenessService?.collectPassiveMetrics(passive.bitmap, passive.result)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Passive metrics error", e)
        } finally {
            if (!passive.bitmap.isRecycled) passive.bitmap.recycle()
            markPassiveFrameFinished()
        }
    }

    private fun startFrameLoop(runId: Int) {
        detectorJob?.cancel()
        landmarkJob?.cancel()
        passiveMetricsJob?.cancel()

        detectorJob = scope.launch(Dispatchers.Default) {
            while (isActive && !isShuttingDown) {
                if (!runDetectorIteration(runId)) break
            }
        }

        landmarkJob = scope.launch(Dispatchers.Default) {
            while (isActive && !isShuttingDown) {
                val frame = try { detectorOutputChannel.receive() }
                catch (_: CancellationException) { break }
                processLandmarkFrame(frame)
            }
        }

        passiveMetricsJob = scope.launch(Dispatchers.Default) {
            while (isActive && !isShuttingDown) {
                val passive = try { passiveChannel.receive() }
                catch (_: CancellationException) { break }
                runPassiveIteration(passive)
            }
        }
    }

    private suspend fun isActiveRun(runId: Int): Boolean = activeFlowMutex.withLock {
        !isShuttingDown && !sessionFinished && !sessionStopping && runId == activeRunId
    }

    private fun markPassiveFrameStarted() {
        synchronized(passiveInFlightLock) { passiveFramesInFlight++ }
    }

    private fun markPassiveFrameFinished() {
        synchronized(passiveInFlightLock) {
            if (passiveFramesInFlight > 0) passiveFramesInFlight--
        }
    }

    private suspend fun awaitPassiveMetricsIdle() {
        while (true) {
            val idle = synchronized(passiveInFlightLock) { passiveFramesInFlight == 0 }
            if (idle) return
            delay(25)
        }
    }

    private fun handleProcessFrame(call: MethodCall, result: MethodChannel.Result) {
        val data = call.argument<ByteArray>("frame")
        if (data == null || data.isEmpty()) {
            result.error("INVALID_ARGS", "frame is required", null); return
        }
        val rotation = normalizeRotationDegrees(call.argument<Int>("rotation") ?: cameraRotationDegrees)
        if (!isShuttingDown && !sessionFinished && !sessionStopping) {
            frameChannel.trySend(RawFrame(data, rotation))
            latestFrameReceivedMs = SystemClock.elapsedRealtime()
        }
        result.success(null)
    }

    private suspend fun handleAligningState(frame: PipelineFrame, result: FaceLandmarkerResult, bitmap: Bitmap, service: ActiveLivenessService) {
        val timedOut = framesSinceLastAction > ACTION_TIMEOUT_FRAMES
        val done = service.processAlignmentFrameWithResult(result, pendingActions[currentActionIndex], timedOut)
        if (done) {
            framesSinceLastAction = 0
            if (!timedOut) completeFirstFrameDeferred(bitmap)
            sendEvent(frame.runId, mapOf("type" to "nextAction", "action" to pendingActions[currentActionIndex].name))
        }
    }

    private suspend fun processActionUnderLock(frame: PipelineFrame, result: FaceLandmarkerResult?, bitmap: Bitmap) {
        if (isShuttingDown || sessionFinished || sessionStopping || frame.runId != activeRunId) return
        if (currentActionIndex >= pendingActions.size) return

        framesSinceLastAction++
        val service = activeLivenessService ?: throw IllegalStateException(ERR_ACTIVE_SERVICE)

        if (result == null) { service.lastFacePresent = false; return }

        completeFirstFrameDeferred(bitmap)

        if (service.isAligning) { handleAligningState(frame, result, bitmap, service); return }

        if (framesSinceLastAction > ACTION_TIMEOUT_FRAMES) { handleTimeoutLocked(frame.runId); return }

        val actionDone = service.processFrameWithResult(result)
        if (service.lastFacePresent) completeFirstFrameDeferred(bitmap)
        if (actionDone) handleActionDetectedLocked(frame.runId)
    }

    private suspend fun processLandmarkFrame(frame: PipelineFrame) {
        val bitmap = frame.bitmap
        var sentToPassive = false
        try {
            if (!isActiveRun(frame.runId)) return

            val pipeline = livenessService?.pipeline
            val result = if (frame.crop != null && pipeline != null) {
                pipeline.runLandmarkStage(bitmap, frame.crop)
            } else null

            if (!isActiveRun(frame.runId)) return

            if (result != null) pipeline?.updateTrackingCrop(result, bitmap.width, bitmap.height)
            else pipeline?.resetTracking()

            activeFlowMutex.withLock { processActionUnderLock(frame, result, bitmap) }

            if (result != null && isActiveRun(frame.runId)) {
                sentToPassive = passiveChannel.trySend(PassiveFrame(bitmap, result, frame.runId)).isSuccess
            }
        } catch (e: CancellationException) { throw e
        } catch (e: Exception) {
            Log.e(TAG, "Landmark loop error", e)
            abortActiveRun(frame.runId, "Liveness processing failed. Please try again.")
        } finally {
            if (!sentToPassive && !bitmap.isRecycled) bitmap.recycle()
        }
    }

    private fun completeFirstFrameDeferred(bitmap: Bitmap) {
        firstFrameDeferred?.let { if (!it.isCompleted) it.complete(bitmap.copy(bitmap.config ?: Bitmap.Config.ARGB_8888, false)) }
    }

    private suspend fun handleActionDetectedLocked(runId: Int) {
        val completed = pendingActions[currentActionIndex]
        completedCount++; currentActionIndex++; framesSinceLastAction = 0

        sendEvent(runId, mapOf("type" to "actionDetected", "action" to completed.name))
        advanceToNextActionLocked(runId, useQueue = true)
    }

    // ═══════════════════════════════════════════════════════════
    //  Timeout / Extra / Finish
    // ═══════════════════════════════════════════════════════════

    private suspend fun handleTimeoutLocked(runId: Int) {
        val timedOut = pendingActions.getOrNull(currentActionIndex)
        framesSinceLastAction = 0

        sendEvent(runId, mapOf("type" to "timeout", "action" to timedOut?.name))
        currentActionIndex++

        advanceToNextActionLocked(runId, useQueue = false)
    }

    private suspend fun advanceToNextActionLocked(runId: Int, useQueue: Boolean) {
        if (currentActionIndex >= pendingActions.size) {
            if (shouldStartExtra()) { startExtraLocked(runId); return }
            val passed = completedCount >= if (extraActionMode) ACTIONS_NEEDED_TO_PASS + 1 else REQUIRED_ACTIONS
            finishSessionLocked(runId, passed)
            return
        }
        // Only resolve the service when we actually need to start the next action
        val service = activeLivenessService ?: throw IllegalStateException(ERR_ACTIVE_SERVICE)
        val next = pendingActions[currentActionIndex]
        if (useQueue) service.queueNextAction(next) else service.startAction(next)
        sendEvent(runId, mapOf("type" to "nextAction", "action" to next.name))
    }

    private fun shouldStartExtra(): Boolean =
        !extraActionMode &&
                pendingActions.size == REQUIRED_ACTIONS &&
                currentActionIndex >= REQUIRED_ACTIONS &&
                completedCount == ACTIONS_NEEDED_TO_PASS

    private suspend fun startExtraLocked(runId: Int) {
        val service = activeLivenessService ?: throw IllegalStateException(ERR_ACTIVE_SERVICE)
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
        cancelPipelineJobs()
        sendEvent(runId, mapOf("type" to "processing"))
        scope.launch(Dispatchers.Default) { collectAndSendResult(runId, passed) }
    }

    private suspend fun collectAndSendResult(runId: Int, passed: Boolean) {
        val score = try {
            val deferred = activeFlowMutex.withLock {
                if (runId != activeRunId || sessionStopping) return
                matchScoreDeferred
            }
            deferred?.await() ?: 0.0
        } catch (_: CancellationException) { return }

        awaitPassiveMetricsIdle()
        passiveLivenessService?.awaitRppgIdle()

        val antiSpoofScore    = passiveLivenessService?.getAntiSpoofScore()
        val antiSpoofPassed   = passiveLivenessService?.isAntiSpoofPassed() ?: false
        val rppgResult        = passiveLivenessService?.getRppgResult()
        val rppgPassed        = rppgResult?.passed ?: false
        val finalPassed       = passed && antiSpoofPassed && rppgPassed

        val shouldSend = activeFlowMutex.withLock {
            runId == activeRunId && !isShuttingDown && !sessionStopping
        }

        if (shouldSend) {
            sendEvent(runId, mapOf(
                "type"            to "complete",
                "passed"          to finalPassed,
                "matchScore"      to score,
                "antiSpoofScore"  to antiSpoofScore,
                "antiSpoofPassed" to antiSpoofPassed,
                "rppg"            to mapOf(
                    "hr" to rppgResult?.hr,
                    "passed" to rppgResult?.passed,
                    "sampleCount" to rppgResult?.sampleCount,
                    "durationMs" to rppgResult?.durationMs
                ),
            ))
        }

        activeFlowMutex.withLock { cleanUpSessionStateLocked(runId) }
    }

    private fun cleanUpSessionStateLocked(runId: Int) {
        if (runId != activeRunId) return
        clearSessionStateLocked()
    }

    /** Must only be called while holding the [activeFlowMutex] lock. */
    private fun clearSessionStateLocked() {
        try { faceMatchJob?.cancel() } catch (e: Exception) { Log.w(TAG, "faceMatchJob cancel failed", e) }
        faceMatchJob = null

        firstFrameDeferred?.let { if (!it.isCompleted) it.cancel() }
        firstFrameDeferred = null
        matchScoreDeferred?.let { if (!it.isCompleted) it.cancel() }
        matchScoreDeferred = null

        pendingActions.clear(); completedCount = 0; currentActionIndex = 0
        extraActionMode = false; framesSinceLastAction = 0

        try { activeLivenessService?.reset() } catch (e: Exception) { Log.w(TAG, "activeLivenessService reset failed", e) }
        sessionStopping = false
    }

    private suspend fun abortActiveRun(runId: Int, message: String) {
        cancelPipelineJobs()
        val shouldNotify = activeFlowMutex.withLock {
            if (runId != activeRunId || sessionStopping) return@withLock false
            sessionStopping = true; sessionFinished = true; activeRunId++
            clearSessionStateLocked()
            true
        }

        if (shouldNotify) sendTerminalError(message)
    }

    // ═══════════════════════════════════════════════════════════
    //  NV21 decode
    // ═══════════════════════════════════════════════════════════

    private fun decodeNv21Frame(data: ByteArray, rotationDegrees: Int): Bitmap? {
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
        val raw = Bitmap.createBitmap(argb, w, h, Bitmap.Config.ARGB_8888)
        val rot = normalizeRotationDegrees(rotationDegrees)
        if (rot == 0) return raw
        val m = android.graphics.Matrix().apply { postRotate(rot.toFloat()) }
        val rotated = Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, m, true)
        raw.recycle()
        return rotated
    }

    private fun normalizeRotationDegrees(degrees: Int): Int {
        val normalized = ((degrees % 360) + 360) % 360
        return when (normalized) {
            0, 90, 180, 270 -> normalized
            else -> (((normalized + 45) / 90) * 90) % 360
        }
    }

    private fun nv21ToArgb(src: ByteArray, off: Int, w: Int, h: Int, out: IntArray) {
        val frameSize = w * h
        // NV21 layout: [off .. off+w*h) = Y plane, then interleaved V,U pairs at half resolution
        val uvStart = off + frameSize
        var yp      = off

        for (j in 0 until h) {
            // UV rows are 2× subsampled: row j shares UV data with row j+1
            val uvp = uvStart + (j shr 1) * w
            var u = 0; var v = 0

            for (i in 0 until w) {
                // Bias Y into [0..219] studio-swing range; clamp negatives to 0
                val y = (src[yp].toInt() and 0xFF) - 16
                // UV pairs are 2× subsampled horizontally; reload every two pixels
                if ((i and 1) == 0) {
                    v = (src[uvp + i].toInt()     and 0xFF) - 128  // V (Cr) first in NV21
                    u = (src[uvp + i + 1].toInt() and 0xFF) - 128  // U (Cb) second
                }
                // Apply BT.601 matrix — all values are ×1024 (see YUV_* constants)
                val y1192 = YUV_Y * if (y < 0) 0 else y
                var r = y1192 + YUV_VR * v
                var g = y1192 - YUV_VG * v - YUV_UG * u
                var b = y1192 + YUV_UB * u

                // Clamp to valid ×1024 range (0..255×1024 = 0..261120; 262143 = 0x3FFFF)
                r = r.coerceIn(0, 262143); g = g.coerceIn(0, 262143); b = b.coerceIn(0, 262143)

                // Pack into ARGB_8888: divide each channel by 1024 via bit manipulation.
                // (r shl 6) places bits [17:10] of r at [23:16]; same effect as (r/1024) shl 16.
                // (g shr 2) places bits [9:2]   of g at [15:8];  same effect as (g/1024) shl 8.
                // (b shr 10) extracts bits [17:10] of b directly into [7:0].
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
            try { eventSink?.success(data) } catch (e: Exception) { Log.w(TAG, "eventSink send failed", e) }
        }
    }

    private fun sendTerminalError(message: String) {
        if (isShuttingDown) return
        scope.launch(Dispatchers.Main) {
            if (isShuttingDown) return@launch
            try { eventSink?.success(mapOf("type" to "error", "message" to message)) } catch (e: Exception) { Log.w(TAG, "eventSink terminal error send failed", e) }
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
