// Created for nonce-enhanced passport authentication
// Extends DBAKey to integrate universal link nonce for enhanced security

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dmrtd/dmrtd.dart';
import 'package:dmrtd/extensions.dart';
import 'package:logging/logging.dart';

import 'authentication_context.dart';

/// Enhanced DBAKey that integrates nonce from universal link authentication
/// for stronger replay attack prevention and session binding
class NonceEnhancedDBAKey extends DBAKey {
  static final Logger _log = Logger("NonceEnhancedDBAKey");
  
  final AuthenticationContext? _authContext;
  final String? _customNonce;
  
  /// Constructor that takes optional authentication context with nonce
  NonceEnhancedDBAKey(
    String mrtdNumber, 
    DateTime dateOfBirth, 
    DateTime dateOfExpiry, {
    bool paceMode = false,
    AuthenticationContext? authContext,
    String? customNonce,
  }) : _authContext = authContext,
       _customNonce = customNonce,
       super(mrtdNumber, dateOfBirth, dateOfExpiry, paceMode: paceMode);

  /// Factory constructor from MRZ with authentication context
  factory NonceEnhancedDBAKey.fromMRZWithAuth(
    MRZ mrz, {
    AuthenticationContext? authContext,
    String? customNonce,
    bool paceMode = false,
  }) {
    return NonceEnhancedDBAKey(
      mrz.documentNumber,
      mrz.dateOfBirth,
      mrz.dateOfExpiry,
      authContext: authContext,
      customNonce: customNonce,
      paceMode: paceMode,
    );
  }

  /// Get the nonce to use for authentication
  String? get effectiveNonce {
    if (_customNonce != null && _customNonce!.isNotEmpty) {
      return _customNonce;
    }
    if (_authContext != null && _authContext!.isValid) {
      return _authContext!.nonce;
    }
    return null;
  }

  /// Check if nonce-enhanced authentication is available
  bool get hasNonceEnhancement => effectiveNonce != null;

  /// Generate nonce-enhanced key seed
  /// Combines traditional DBA key seed with nonce for stronger security
  @override
  Uint8List get keySeed {
    final originalSeed = super.keySeed;
    
    if (!hasNonceEnhancement) {
      _log.debug("No nonce available, using standard DBA key seed");
      return originalSeed;
    }

    final nonce = effectiveNonce!;
    _log.debug("Enhancing key seed with nonce for stronger security");
    
    // Combine original seed with nonce using cryptographic hash
    final nonceBytes = Uint8List.fromList(nonce.codeUnits);
    final combined = Uint8List.fromList([...originalSeed, ...nonceBytes]);
    
    // Use SHA-256 for stronger mixing, then truncate to required length
    final hash = sha256.convert(combined);
    final enhancedSeed = Uint8List.fromList(hash.bytes.sublist(0, seedLen));
    
    _log.sdDebug("Enhanced seed generated with nonce integration");
    return enhancedSeed;
  }

  /// Get nonce as bytes for PACE protocol
  Uint8List? get nonceAsBytes {
    final nonce = effectiveNonce;
    if (nonce == null) return null;
    
    // Convert nonce to bytes with proper encoding
    if (nonce.length >= 16 && _isValidHex(nonce)) {
      // If nonce is hex-encoded, decode it
      return _hexToBytes(nonce);
    } else {
      // Otherwise, use UTF-8 encoding and hash to consistent length
      final bytes = Uint8List.fromList(nonce.codeUnits);
      final hash = sha1.convert(bytes);
      return Uint8List.fromList(hash.bytes.sublist(0, 8)); // 8 bytes for nonce
    }
  }

  /// Enhanced K-pi calculation with nonce integration
  @override
  Uint8List Kpi(CipherAlgorithm cipherAlgorithm, KEY_LENGTH keyLength) {
    final baseKpi = super.Kpi(cipherAlgorithm, keyLength);
    
    if (!hasNonceEnhancement) {
      return baseKpi;
    }

    _log.debug("Enhancing K-pi with nonce for PACE authentication");
    
    // XOR the nonce bytes with K-pi for additional entropy
    final nonceBytes = nonceAsBytes;
    if (nonceBytes != null && nonceBytes.length >= 8) {
      final enhancedKpi = Uint8List.fromList(baseKpi);
      for (int i = 0; i < 8 && i < enhancedKpi.length; i++) {
        enhancedKpi[i] ^= nonceBytes[i % nonceBytes.length];
      }
      _log.sdDebug("K-pi enhanced with nonce XOR operation");
      return enhancedKpi;
    }
    
    return baseKpi;
  }

  /// Validate that the authentication context is still valid for use
  bool validateAuthContext() {
    if (_authContext == null) {
      _log.debug("No authentication context to validate");
      return true; // No context is valid (fallback mode)
    }
    
    if (!_authContext!.isValid) {
      _log.warning("Authentication context is invalid or expired");
      return false;
    }
    
    _log.debug("Authentication context validation passed");
    return true;
  }

  /// Generate authentication challenge incorporating nonce
  Uint8List generateNonceChallenge(Uint8List originalChallenge) {
    if (!hasNonceEnhancement) {
      return originalChallenge;
    }

    final nonceBytes = nonceAsBytes;
    if (nonceBytes == null) {
      return originalChallenge;
    }

    _log.debug("Generating nonce-enhanced authentication challenge");
    
    // Combine original challenge with nonce
    final combined = Uint8List.fromList([...originalChallenge, ...nonceBytes]);
    final hash = sha256.convert(combined);
    
    // Return challenge of same length as original
    return Uint8List.fromList(hash.bytes.sublist(0, originalChallenge.length));
  }

  /// Helper method to check if string is valid hex
  bool _isValidHex(String str) {
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(str);
  }

  /// Helper method to convert hex string to bytes
  Uint8List _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      final hexByte = hex.substring(i, i + 2);
      bytes.add(int.parse(hexByte, radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  /// Get authentication session ID if available
  String? get sessionId => _authContext?.sessionId;

  /// Check if this key is bound to a specific session
  bool get isSessionBound => sessionId != null && sessionId!.isNotEmpty;

  @override
  String toString() {
    _log.warning("NonceEnhancedDBAKey.toString() called. This contains sensitive data!");
    return "NonceEnhancedDBAKey{mrtdNumber: $mrtdNumber, "
        "dateOfBirth: ${_dob}, dateOfExpiry: ${_doe}, "
        "hasNonce: $hasNonceEnhancement, "
        "sessionBound: $isSessionBound, "
        "authValid: ${_authContext?.isValid ?? 'N/A'}}";
  }
}