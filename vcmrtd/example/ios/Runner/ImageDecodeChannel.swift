import Flutter
import UIKit

/// Handles the `image_channel` method channel for JP2 / JPEG-2000 passport photo decoding.
/// UIImage natively supports JPEG 2000 on iOS, so no third-party library is needed.
class ImageDecodeChannel {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "image_channel",
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            guard call.method == "decodeImage" else {
                result(FlutterMethodNotImplemented)
                return
            }
            guard let args = call.arguments as? [String: Any],
                  let jp2Data = args["jp2ImageData"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "jp2ImageData is required", details: nil))
                return
            }
            guard let image = UIImage(data: jp2Data.data) else {
                result(FlutterError(code: "DECODE_FAILED", message: "Could not decode image data", details: nil))
                return
            }
            guard let jpegData = image.jpegData(compressionQuality: 1.0) else {
                result(FlutterError(code: "ENCODE_FAILED", message: "Could not re-encode image as JPEG", details: nil))
                return
            }
            result(FlutterStandardTypedData(bytes: jpegData))
        }
    }
}
