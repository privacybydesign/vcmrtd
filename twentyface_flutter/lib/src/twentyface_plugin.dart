import 'package:flutter/services.dart';

import 'models/comparison_result.dart';
import 'models/face_detection.dart';
import 'models/face_status.dart';
import 'models/liveness_result.dart';
import 'models/verification_config.dart';

/// Image type for passport photos.
enum ImageType { jpeg, jpeg2000 }

/// Low-level plugin interface for the 20face SDK.
///
/// This class provides direct access to the native SDK methods via MethodChannel.
/// For most use cases, prefer using [FaceVerificationService] instead.
class TwentyfacePlugin {
  static const MethodChannel _channel = MethodChannel('twentyface_flutter');

  /// Initialize the SDK with a license key.
  ///
  /// Must be called before using any other methods.
  /// Throws [PlatformException] if the license is invalid or expired.
  static Future<void> initialize(String license) async {
    await _channel.invokeMethod('initialize', {'license': license});
  }

  /// Get the SDK version string.
  static Future<String> getVersion() async {
    final result = await _channel.invokeMethod<String>('getVersion');
    return result ?? 'unknown';
  }

  /// Get the model version string.
  static Future<String> getModelVersion() async {
    final result = await _channel.invokeMethod<String>('getModelVersion');
    return result ?? 'unknown';
  }

  /// Compare two face images.
  ///
  /// [liveImage] - The live camera capture (JPEG bytes).
  /// [referenceImage] - The reference image (e.g., passport photo).
  /// [referenceImageType] - Type of the reference image (jpeg or jpeg2000).
  /// [config] - Verification configuration.
  ///
  /// Returns a [FaceComparisonResult] with match status and details.
  static Future<FaceComparisonResult> compareFaces({
    required Uint8List liveImage,
    required Uint8List referenceImage,
    ImageType referenceImageType = ImageType.jpeg,
    FaceVerificationConfig? config,
  }) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'compareFaces',
      {
        'liveImage': liveImage,
        'referenceImage': referenceImage,
        'referenceImageType': referenceImageType.name,
        'config': config?.toMap() ?? const FaceVerificationConfig().toMap(),
      },
    );

    if (result == null) {
      return FaceComparisonResult(
        match: false,
        recognitionDistance: -1.0,
        statusImage1: const FaceStatus(isOverallOk: false),
        statusImage2: const FaceStatus(isOverallOk: false),
      );
    }

    return FaceComparisonResult.fromMap(result);
  }

  /// Detect faces in an image.
  ///
  /// Returns a list of [FaceDetection] objects with face positions and quality info.
  /// Useful for real-time camera feedback.
  static Future<List<FaceDetection>> detectFaces(
    Uint8List image, {
    FaceVerificationConfig? config,
  }) async {
    final result = await _channel.invokeMethod<List<dynamic>>(
      'detectFaces',
      {
        'image': image,
        'config': config?.toMap() ?? const FaceVerificationConfig().toMap(),
      },
    );

    if (result == null) return [];

    return result
        .whereType<Map<dynamic, dynamic>>()
        .map((map) => FaceDetection.fromMap(map))
        .toList();
  }

  /// Check liveness of a face in an image.
  ///
  /// Performs passive anti-spoofing detection.
  static Future<LivenessResult> checkLiveness(
    Uint8List image, {
    FaceVerificationConfig? config,
  }) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'checkLiveness',
      {
        'image': image,
        'config': config?.toMap() ?? const FaceVerificationConfig().toMap(),
      },
    );

    if (result == null) {
      return const LivenessResult(
        isLive: false,
        score: 0.0,
        status: FaceStatus(isOverallOk: false, passiveAntispoofingSpoofed: true),
      );
    }

    return LivenessResult.fromMap(result);
  }

  /// Get the hardware ID for license requests.
  ///
  /// Returns the device's hardware ID as a string, which can be used
  /// to request a license from the 20face license server.
  static Future<String> getHardwareId() async {
    final result = await _channel.invokeMethod<String>('getHardwareId');
    return result ?? '';
  }

  /// Release SDK resources.
  static Future<void> dispose() async {
    await _channel.invokeMethod('dispose');
  }
}
