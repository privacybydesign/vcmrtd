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

/// Runs a Regula Face SDK liveness session against the Face API backend.
///
/// The client only performs liveness: the session is processed by the Face API
/// (configured via [serviceUrl]) which stores a proven-live portrait and hands
/// back a transaction id. The face match itself is done by the issuer backend
/// against that transaction id — no raw selfie leaves the SDK.
///
/// Abstracted so the verify flow can be tested without the native SDK.
abstract class RegulaFaceService {
  /// Initializes the SDK and points it at the Face API backend. Idempotent.
  Future<void> initialize();

  /// Presents Regula's liveness UI and returns the resulting transaction id.
  Future<RegulaLivenessResult> captureLiveness();
}

class RegulaFaceServiceImpl implements RegulaFaceService {
  RegulaFaceServiceImpl({this.serviceUrl = defaultServiceUrl, FaceSDK? sdk}) : _sdk = sdk ?? FaceSDK.instance;

  /// URL of the Regula Face API. The client runs liveness against this same
  /// service that the issuer uses for matching, so the transaction id resolves
  /// on the backend. The Face API holds the Regula license.
  static const String defaultServiceUrl = 'https://faceapi.staging.yivi.app';

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
    await initialize();
    final liveness = await _sdk.startLiveness();
    if (liveness.error != null) {
      throw StateError('Regula liveness failed: ${liveness.error!.message}');
    }
    return RegulaLivenessResult(
      isLive: liveness.liveness == LivenessStatus.PASSED,
      transactionId: liveness.transactionId,
    );
  }
}
