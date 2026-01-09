import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:vcmrtdapp/facetec_config.dart';
import 'package:vcmrtdapp/processors/facetec_session_processor.dart';

/// State for FaceTec face verification
class FaceTecVerificationState {
  final bool isInitialized;
  final bool isLoading;
  final bool isProcessing;
  final Uint8List? livenessImage;
  final Uint8List? documentImage;
  final double? matchScore;
  final String? error;
  final String? sessionStatus;

  FaceTecVerificationState({
    this.isInitialized = false,
    this.isLoading = false,
    this.isProcessing = false,
    this.livenessImage,
    this.documentImage,
    this.matchScore,
    this.error,
    this.sessionStatus,
  });

  FaceTecVerificationState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isProcessing,
    Uint8List? livenessImage,
    Uint8List? documentImage,
    double? matchScore,
    String? error,
    String? sessionStatus,
  }) {
    return FaceTecVerificationState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      livenessImage: livenessImage ?? this.livenessImage,
      documentImage: documentImage ?? this.documentImage,
      matchScore: matchScore ?? this.matchScore,
      error: error ?? this.error,
      sessionStatus: sessionStatus ?? this.sessionStatus,
    );
  }
}

/// Provider for FaceTec face verification state and operations
class FaceTecVerificationNotifier
    extends StateNotifier<FaceTecVerificationState> {
  final Logger _logger = Logger();
  static const _channel = MethodChannel('com.facetec.sdk');

  // Session processor for handling server communication
  final FaceTecSessionProcessor _sessionProcessor;

  FaceTecVerificationNotifier()
      : _sessionProcessor = FaceTecSessionProcessor(),
        super(FaceTecVerificationState());

  /// Initialize the FaceTec SDK
  Future<bool> initialize() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      if (FaceTecConfig.deviceKeyIdentifier.isEmpty) {
        _logger.e("Device key identifier is empty");
        state = state.copyWith(
          isLoading: false,
          error: "Device key identifier not configured",
        );
        return false;
      }

      await _channel.invokeMethod("initialize", {
        "deviceKeyIdentifier": FaceTecConfig.deviceKeyIdentifier,
        "publicFaceScanEncryptionKey":
            FaceTecConfig.publicFaceScanEncryptionKey,
      });

      _logger.i("FaceTec SDK initialized successfully");
      state = state.copyWith(isInitialized: true, isLoading: false);
      return true;
    } on PlatformException catch (e) {
      _logger.e("FaceTec SDK initialization error: ${e.code}: ${e.message}");
      state = state.copyWith(
        isLoading: false,
        error: "${e.code}: ${e.message}",
      );
      return false;
    } catch (e) {
      _logger.e("Exception during FaceTec SDK initialization: $e");
      state = state.copyWith(
        isLoading: false,
        error: "Exception: $e",
      );
      return false;
    }
  }

  /// Start 3D liveness check
  ///
  /// This will open the FaceTec UI and capture a live face scan
  /// Returns true if the liveness check was initiated successfully
  Future<bool> startLiveness() async {
    if (!state.isInitialized) {
      _logger.w("FaceTec SDK not initialized, initializing now...");
      final initialized = await initialize();
      if (!initialized) {
        return false;
      }
    }

    state = state.copyWith(isProcessing: true, error: null);

    try {
      await _channel.invokeMethod("startLivenessCheck");

      _logger.i("Liveness check started successfully");
      state = state.copyWith(
        sessionStatus: "Liveness check in progress",
      );
      return true;
    } on PlatformException catch (e) {
      _logger.e("Liveness check error: ${e.code}: ${e.message}");
      state = state.copyWith(
        isProcessing: false,
        error: "${e.code}: ${e.message}",
      );
      return false;
    } catch (e) {
      _logger.e("Exception during liveness check: $e");
      state = state.copyWith(
        isProcessing: false,
        error: "Liveness check failed: $e",
      );
      return false;
    }
  }

  /// Set document image for comparison
  ///
  /// [image] - The face photo extracted from the document (DG2)
  void setDocumentImage(Uint8List image) {
    state = state.copyWith(documentImage: image);
    _logger.d("Document image set (${image.length} bytes)");
  }

  /// Complete the liveness session
  ///
  /// Called when the session completes successfully
  /// In a real implementation, this would be called from native code
  /// after receiving the final result from the FaceTec server
  void onSessionComplete({
    Uint8List? livenessImage,
    double? matchScore,
  }) {
    state = state.copyWith(
      isProcessing: false,
      livenessImage: livenessImage,
      matchScore: matchScore,
      sessionStatus: "completed",
    );
    _logger.i("Session completed with match score: $matchScore");
  }

  /// Handle session error
  void onSessionError(String error) {
    state = state.copyWith(
      isProcessing: false,
      error: error,
      sessionStatus: "error",
    );
    _logger.e("Session error: $error");
  }

  /// Reset the state
  void reset() {
    state = FaceTecVerificationState(isInitialized: state.isInitialized);
  }
}

/// Provider for FaceTec verification
final faceTecVerificationProvider =
    StateNotifierProvider<FaceTecVerificationNotifier,
        FaceTecVerificationState>((ref) {
  return FaceTecVerificationNotifier();
});
