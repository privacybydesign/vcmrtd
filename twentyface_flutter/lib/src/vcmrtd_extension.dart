import 'dart:typed_data';

import 'face_verification_service.dart';

/// Extension for integrating face verification with vcmrtd PassportData.
///
/// This extension requires importing the vcmrtd package alongside twentyface_flutter.
///
/// Example usage:
/// ```dart
/// import 'package:vcmrtd/vcmrtd.dart';
/// import 'package:twentyface_flutter/twentyface_flutter.dart';
///
/// // After reading passport data
/// final passportData = await reader.read();
///
/// // Create verification service
/// final service = FaceVerificationService();
/// await service.initialize(license);
///
/// // Verify face
/// final result = await verifyFaceAgainstPassport(
///   passportData: passportData,
///   liveImage: cameraCapture,
///   service: service,
/// );
/// ```

/// Verify a live camera image against passport photo data.
///
/// [passportPhotoData] - The photo bytes from passport DG2.
/// [passportPhotoType] - The image type (jpeg or jpeg2000).
/// [liveImage] - JPEG bytes from camera capture.
/// [service] - Initialized [FaceVerificationService].
/// [config] - Optional verification configuration.
///
/// Returns [FaceComparisonResult] with match status and details.
Future<FaceComparisonResult> verifyFaceAgainstPassport({
  required Uint8List passportPhotoData,
  required ImageType passportPhotoType,
  required Uint8List liveImage,
  required FaceVerificationService service,
  FaceVerificationConfig? config,
}) async {
  return service.compareFaces(
    liveImage: liveImage,
    referenceImage: passportPhotoData,
    referenceImageType: passportPhotoType,
    config: config,
  );
}

/// Helper to convert vcmrtd ImageType to twentyface ImageType.
///
/// Use this when the image type comes from vcmrtd's document.dart.
ImageType imageTypeFromString(String type) {
  switch (type.toLowerCase()) {
    case 'jpeg2000':
      return ImageType.jpeg2000;
    case 'jpeg':
    default:
      return ImageType.jpeg;
  }
}
