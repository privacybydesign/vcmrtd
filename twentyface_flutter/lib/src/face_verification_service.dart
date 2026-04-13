import 'dart:typed_data';

import 'models/comparison_result.dart';
import 'models/face_detection.dart';
import 'models/liveness_result.dart';
import 'models/verification_config.dart';
import 'twentyface_plugin.dart';

export 'models/comparison_result.dart';
export 'models/face_detection.dart';
export 'models/face_status.dart';
export 'models/liveness_result.dart';
export 'models/verification_config.dart';
export 'twentyface_plugin.dart' show ImageType;

/// High-level service for face verification against passport photos.
///
/// Example usage:
/// ```dart
/// final service = FaceVerificationService();
/// await service.initialize(license);
///
/// final result = await service.compareFaces(
///   liveImage: cameraCapture,
///   referenceImage: passportPhoto,
///   referenceImageType: ImageType.jpeg2000,
/// );
///
/// if (result.match && result.passedLivenessCheck) {
///   print('Verification successful!');
/// }
///
/// await service.dispose();
/// ```
class FaceVerificationService {
  bool _initialized = false;

  /// The default configuration used when no config is specified.
  FaceVerificationConfig defaultConfig = const FaceVerificationConfig();

  /// Whether the service has been initialized.
  bool get isInitialized => _initialized;

  /// Initialize the face verification service with a license key.
  ///
  /// [license] - The 20face SDK license string.
  /// [config] - Optional default configuration for all operations.
  ///
  /// Throws [StateError] if already initialized.
  /// Throws [Exception] if the license is invalid or expired.
  Future<void> initialize(
    String license, {
    FaceVerificationConfig? config,
  }) async {
    if (_initialized) {
      throw StateError('FaceVerificationService is already initialized');
    }

    await TwentyfacePlugin.initialize(license);
    _initialized = true;

    if (config != null) {
      defaultConfig = config;
    }
  }

  /// Compare a live camera image with a reference (passport) image.
  ///
  /// [liveImage] - JPEG bytes from camera capture.
  /// [referenceImage] - Reference image bytes (e.g., DG2 passport photo).
  /// [referenceImageType] - Type of reference image (jpeg or jpeg2000).
  /// [config] - Optional configuration override.
  ///
  /// Returns [FaceComparisonResult] with match status, distance, and quality info.
  Future<FaceComparisonResult> compareFaces({
    required Uint8List liveImage,
    required Uint8List referenceImage,
    ImageType referenceImageType = ImageType.jpeg,
    FaceVerificationConfig? config,
  }) async {
    _checkInitialized();

    return TwentyfacePlugin.compareFaces(
      liveImage: liveImage,
      referenceImage: referenceImage,
      referenceImageType: referenceImageType,
      config: config ?? defaultConfig,
    );
  }

  /// Detect faces in an image.
  ///
  /// Useful for real-time camera feedback to guide face positioning.
  ///
  /// [image] - JPEG bytes from camera.
  /// [config] - Optional configuration override.
  ///
  /// Returns list of [FaceDetection] with face positions and quality status.
  Future<List<FaceDetection>> detectFaces(
    Uint8List image, {
    FaceVerificationConfig? config,
  }) async {
    _checkInitialized();

    return TwentyfacePlugin.detectFaces(
      image,
      config: config ?? defaultConfig,
    );
  }

  /// Check if a face image is from a live person (anti-spoofing).
  ///
  /// [image] - JPEG bytes from camera.
  /// [config] - Optional configuration override.
  ///
  /// Returns [LivenessResult] with pass/fail status and confidence score.
  Future<LivenessResult> checkLiveness(
    Uint8List image, {
    FaceVerificationConfig? config,
  }) async {
    _checkInitialized();

    return TwentyfacePlugin.checkLiveness(
      image,
      config: config ?? defaultConfig,
    );
  }

  /// Get the SDK version string.
  Future<String> getVersion() async {
    _checkInitialized();
    return TwentyfacePlugin.getVersion();
  }

  /// Release SDK resources.
  ///
  /// Should be called when the service is no longer needed.
  Future<void> dispose() async {
    if (_initialized) {
      await TwentyfacePlugin.dispose();
      _initialized = false;
    }
  }

  void _checkInitialized() {
    if (!_initialized) {
      throw StateError(
        'FaceVerificationService not initialized. Call initialize() first.',
      );
    }
  }
}
