package nl.twentyface.twentyface_flutter

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import com.example.twentyface_sdk_library.twentyfacelib
import com.example.twentyface_sdk_library.classes.Configuration
import com.example.twentyface_sdk_library.classes.Comparison
import com.example.twentyface_sdk_library.classes.Detection
import com.example.twentyface_sdk_library.classes.Status
import com.gemalto.jp2.JP2Decoder
import android.util.Log
import java.io.ByteArrayInputStream

/** TwentyfaceFlutterPlugin */
class TwentyfaceFlutterPlugin : FlutterPlugin, MethodCallHandler {
    companion object {
        private const val TAG = "TwentyfaceFlutter"
    }

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var lib: twentyfacelib? = null
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "twentyface_flutter")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> handleInitialize(call, result)
            "getVersion" -> handleGetVersion(result)
            "getModelVersion" -> handleGetModelVersion(result)
            "getHardwareId" -> handleGetHardwareId(result)
            "compareFaces" -> handleCompareFaces(call, result)
            "detectFaces" -> handleDetectFaces(call, result)
            "checkLiveness" -> handleCheckLiveness(call, result)
            "dispose" -> handleDispose(result)
            else -> result.notImplemented()
        }
    }

    private fun handleInitialize(call: MethodCall, result: Result) {
        scope.launch {
            try {
                val license = call.argument<String>("license")
                    ?: throw IllegalArgumentException("License is required")

                Log.d(TAG, "Initializing TwentyfaceSDK...")
                Log.d(TAG, "License (first 8 chars): ${license.take(8)}...")

                // Copy models to internal storage
                Log.d(TAG, "Copying models to internal storage...")
                twentyfacelib.models_assets_to_internal(context)
                Log.d(TAG, "Models copied successfully")

                // Set the license
                Log.d(TAG, "Setting license...")
                twentyfacelib.setLicense(license)
                Log.d(TAG, "License set successfully")

                // Create library instance
                Log.d(TAG, "Creating twentyfacelib instance...")
                lib = twentyfacelib()
                Log.d(TAG, "TwentyfaceSDK initialized successfully")

                withContext(Dispatchers.Main) {
                    result.success(null)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize TwentyfaceSDK: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("INIT_ERROR", e.message, e.stackTraceToString())
                }
            }
        }
    }

    private fun handleGetVersion(result: Result) {
        try {
            val version = twentyfacelib.getVersion()
            result.success(version)
        } catch (e: Exception) {
            result.error("VERSION_ERROR", e.message, null)
        }
    }

    private fun handleGetModelVersion(result: Result) {
        try {
            val version = twentyfacelib.getModelVersion()
            result.success(version)
        } catch (e: Exception) {
            result.error("VERSION_ERROR", e.message, null)
        }
    }

    private fun handleGetHardwareId(result: Result) {
        scope.launch {
            try {
                val hardwareId = twentyfacelib.getHardwareID()
                withContext(Dispatchers.Main) {
                    result.success(hardwareId)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("HWID_ERROR", e.message, e.stackTraceToString())
                }
            }
        }
    }

    private fun handleCompareFaces(call: MethodCall, result: Result) {
        scope.launch {
            try {
                val library = lib ?: throw IllegalStateException("SDK not initialized")

                val liveImageData = call.argument<ByteArray>("liveImage")
                    ?: throw IllegalArgumentException("liveImage is required")
                val referenceImageData = call.argument<ByteArray>("referenceImage")
                    ?: throw IllegalArgumentException("referenceImage is required")
                val referenceImageType = call.argument<String>("referenceImageType") ?: "jpeg"
                val configMap = call.argument<Map<String, Any>>("config")

                // Decode live image (JPEG) — applies EXIF orientation
                val liveImage = decodeJpegWithOrientation(liveImageData)
                    ?: throw IllegalArgumentException("Failed to decode live image")

                // Decode reference image (JPEG or JPEG2000)
                val referenceImage = if (referenceImageType == "jpeg2000") {
                    decodeJpeg2000(referenceImageData)
                } else {
                    decodeJpegWithOrientation(referenceImageData)
                } ?: throw IllegalArgumentException("Failed to decode reference image")

                // Create configuration
                val config = createConfiguration(configMap)

                // Perform comparison
                val comparison = library.compare(liveImage, referenceImage, config)

                // Convert to map
                val resultMap = comparisonToMap(comparison)

                withContext(Dispatchers.Main) {
                    result.success(resultMap)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("COMPARE_ERROR", e.message, e.stackTraceToString())
                }
            }
        }
    }

    private fun handleDetectFaces(call: MethodCall, result: Result) {
        scope.launch {
            try {
                val library = lib ?: throw IllegalStateException("SDK not initialized")

                val imageData = call.argument<ByteArray>("image")
                    ?: throw IllegalArgumentException("image is required")
                val configMap = call.argument<Map<String, Any>>("config")

                val bitmap = decodeJpegWithOrientation(imageData)
                    ?: throw IllegalArgumentException("Failed to decode image")

                Log.d(TAG, "detectFaces: bitmap ${bitmap.width}x${bitmap.height}, ${imageData.size} bytes")

                val config = createConfiguration(configMap)
                val detections = library.detectFaces(bitmap, config)

                Log.d(TAG, "detectFaces: found ${detections.size} face(s)")

                val resultList = detections.map { detectionToMap(it) }

                withContext(Dispatchers.Main) {
                    result.success(resultList)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("DETECT_ERROR", e.message, e.stackTraceToString())
                }
            }
        }
    }

    private fun handleCheckLiveness(call: MethodCall, result: Result) {
        scope.launch {
            try {
                val library = lib ?: throw IllegalStateException("SDK not initialized")

                val imageData = call.argument<ByteArray>("image")
                    ?: throw IllegalArgumentException("image is required")
                val configMap = call.argument<Map<String, Any>>("config")

                val bitmap = decodeJpegWithOrientation(imageData)
                    ?: throw IllegalArgumentException("Failed to decode image")

                // Force passive liveness enabled
                val config = createConfiguration(configMap).apply {
                    passive_anti_spoofing = true
                }

                val detections = library.detectFaces(bitmap, config)

                if (detections.isEmpty()) {
                    withContext(Dispatchers.Main) {
                        result.success(mapOf(
                            "is_live" to false,
                            "score" to 0.0,
                            "status" to statusToMap(Status())
                        ))
                    }
                    return@launch
                }

                val detection = detections.first()
                val status = detection.get_status()
                val isLive = !status.passive_antispoofing_spoofed && !status.antispoofing_spoofed

                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "is_live" to isLive,
                        "score" to detection.get_score().toDouble(),
                        "status" to statusToMap(status)
                    ))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("LIVENESS_ERROR", e.message, e.stackTraceToString())
                }
            }
        }
    }

    private fun handleDispose(result: Result) {
        lib = null
        result.success(null)
    }

    private fun decodeJpeg2000(data: ByteArray): Bitmap {
        val inputStream = ByteArrayInputStream(data)
        return JP2Decoder(inputStream).decode()
    }

    /**
     * Decode a JPEG and apply EXIF orientation so the resulting bitmap is
     * upright. Camera captures (image_picker, native camera intents) often
     * store the raw sensor pixels plus an EXIF orientation tag — without
     * applying it, faces end up sideways and the SDK can't detect them.
     */
    private fun decodeJpegWithOrientation(data: ByteArray): Bitmap? {
        val bitmap = BitmapFactory.decodeByteArray(data, 0, data.size) ?: return null

        val orientation = try {
            ExifInterface(ByteArrayInputStream(data))
                .getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read EXIF: ${e.message}")
            ExifInterface.ORIENTATION_NORMAL
        }

        if (orientation == ExifInterface.ORIENTATION_NORMAL ||
            orientation == ExifInterface.ORIENTATION_UNDEFINED) {
            return bitmap
        }

        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.postRotate(90f); matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.postRotate(270f); matrix.postScale(-1f, 1f)
            }
        }

        Log.d(TAG, "Applying EXIF orientation: $orientation")

        return try {
            val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (rotated != bitmap) bitmap.recycle()
            rotated
        } catch (e: Exception) {
            Log.e(TAG, "Failed to rotate bitmap: ${e.message}", e)
            bitmap
        }
    }

    private fun createConfiguration(configMap: Map<String, Any>?): Configuration {
        val config = Configuration()

        configMap?.let { map ->
            (map["enable_passive_liveness"] as? Boolean)?.let {
                config.passive_anti_spoofing = it
            }
            (map["liveness_threshold"] as? Number)?.let {
                config.passive_anti_spoofing_threshold = it.toDouble()
            }
            (map["max_horizontal_rotation"] as? Number)?.let {
                config.qc_max_horizontal_rotation = it.toDouble()
            }
            (map["max_vertical_rotation"] as? Number)?.let {
                config.qc_max_vertical_rotation = it.toDouble()
            }
            (map["min_sharpness"] as? Number)?.let {
                config.qc_min_sharpness = it.toFloat()
            }
            (map["max_exposure"] as? Number)?.let {
                config.qc_max_exposure = it.toDouble()
            }
            (map["detect_closest_only"] as? Boolean)?.let {
                config.detect_closest_only = it
            }
        }

        return config
    }

    private fun comparisonToMap(comparison: Comparison): Map<String, Any?> {
        return mapOf(
            "match" to comparison.match,
            "recognition_distance" to comparison.recognition_distance.toDouble(),
            "status_image_1" to statusToMap(comparison.status_image_1),
            "status_image_2" to statusToMap(comparison.status_image_2)
        )
    }

    private fun detectionToMap(detection: Detection): Map<String, Any?> {
        val rectangle = detection.get_rectangle()
        return mapOf(
            "id" to detection.get_id(),
            "score" to detection.get_score().toDouble(),
            "rectangle" to mapOf(
                "x" to rectangle.left(),
                "y" to rectangle.top(),
                "width" to rectangle.width(),
                "height" to rectangle.height()
            ),
            "status" to statusToMap(detection.get_status()),
            "pose" to mapOf(
                "yaw" to 0.0,  // Pose estimation available via landmarks if needed
                "pitch" to 0.0,
                "roll" to 0.0
            ),
            "frame_width" to detection.get_frame_width(),
            "frame_height" to detection.get_frame_height()
        )
    }

    private fun statusToMap(status: Status): Map<String, Boolean> {
        return mapOf(
            "detection_too_small" to status.detection_too_small,
            "detection_score_too_low" to status.detection_score_too_low,
            "detection_outside_image" to status.detection_outside_image,
            "detection_outside_depth_image" to status.detection_outside_depth_image,
            "detection_no_faces" to status.detection_no_faces,
            "detection_too_many_faces" to status.detection_too_many_faces,
            "qualitycheck_blurry" to status.qualitycheck_blurry,
            "qualitycheck_rotated" to status.qualitycheck_rotated,
            "qualitycheck_overexposed" to status.qualitycheck_overexposed,
            "antispoofing_too_far" to status.antispoofing_too_far,
            "antispoofing_spoofed" to status.antispoofing_spoofed,
            "passive_antispoofing_spoofed" to status.passive_antispoofing_spoofed,
            "facevector_too_similar_in_db" to status.facevector_too_similar_in_db,
            "facevector_not_recognized" to status.facevector_not_recognized,
            "facevector_failed_to_create" to status.facevector_failed_to_create,
            "is_overall_ok" to status.is_overall_ok()
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
    }
}
