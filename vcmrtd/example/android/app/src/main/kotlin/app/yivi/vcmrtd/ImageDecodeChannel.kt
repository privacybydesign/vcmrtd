package foundation.privacybydesign.vcmrtd

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object ImageDecodeChannel {

    fun register(flutterEngine: FlutterEngine, appContext: Context) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "image_channel")
            .setMethodCallHandler { call, result ->
                if (call.method == "decodeImage") {
                    val jp2ImageData = call.argument<ByteArray?>("jp2ImageData")
                    if (jp2ImageData != null) {
                        ImageUtil.decodeImage(appContext, jp2ImageData, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "jp2ImageData is null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}