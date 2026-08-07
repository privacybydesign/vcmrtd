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

/// Runs Regula liveness sessions against the Face API backend.
///
/// The session is processed by the Face API (configured via [serviceUrl]) which
/// holds the Regula license. This is liveness-only: [captureLiveness] produces a
/// `liveness_transaction_id`, and the 1:1 face match is performed by the issuer
/// backend against that transaction. The client never matches faces itself — the
/// bundled `flutter_face_core_basic` supports liveness only, not `matchFaces`.
///
/// Abstracted so the flows can be tested without the native SDK.
abstract class RegulaFaceService {
  /// Initializes the SDK and points it at the Face API backend. Idempotent.
  Future<void> initialize();

  /// Presents Regula's liveness UI and returns the resulting transaction id.
  Future<RegulaLivenessResult> captureLiveness();
}

class RegulaFaceServiceImpl implements RegulaFaceService {
  RegulaFaceServiceImpl({this.serviceUrl = defaultServiceUrl, this.livenessType = LivenessType.PASSIVE, FaceSDK? sdk})
    : _sdk = sdk ?? FaceSDK.instance;

  /// URL of the Regula Face API. The client runs liveness against this same
  /// service that the issuer uses for matching, so the transaction id resolves
  /// on the backend. The Face API holds the Regula license.
  static const String defaultServiceUrl = 'https://faceapi.staging.yivi.app';

  /// Regula liveness mode. Defaults to [LivenessType.PASSIVE] — a hands-free
  /// check with no on-screen actions — rather than the SDK default of
  /// [LivenessType.ACTIVE], which prompts the user through movement steps.
  final LivenessType livenessType;

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

  Future<LivenessResponse> _runLiveness() async {
    await initialize();
    final liveness = await _sdk.startLiveness(config: LivenessConfig(livenessType: livenessType));
    if (liveness.error != null) {
      throw StateError('Regula liveness failed: ${liveness.error!.message}');
    }
    return liveness;
  }
}
