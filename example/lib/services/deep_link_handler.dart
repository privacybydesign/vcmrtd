import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Deep link handler for MRTD validation URLs
/// Handles mrtd:// scheme URLs with security validation
class DeepLinkHandler {
  static const String _expectedScheme = 'mrtd';
  static const String _expectedHost = 'validate';
  static const int _maxTimestampAge = 300; // 5 minutes in seconds
  static const String _secretKey = 'your-secret-key-here'; // TODO: Load from secure storage
  
  // Track used nonces to prevent replay attacks
  static final Set<String> _usedNonces = <String>{};
  static const MethodChannel _channel = MethodChannel('deep_link_handler');

  /// Initialize deep link handling
  static Future<void> initialize() async {
    if (Platform.isAndroid || Platform.isIOS) {
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Get initial link if app was opened via deep link
      try {
        final String? initialLink = await _channel.invokeMethod('getInitialLink');
        if (initialLink != null) {
          await handleUrl(initialLink);
        }
      } catch (e) {
        debugPrint('Error getting initial link: $e');
      }
    }
  }

  /// Handle method calls from native platforms
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'handleDeepLink':
        final String url = call.arguments as String;
        return await handleUrl(url);
      default:
        throw MissingPluginException('Not implemented: ${call.method}');
    }
  }

  /// Main entry point for handling deep link URLs
  static Future<DeepLinkResult> handleUrl(String url) async {
    try {
      debugPrint('Processing deep link: $url');
      
      // Parse and validate the URL
      final parameters = _parseAndValidate(url);
      
      // Process the validated parameters
      final result = await _processValidationRequest(parameters);
      
      debugPrint('Deep link processed successfully: ${result.sessionId}');
      return result;
      
    } on DeepLinkException catch (e) {
      debugPrint('Deep link error: ${e.message}');
      return DeepLinkResult.error(e.message);
    } catch (e) {
      debugPrint('Unexpected error processing deep link: $e');
      return DeepLinkResult.error('Failed to process deep link');
    }
  }

  /// Parse and validate the deep link URL
  static DeepLinkParameters _parseAndValidate(String url) {
    // Parse the URL
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw DeepLinkException('Invalid URL format');
    }

    // Validate scheme
    if (uri.scheme != _expectedScheme) {
      throw DeepLinkException('Invalid URL scheme: ${uri.scheme}');
    }

    // Validate host
    if (uri.host != _expectedHost) {
      throw DeepLinkException('Invalid URL host: ${uri.host}');
    }

    // Extract and validate parameters
    final sessionId = uri.queryParameters['sessionId'];
    final nonce = uri.queryParameters['nonce'];
    final timestampStr = uri.queryParameters['timestamp'];
    final signature = uri.queryParameters['signature'];

    if (sessionId == null || sessionId.isEmpty) {
      throw DeepLinkException('Missing sessionId parameter');
    }

    if (nonce == null || nonce.isEmpty) {
      throw DeepLinkException('Missing nonce parameter');
    }

    if (timestampStr == null || timestampStr.isEmpty) {
      throw DeepLinkException('Missing timestamp parameter');
    }

    if (signature == null || signature.isEmpty) {
      throw DeepLinkException('Missing signature parameter');
    }

    // Validate sessionId format (UUID)
    if (!_isValidUuid(sessionId)) {
      throw DeepLinkException('Invalid sessionId format');
    }

    // Validate nonce format (Base64)
    try {
      base64Decode(nonce);
    } catch (e) {
      throw DeepLinkException('Invalid nonce format');
    }

    // Validate timestamp
    final timestamp = int.tryParse(timestampStr);
    if (timestamp == null) {
      throw DeepLinkException('Invalid timestamp format');
    }

    if (!_isValidTimestamp(timestamp)) {
      throw DeepLinkException('Timestamp is too old or in the future');
    }

    // Check for replay attacks
    if (_usedNonces.contains(nonce)) {
      throw DeepLinkException('Nonce has already been used (replay attack detected)');
    }

    final parameters = DeepLinkParameters(
      sessionId: sessionId,
      nonce: nonce,
      timestamp: timestamp,
      signature: signature,
    );

    // Validate signature
    if (!_validateSignature(parameters)) {
      throw DeepLinkException('Invalid signature');
    }

    // Mark nonce as used
    _usedNonces.add(nonce);
    
    // Clean up old nonces periodically
    if (_usedNonces.length > 10000) {
      _usedNonces.clear();
    }

    return parameters;
  }

  /// Validate UUID format
  static bool _isValidUuid(String uuid) {
    const uuidRegex = r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
    return RegExp(uuidRegex, caseSensitive: false).hasMatch(uuid);
  }

  /// Validate timestamp (within acceptable time window)
  static bool _isValidTimestamp(int timestamp) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = (now - timestamp).abs();
    return diff <= _maxTimestampAge;
  }

  /// Validate HMAC signature
  static bool _validateSignature(DeepLinkParameters params) {
    final expectedSignature = _generateSignature(params);
    return expectedSignature == params.signature;
  }

  /// Generate HMAC-SHA256 signature for parameters
  static String _generateSignature(DeepLinkParameters params) {
    final message = '${params.sessionId}|${params.nonce}|${params.timestamp}';
    final key = utf8.encode(_secretKey);
    final bytes = utf8.encode(message);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
  }

  /// Process the validation request
  static Future<DeepLinkResult> _processValidationRequest(DeepLinkParameters params) async {
    // TODO: Implement actual validation logic
    // This would typically involve:
    // 1. Retrieving session data from server
    // 2. Initializing MRTD validation workflow
    // 3. Setting up UI for document scanning/validation
    
    debugPrint('Processing validation request for session: ${params.sessionId}');
    
    // Simulate async processing
    await Future.delayed(const Duration(milliseconds: 100));
    
    return DeepLinkResult.success(
      sessionId: params.sessionId,
      timestamp: params.timestamp,
      message: 'Validation session initialized successfully',
    );
  }

  /// Generate a test deep link URL (for testing purposes)
  static String generateTestUrl() {
    final sessionId = _generateUuid();
    final nonce = base64Encode(List.generate(32, (i) => Random().nextInt(256)));
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    final params = DeepLinkParameters(
      sessionId: sessionId,
      nonce: nonce,
      timestamp: timestamp,
      signature: '',
    );
    
    final signature = _generateSignature(params);
    
    return 'mrtd://validate?sessionId=$sessionId&nonce=$nonce&timestamp=$timestamp&signature=$signature';
  }

  /// Generate a UUID v4
  static String _generateUuid() {
    final random = Random();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    
    // Set version (4) and variant bits
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}

/// Deep link parameters extracted from URL
class DeepLinkParameters {
  final String sessionId;
  final String nonce;
  final int timestamp;
  final String signature;

  const DeepLinkParameters({
    required this.sessionId,
    required this.nonce,
    required this.timestamp,
    required this.signature,
  });

  @override
  String toString() {
    return 'DeepLinkParameters(sessionId: $sessionId, nonce: $nonce, timestamp: $timestamp, signature: $signature)';
  }
}

/// Result of deep link processing
class DeepLinkResult {
  final bool success;
  final String? sessionId;
  final int? timestamp;
  final String message;

  const DeepLinkResult._({
    required this.success,
    this.sessionId,
    this.timestamp,
    required this.message,
  });

  factory DeepLinkResult.success({
    required String sessionId,
    required int timestamp,
    required String message,
  }) {
    return DeepLinkResult._(
      success: true,
      sessionId: sessionId,
      timestamp: timestamp,
      message: message,
    );
  }

  factory DeepLinkResult.error(String message) {
    return DeepLinkResult._(
      success: false,
      message: message,
    );
  }

  @override
  String toString() {
    return 'DeepLinkResult(success: $success, sessionId: $sessionId, message: $message)';
  }
}

/// Custom exception for deep link errors
class DeepLinkException implements Exception {
  final String message;

  const DeepLinkException(this.message);

  @override
  String toString() => 'DeepLinkException: $message';
}