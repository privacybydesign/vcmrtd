import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_face_api/flutter_face_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// Provider for the Face SDK instance
final faceSdkProvider = Provider<FaceSDK>((ref) {
  return FaceSDK.instance;
});

/// State for face verification
class FaceVerificationState {
  final bool isInitialized;
  final bool isLoading;
  final Uint8List? livenessImage;
  final Uint8List? documentImage;
  final double? matchScore;
  final String? error;

  FaceVerificationState({
    this.isInitialized = false,
    this.isLoading = false,
    this.livenessImage,
    this.documentImage,
    this.matchScore,
    this.error,
  });

  FaceVerificationState copyWith({
    bool? isInitialized,
    bool? isLoading,
    Uint8List? livenessImage,
    Uint8List? documentImage,
    double? matchScore,
    String? error,
  }) {
    return FaceVerificationState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      livenessImage: livenessImage ?? this.livenessImage,
      documentImage: documentImage ?? this.documentImage,
      matchScore: matchScore ?? this.matchScore,
      error: error ?? this.error,
    );
  }
}

/// Provider for face verification state and operations
class FaceVerificationNotifier extends StateNotifier<FaceVerificationState> {
  final FaceSDK _faceSdk;
  final Logger _logger = Logger();

  FaceVerificationNotifier(this._faceSdk) : super(FaceVerificationState());

  /// Initialize the Face SDK
  Future<bool> initialize() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Try to load license file from assets
      InitConfig? config;
      try {
        final licenseData = await rootBundle.load("assets/regula.license");
        config = InitConfig(licenseData);
      } catch (e) {
        _logger.w("No license file found, initializing without license: $e");
        // Initialize without license (trial mode)
      }

      final (success, error) = await _faceSdk.initialize(config: config);

      if (error != null) {
        _logger.e("Face SDK initialization error: ${error.code}: ${error.message}");
        state = state.copyWith(
          isLoading: false,
          error: "${error.code}: ${error.message}",
        );
        return false;
      }

      if (success) {
        _logger.i("Face SDK initialized successfully");
        state = state.copyWith(isInitialized: true, isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: "Failed to initialize Face SDK",
        );
        return false;
      }
    } catch (e) {
      _logger.e("Exception during Face SDK initialization: $e");
      state = state.copyWith(
        isLoading: false,
        error: "Exception: $e",
      );
      return false;
    }
  }

  /// Start liveness detection
  Future<LivenessResponse?> startLiveness() async {
    if (!state.isInitialized) {
      _logger.w("Face SDK not initialized, initializing now...");
      final initialized = await initialize();
      if (!initialized) {
        return null;
      }
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _faceSdk.startLiveness(
        config: LivenessConfig(
          skipStep: [LivenessSkipStep.ONBOARDING_STEP],
        ),
        notificationCompletion: (notification) {
          _logger.d("Liveness notification: ${notification.status}");
        },
      );

      if (result.image != null) {
        _logger.i("Liveness detection completed successfully");
        state = state.copyWith(
          livenessImage: result.image,
          isLoading: false,
        );
        return result;
      } else {
        _logger.w("Liveness detection completed but no image captured");
        state = state.copyWith(isLoading: false);
        return result;
      }
    } catch (e) {
      _logger.e("Exception during liveness detection: $e");
      state = state.copyWith(
        isLoading: false,
        error: "Liveness detection failed: $e",
      );
      return null;
    }
  }

  /// Set document image for comparison
  void setDocumentImage(Uint8List image) {
    state = state.copyWith(documentImage: image);
  }

  /// Match faces between liveness image and document image
  Future<double?> matchFaces() async {
    if (state.livenessImage == null || state.documentImage == null) {
      _logger.w("Cannot match faces: missing images");
      state = state.copyWith(
        error: "Both liveness and document images are required for matching",
      );
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      _logger.d("Creating MatchFacesRequest with liveness image (${state.livenessImage!.length} bytes) and document image (${state.documentImage!.length} bytes)");
      
      final request = MatchFacesRequest([
        MatchFacesImage(state.livenessImage!, ImageType.LIVE),
        MatchFacesImage(state.documentImage!, ImageType.PRINTED),
      ]);

      _logger.d("Calling matchFaces...");
      final response = await _faceSdk.matchFaces(request).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _logger.e("matchFaces timed out after 30 seconds");
          throw TimeoutException("Face matching timed out after 30 seconds");
        },
      );
      _logger.d("matchFaces completed");

      if (response.error != null) {
        _logger.e("Face matching error: ${response.error!.code}: ${response.error!.message}");
        state = state.copyWith(
          isLoading: false,
          error: "Face matching failed: ${response.error!.message}",
        );
        return null;
      }

      if (response.results.isNotEmpty) {
        final matchResult = response.results.first;
        final score = matchResult.similarity;
        _logger.i("Face match score: $score");

        state = state.copyWith(
          matchScore: score,
          isLoading: false,
        );
        return score;
      } else {
        _logger.w("No match results returned");
        state = state.copyWith(
          isLoading: false,
          error: "No face match results",
        );
        return null;
      }
    } catch (e) {
      _logger.e("Exception during face matching: $e");
      state = state.copyWith(
        isLoading: false,
        error: "Face matching failed: $e",
      );
      return null;
    }
  }

  /// Reset the state
  void reset() {
    state = FaceVerificationState(isInitialized: state.isInitialized);
  }
}

/// Provider for face verification
final faceVerificationProvider = StateNotifierProvider<FaceVerificationNotifier, FaceVerificationState>((ref) {
  final faceSdk = ref.watch(faceSdkProvider);
  return FaceVerificationNotifier(faceSdk);
});
