import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Enum for face verification providers
enum FaceVerificationProvider {
  /// Regula Forensics Face SDK
  regula,

  /// FaceTec 3D Face SDK
  faceTec,
}

/// Extension to get display name for each provider
extension FaceVerificationProviderExtension on FaceVerificationProvider {
  String get displayName {
    switch (this) {
      case FaceVerificationProvider.regula:
        return 'Regula Forensics';
      case FaceVerificationProvider.faceTec:
        return 'FaceTec';
    }
  }

  String get description {
    switch (this) {
      case FaceVerificationProvider.regula:
        return '2D Face matching with liveness detection (iBeta certified)';
      case FaceVerificationProvider.faceTec:
        return '3D Face scanning with advanced liveness detection';
    }
  }
}

/// Provider for selecting the face verification provider
///
/// Allows switching between Regula and FaceTec implementations
/// for comparison purposes.
final faceVerificationConfigProvider =
    StateProvider<FaceVerificationProvider>((ref) {
  // Default to FaceTec for demonstration
  return FaceVerificationProvider.faceTec;
});

/// Provider to check if face verification is enabled
///
/// Set to false to disable face verification entirely
final faceVerificationEnabledProvider = StateProvider<bool>((ref) {
  return true;
});
