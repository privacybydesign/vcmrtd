import 'dart:typed_data';

import 'package:vcmrtd/vcmrtd.dart';

/// Everything the face verification screen needs to run a remote verification.
///
/// The remote verification + liveness flow needs a [faceSession] (started by the
/// passport issuer from the chip's DG2 portrait) and the [referencePhotoBytes]
/// — the **raw DG2 bytes** read over NFC — from which the wallet derives the
/// same binding key the issuer forwarded to the face service.
class FaceVerificationArgs {
  /// Extracted portrait image (JPEG/JP2) used only for on-screen display.
  final Uint8List? portraitImageBytes;

  /// Raw DG2 bytes read from the chip, used to derive the binding key. Null when
  /// no chip portrait is available (e.g. driving licence), which disables the
  /// remote verification path.
  final Uint8List? referencePhotoBytes;

  /// The face verification session, present only when the issuer has the face
  /// verification integration enabled.
  final FaceSession? faceSession;

  final DateTime? issueDate;

  const FaceVerificationArgs({
    this.portraitImageBytes,
    this.referencePhotoBytes,
    this.faceSession,
    this.issueDate,
  });

  /// True when a remote verification stream can be started.
  bool get canVerifyRemotely =>
      faceSession != null && referencePhotoBytes != null && referencePhotoBytes!.isNotEmpty;
}
