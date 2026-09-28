import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idem/providers/active_authenticiation_provider.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/services/regula_face_service.dart';

/// URL of the Regula Face API used for the client-side liveness session.
///
/// When null, face verification is disabled and the verify flow submits no
/// liveness transaction (the issuer then skips face matching). Must point at
/// the same Face API instance the issuer backend uses, so the liveness
/// transaction id resolves server-side.
final faceApiUrlProvider = Provider<String?>((ref) => RegulaFaceServiceImpl.defaultServiceUrl);

/// The Regula liveness service, configured for the current [faceApiUrlProvider].
final regulaFaceServiceProvider = Provider<RegulaFaceService>((ref) {
  final url = ref.watch(faceApiUrlProvider) ?? RegulaFaceServiceImpl.defaultServiceUrl;
  return RegulaFaceServiceImpl(serviceUrl: url);
});

/// The passport issuer's face verification announcement from the current
/// standalone (no QR) scan; null when the issuer didn't offer it.
final issuerFaceVerificationProvider =
    NotifierProvider<ValueNotifier<FaceVerificationConfig?>, FaceVerificationConfig?>(() => ValueNotifier(null));
