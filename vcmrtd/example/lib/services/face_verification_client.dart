import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final _log = Logger('FaceVerificationStream');

// Client for the privacybydesign/face-verification-service session streaming
// protocol. The passport issuer creates a session bound to the chip's DG2
// portrait and hands the wallet a [FaceSession]; the wallet derives the same
// binding key from the raw DG2 bytes it read over NFC, connects to the live
// stream, and streams signed camera frames for verification + liveness.
//
// This mirrors the reference web client (`frontend/composables/useFaceVerification.ts`)
// so the crypto matches the backend byte-for-byte:
//   binding_key = HKDF-SHA256(ikm=session_id, salt=SHA256(photo), info="yivi_face_binding_v1")
//   handshake   = HMAC-SHA256(binding_key, session_id)
//   frame mac   = HMAC-SHA256(binding_key, frame_bytes || sequence_be64)

const _bindingInfo = 'yivi_face_binding_v1';

/// Derives the 32-byte binding key shared with the face verification service.
///
/// [photoBytes] must be the **raw DG2 bytes** read from the passport chip — the
/// exact bytes the issuer forwarded to the face service as the reference
/// portrait — because the salt is `SHA256(reference_photo)`.
Uint8List deriveBindingKey(String sessionId, List<int> photoBytes) {
  final salt = sha256.convert(photoBytes).bytes; // 32 bytes
  final ikm = utf8.encode(sessionId);

  // HKDF-Extract: PRK = HMAC-SHA256(salt, ikm)
  final prk = Hmac(sha256, salt).convert(ikm).bytes;

  // HKDF-Expand for L=32 (single block): T(1) = HMAC(PRK, info || 0x01)
  final info = utf8.encode(_bindingInfo);
  final okm = Hmac(sha256, prk).convert([...info, 1]).bytes;

  return Uint8List.fromList(okm.sublist(0, 32));
}

Uint8List _hmac(List<int> key, List<int> data) => Uint8List.fromList(Hmac(sha256, key).convert(data).bytes);

Uint8List _sequenceBe64(int sequence) {
  final bytes = ByteData(8)..setUint64(0, sequence, Endian.big);
  return bytes.buffer.asUint8List();
}

/// Result of processing a single streamed frame.
class FaceFrameResult {
  final int sequence;
  final String status;
  final double? matchScore;
  final double? livenessScore;
  final double? recognitionDistance;
  final bool faceDetected;
  final bool isSpoofed;
  final int framesProcessed;
  final bool verificationComplete;

  FaceFrameResult({
    required this.sequence,
    required this.status,
    required this.faceDetected,
    required this.isSpoofed,
    required this.framesProcessed,
    required this.verificationComplete,
    this.matchScore,
    this.livenessScore,
    this.recognitionDistance,
  });

  factory FaceFrameResult.fromJson(Map<String, dynamic> json) => FaceFrameResult(
    sequence: (json['sequence'] as num?)?.toInt() ?? 0,
    status: json['status'] as String? ?? 'processing',
    matchScore: (json['match_score'] as num?)?.toDouble(),
    livenessScore: (json['liveness_score'] as num?)?.toDouble(),
    recognitionDistance: (json['recognition_distance'] as num?)?.toDouble(),
    faceDetected: json['face_detected'] as bool? ?? false,
    isSpoofed: json['is_spoofed'] as bool? ?? false,
    framesProcessed: (json['frames_processed'] as num?)?.toInt() ?? 0,
    verificationComplete: json['verification_complete'] as bool? ?? false,
  );
}

/// Final verification outcome.
class FaceVerificationComplete {
  final String result; // "success" | "failed" | "unknown"
  final double? matchConfidence;
  final bool? livenessPassed;
  final int framesProcessed;
  final int verificationDurationMs;

  FaceVerificationComplete({
    required this.result,
    required this.framesProcessed,
    required this.verificationDurationMs,
    this.matchConfidence,
    this.livenessPassed,
  });

  bool get isSuccess => result == 'success';

  factory FaceVerificationComplete.fromJson(Map<String, dynamic> json) => FaceVerificationComplete(
    result: json['result'] as String? ?? 'unknown',
    matchConfidence: (json['match_confidence'] as num?)?.toDouble(),
    livenessPassed: json['liveness_passed'] as bool?,
    framesProcessed: (json['frames_processed'] as num?)?.toInt() ?? 0,
    verificationDurationMs: (json['verification_duration_ms'] as num?)?.toInt() ?? 0,
  );
}

/// Thrown when the stream cannot be established or the server rejects it.
class FaceVerificationException implements Exception {
  final String message;
  FaceVerificationException(this.message);
  @override
  String toString() => 'FaceVerificationException: $message';
}

/// Drives a single face verification session over a WebSocket.
///
/// Lifecycle: [connect] (opens the socket and performs the signed handshake) →
/// [sendFrame] repeatedly (each call resolves with that frame's result) →
/// [onComplete] fires once when the server finishes → [dispose].
class FaceVerificationStream {
  FaceVerificationStream({
    required this.websocketUrl,
    required this.sessionId,
    required this.bindingKey,
  });

  final String websocketUrl;
  final String sessionId;
  final Uint8List bindingKey;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  int _sequence = 0;
  bool _authenticated = false;
  bool _completed = false;

  Completer<void>? _handshakeCompleter;
  Completer<FaceFrameResult?>? _pendingFrame;

  /// Fires once when the server reports `verification_complete`.
  final Completer<FaceVerificationComplete> _completion = Completer<FaceVerificationComplete>();
  Future<FaceVerificationComplete> get onComplete => _completion.future;

  bool get isCompleted => _completed;

  /// Opens the socket and completes the HMAC handshake. Throws
  /// [FaceVerificationException] on failure/timeout.
  Future<void> connect({Duration timeout = const Duration(seconds: 10)}) async {
    final uri = Uri.parse(websocketUrl);
    _handshakeCompleter = Completer<void>();

    _log.info('Connecting to face verification stream: $uri (session $sessionId)');
    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready.timeout(timeout);
      _log.info('WebSocket open, sending handshake');
    } catch (e) {
      _log.warning('Could not open stream to $uri: $e');
      throw FaceVerificationException('Could not open stream: $e');
    }

    _subscription = _channel!.stream.listen(
      _onMessage,
      onError: (Object e) {
        _log.warning('Stream error: $e');
        _failPending('Stream error: $e');
      },
      onDone: () {
        _log.info('Stream closed (code ${_channel?.closeCode}, reason ${_channel?.closeReason})');
        _failPending('Stream closed');
      },
    );

    // Send handshake: { type, session_id, signature = base64(HMAC(key, session_id)) }
    final signature = _hmac(bindingKey, utf8.encode(sessionId));
    _send({
      'type': 'handshake',
      'session_id': sessionId,
      'signature': base64.encode(signature),
    });

    try {
      await _handshakeCompleter!.future.timeout(timeout);
      _log.info('Handshake acknowledged');
    } on TimeoutException {
      _log.warning('Handshake timed out after ${timeout.inSeconds}s');
      throw FaceVerificationException('Handshake timed out');
    }
  }

  /// Sends one JPEG frame and resolves with its [FaceFrameResult]. Returns null
  /// if the stream is closed/complete or another frame is already in flight
  /// (callers should drop the frame and try the next one).
  Future<FaceFrameResult?> sendFrame(Uint8List jpegBytes) {
    if (!_authenticated || _completed || _channel == null) return Future.value(null);
    if (_pendingFrame != null) return Future.value(null); // single frame in flight

    _sequence++;
    final seq = _sequence;
    final mac = _hmac(bindingKey, <int>[...jpegBytes, ..._sequenceBe64(seq)]);

    final completer = Completer<FaceFrameResult?>();
    _pendingFrame = completer;
    _send({
      'type': 'frame',
      'sequence': seq,
      'data': base64.encode(jpegBytes),
      'mac': base64.encode(mac),
    });
    return completer.future;
  }

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> message;
    try {
      message = json.decode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (message['type']) {
      case 'handshake_ack':
        _authenticated = true;
        if (!(_handshakeCompleter?.isCompleted ?? true)) _handshakeCompleter!.complete();
        break;
      case 'frame_result':
        final result = FaceFrameResult.fromJson(message);
        _resolvePending(result);
        if (result.verificationComplete && !_completed) {
          // verification_complete message follows; surface a best-effort result
          // now in case the socket closes before it arrives.
          _maybeComplete(FaceVerificationComplete.fromJson(message));
        }
        break;
      case 'verification_complete':
        final completion = FaceVerificationComplete.fromJson(message);
        _log.info('Verification complete: result=${completion.result} '
            'match=${completion.matchConfidence} liveness=${completion.livenessPassed} '
            'frames=${completion.framesProcessed}');
        _maybeComplete(completion);
        break;
      case 'error':
        final err = message['error']?.toString() ?? 'unknown error';
        _log.warning('Server error message: $err');
        if (!(_handshakeCompleter?.isCompleted ?? true)) {
          _handshakeCompleter!.completeError(FaceVerificationException(err));
        }
        _failPending(err);
        if (!_completion.isCompleted) {
          _completion.completeError(FaceVerificationException(err));
        }
        break;
    }
  }

  void _maybeComplete(FaceVerificationComplete completion) {
    _completed = true;
    if (!_completion.isCompleted) _completion.complete(completion);
  }

  void _resolvePending(FaceFrameResult? result) {
    final pending = _pendingFrame;
    _pendingFrame = null;
    if (pending != null && !pending.isCompleted) pending.complete(result);
  }

  void _failPending(String _) => _resolvePending(null);

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(json.encode(message));
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _resolvePending(null);
  }
}
