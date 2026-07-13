import 'dart:typed_data';

import 'package:flutter_face_api/flutter_face_api.dart';

/// Outcome of a Regula liveness session: the liveness verdict and the
/// transaction id that references the proven-live, server-held face.
class RegulaLivenessResult {
  final bool isLive;

  /// The Regula liveness transaction id. Sent to the issuer as
  /// `liveness_transaction_id` so the backend can match it against the document
  /// chip portrait. Null if the session produced no transaction.
  final String? transactionId;

  const RegulaLivenessResult({required this.isLive, required this.transactionId});
}

/// Outcome of a full Regula face verification: liveness plus the on-device
/// comparison of the proven-live face against the document chip portrait
/// (DG2 for passports, DG6 for eDLs).
class RegulaFaceResult {
  final bool isLive;

  /// The Regula liveness transaction id, or null if none was produced.
  final String? transactionId;

  /// Similarity (0..1) between the live face and the document portrait, or null
  /// when the match step did not run (e.g. liveness failed or no portrait).
  final double? similarity;

  /// Similarity at or above which the two faces are treated as the same person.
  final double matchThreshold;

  const RegulaFaceResult({required this.isLive, required this.matchThreshold, this.transactionId, this.similarity});

  /// Whether the live face matched the document portrait.
  bool get matched => similarity != null && similarity! >= matchThreshold;

  /// Overall verdict: the subject is live AND matches the document portrait.
  bool get passed => isLive && matched;
}

/// Runs Regula Face SDK sessions against the Face API backend.
///
/// The session is processed by the Face API (configured via [serviceUrl]) which
/// holds the Regula license. [captureLiveness] performs liveness only — the
/// match is left to the issuer backend (used by the web verify flow).
/// [verifyAgainstDocument] additionally compares the proven-live face against
/// the document chip portrait via the SDK's matcher.
///
/// Abstracted so the flows can be tested without the native SDK.
abstract class RegulaFaceService {
  /// Initializes the SDK and points it at the Face API backend. Idempotent.
  Future<void> initialize();

  /// Presents Regula's liveness UI and returns the resulting transaction id.
  Future<RegulaLivenessResult> captureLiveness();

  /// Presents Regula's liveness UI and, once liveness passes, compares the live
  /// face against [documentPortrait] (the DG2/DG6 chip image).
  Future<RegulaFaceResult> verifyAgainstDocument(Uint8List documentPortrait);
}

class RegulaFaceServiceImpl implements RegulaFaceService {
  RegulaFaceServiceImpl({
    this.serviceUrl = defaultServiceUrl,
    this.livenessType = LivenessType.PASSIVE,
    this.matchThreshold = defaultMatchThreshold,
    FaceSDK? sdk,
  }) : _sdk = sdk ?? FaceSDK.instance;

  /// URL of the Regula Face API. The client runs liveness against this same
  /// service that the issuer uses for matching, so the transaction id resolves
  /// on the backend. The Face API holds the Regula license.
  static const String defaultServiceUrl = 'https://faceapi.staging.yivi.app';

  /// Similarity threshold for the document-portrait match. Regula similarity is
  /// a 0..1 value; 0.75 is Regula's recommended verification default.
  static const double defaultMatchThreshold = 0.75;

  /// Regula liveness mode. Defaults to [LivenessType.PASSIVE] — a hands-free
  /// check with no on-screen actions — rather than the SDK default of
  /// [LivenessType.ACTIVE], which prompts the user through movement steps.
  final LivenessType livenessType;

  /// Minimum [RegulaFaceResult.similarity] to treat as a match.
  final double matchThreshold;

  final String serviceUrl;
  final FaceSDK _sdk;

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    // Route liveness processing to the licensed Face API backend. No local
    // license needed with the backend (web-service) model.
    _sdk.serviceUrl = serviceUrl;
    if (!await _sdk.isInitialized()) {
      final (success, error) = await _sdk.initialize();
      if (!success) {
        throw StateError('Regula Face SDK initialization failed: ${error?.message ?? 'unknown error'}');
      }
    }
    _initialized = true;
  }

  @override
  Future<RegulaLivenessResult> captureLiveness() async {
    final liveness = await _runLiveness();
    return RegulaLivenessResult(
      isLive: liveness.liveness == LivenessStatus.PASSED,
      transactionId: liveness.transactionId,
    );
  }

  @override
  Future<RegulaFaceResult> verifyAgainstDocument(Uint8List documentPortrait) async {
    final liveness = await _runLiveness();
    final isLive = liveness.liveness == LivenessStatus.PASSED;
    final liveImage = liveness.image;

    // Only compare against the chip portrait once liveness is proven.
    double? similarity;
    if (isLive && liveImage != null && documentPortrait.isNotEmpty) {
      similarity = await _matchFaces(liveImage, documentPortrait);
    }

    return RegulaFaceResult(
      isLive: isLive,
      transactionId: liveness.transactionId,
      similarity: similarity,
      matchThreshold: matchThreshold,
    );
  }

  Future<LivenessResponse> _runLiveness() async {
    await initialize();
    final liveness = await _sdk.startLiveness(config: LivenessConfig(livenessType: livenessType));
    if (liveness.error != null) {
      throw StateError('Regula liveness failed: ${liveness.error!.message}');
    }
    return liveness;
  }

  /// Compares the live selfie against the RFID chip portrait, returning the
  /// pair similarity (0..1).
  Future<double> _matchFaces(Uint8List liveImage, Uint8List documentPortrait) async {
    final request = MatchFacesRequest([
      MatchFacesImage(liveImage, ImageType.LIVE),
      MatchFacesImage(documentPortrait, ImageType.RFID),
    ]);
    final response = await _sdk.matchFaces(request);
    if (response.error != null) {
      throw StateError('Regula face match failed: ${response.error!.message}');
    }
    final pair = response.results.isNotEmpty ? response.results.first : null;
    if (pair == null || pair.error != null) {
      throw StateError('Regula face match returned no comparable faces');
    }
    return pair.similarity;
  }
}
