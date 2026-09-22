import 'dart:typed_data';

import 'package:json_annotation/json_annotation.dart';

part 'passport_data_result.g.dart';

@JsonSerializable()
class RawDocumentData {
  @JsonKey(name: 'data_groups')
  final Map<String, String> dataGroups;

  @JsonKey(name: 'ef_sod')
  final String efSod;

  @JsonKey(name: 'session_id')
  final String? sessionId;

  @JsonKey(name: 'nonce')
  @Uint8ListConverter()
  final Uint8List? nonce;

  @JsonKey(name: 'aa_signature')
  @Uint8ListConverter()
  final Uint8List? aaSignature;

  /// Identifier of a completed Regula liveness transaction. The issuer compares
  /// the live face captured during that session against the document chip
  /// portrait for face verification (optional).
  @JsonKey(name: 'liveness_transaction_id', includeIfNull: false)
  final String? livenessTransactionId;

  /// Identifier of the Iris face session the issuer opened at verification
  /// (see `VerificationResponse.faceSession`). The issuer pulls the verdict
  /// for it at issuance (optional; Iris method only).
  @JsonKey(name: 'face_session_id', includeIfNull: false)
  final String? faceSessionId;

  /// Verdict of the on-device Iris SDK: whether the live face it captured
  /// matched the chip portrait (optional; `iris_ondevice` method only).
  ///
  /// A `false` is sent rather than swallowed, so the issuer records the failed
  /// attempt and answers for it; absent means the step was never run. The
  /// issuer cannot check either value — see
  /// `irmamobile/docs/on-device-iris-face-verification-plan.md` §3.
  @JsonKey(name: 'face_ondevice_passed', includeIfNull: false)
  final bool? faceOndevicePassed;

  /// SHA-256, hex, of the portrait bytes the on-device SDK matched against.
  /// The issuer compares it with the portrait it authenticated, so a verdict
  /// obtained against another document is refused (optional; `iris_ondevice`
  /// method only).
  @JsonKey(name: 'face_ondevice_portrait_sha256', includeIfNull: false)
  final String? faceOndevicePortraitSha256;

  /// Which attempt at the face verification step this issuance follows within
  /// the current document flow, starting at 1 (optional; recording only).
  @JsonKey(name: 'face_attempt', includeIfNull: false)
  final int? faceAttempt;

  /// Milliseconds from the user confirming the face verification intro to the
  /// evidence being in hand (optional; recording only).
  @JsonKey(name: 'face_duration_ms', includeIfNull: false)
  final int? faceDurationMs;

  RawDocumentData({
    required this.dataGroups,
    required this.efSod,
    this.sessionId,
    this.nonce,
    this.aaSignature,
    this.livenessTransactionId,
    this.faceSessionId,
    this.faceOndevicePassed,
    this.faceOndevicePortraitSha256,
    this.faceAttempt,
    this.faceDurationMs,
  });

  RawDocumentData copyWith({
    String? livenessTransactionId,
    String? faceSessionId,
    bool? faceOndevicePassed,
    String? faceOndevicePortraitSha256,
    int? faceAttempt,
    int? faceDurationMs,
  }) => RawDocumentData(
    dataGroups: dataGroups,
    efSod: efSod,
    sessionId: sessionId,
    nonce: nonce,
    aaSignature: aaSignature,
    livenessTransactionId: livenessTransactionId ?? this.livenessTransactionId,
    faceSessionId: faceSessionId ?? this.faceSessionId,
    faceOndevicePassed: faceOndevicePassed ?? this.faceOndevicePassed,
    faceOndevicePortraitSha256: faceOndevicePortraitSha256 ?? this.faceOndevicePortraitSha256,
    faceAttempt: faceAttempt ?? this.faceAttempt,
    faceDurationMs: faceDurationMs ?? this.faceDurationMs,
  );

  factory RawDocumentData.fromJson(Map<String, dynamic> json) => _$RawDocumentDataFromJson(json);

  Map<String, dynamic> toJson() => _$RawDocumentDataToJson(this);
}

/// Converter to encode/decode Uint8List <-> hex string
class Uint8ListConverter implements JsonConverter<Uint8List?, String?> {
  const Uint8ListConverter();

  @override
  Uint8List? fromJson(String? json) {
    if (json == null) return null;
    final buffer = Uint8List(json.length ~/ 2);
    for (var i = 0; i < json.length; i += 2) {
      buffer[i ~/ 2] = int.parse(json.substring(i, i + 2), radix: 16);
    }
    return buffer;
  }

  @override
  String? toJson(Uint8List? object) {
    if (object == null) return null;
    final StringBuffer buffer = StringBuffer();
    for (final b in object) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
