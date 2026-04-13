/// Flutter plugin for 20face SDK face verification.
///
/// This plugin provides face verification capabilities using the 20face SDK,
/// enabling comparison of live camera images against passport photos (DG2).
///
/// ## Getting Started
///
/// 1. Initialize the service with your license:
/// ```dart
/// final service = FaceVerificationService();
/// await service.initialize(yourLicenseKey);
/// ```
///
/// 2. Compare faces:
/// ```dart
/// final result = await service.compareFaces(
///   liveImage: cameraImageBytes,
///   referenceImage: passportPhotoBytes,
///   referenceImageType: ImageType.jpeg2000,
/// );
///
/// if (result.match && result.passedLivenessCheck) {
///   print('Identity verified!');
/// }
/// ```
///
/// 3. Use the camera UI for a complete verification flow:
/// ```dart
/// FaceVerificationScreen(
///   referenceImage: passportData.photoImageData,
///   referenceImageType: ImageType.jpeg2000,
///   onResult: (result) {
///     if (result.match) {
///       // Verification successful
///     }
///   },
/// );
/// ```
library;

// Core service
export 'src/face_verification_service.dart';

// Models
export 'src/models/comparison_result.dart';
export 'src/models/face_detection.dart';
export 'src/models/face_status.dart';
export 'src/models/liveness_result.dart';
export 'src/models/verification_config.dart';

// Low-level plugin access
export 'src/twentyface_plugin.dart';

// UI Components
export 'src/ui/face_verification_screen.dart';
export 'src/ui/face_overlay_painter.dart';
export 'src/ui/verification_result_widget.dart';

// vcmrtd integration helpers
export 'src/vcmrtd_extension.dart';
