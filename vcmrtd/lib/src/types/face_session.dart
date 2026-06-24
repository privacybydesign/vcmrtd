import 'dart:convert';

/// A face verification session as returned by the passport issuer (and,
/// underneath, by the face verification service) as part of a
/// [VerificationResponse].
///
/// It carries everything the wallet needs to connect to the live verification
/// stream. The `binding_secret` (used by the issuer to authenticate result
/// callbacks) is intentionally never exposed to the wallet.
///
/// See https://github.com/privacybydesign/face-verification-service for the
/// session/streaming protocol.
class FaceSession {
  /// Identifier used in every subsequent face verification call.
  final String faceSessionId;

  /// Base64url-encoded JSON blob (`{ "id": <session_id>, "ws": <websocket_url> }`)
  /// the wallet can use to learn the session id and stream URL.
  final String? faceSessionToken;

  /// WebSocket endpoint the client streams camera frames to. May be absent when
  /// only [faceSessionToken] is provided; use [resolvedWebsocketUrl].
  final String? websocketUrl;

  /// True when a reference portrait was supplied at session creation (the
  /// passport-issuer flow always supplies the DG2 portrait, so this is true).
  final bool bindingKeyReady;

  FaceSession({
    required this.faceSessionId,
    this.faceSessionToken,
    this.websocketUrl,
    this.bindingKeyReady = false,
  });

  factory FaceSession.fromJson(Map<String, dynamic> json) => FaceSession(
    faceSessionId: json['face_session_id'] as String,
    faceSessionToken: json['face_session_token'] as String?,
    websocketUrl: json['websocket_url'] as String?,
    bindingKeyReady: json['binding_key_ready'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'face_session_id': faceSessionId,
    if (faceSessionToken != null) 'face_session_token': faceSessionToken,
    if (websocketUrl != null) 'websocket_url': websocketUrl,
    'binding_key_ready': bindingKeyReady,
  };

  /// The websocket URL to stream to, preferring the explicit [websocketUrl] and
  /// falling back to the `ws` field encoded in [faceSessionToken]. Returns null
  /// when neither is available.
  String? get resolvedWebsocketUrl {
    if (websocketUrl != null && websocketUrl!.isNotEmpty) return websocketUrl;
    final token = faceSessionToken;
    if (token == null || token.isEmpty) return null;
    try {
      var padded = token;
      final mod = padded.length % 4;
      if (mod != 0) padded += '=' * (4 - mod);
      final decoded = utf8.decode(base64Url.decode(padded));
      final map = json.decode(decoded) as Map<String, dynamic>;
      final ws = map['ws'];
      return ws is String && ws.isNotEmpty ? ws : null;
    } catch (_) {
      return null;
    }
  }
}
