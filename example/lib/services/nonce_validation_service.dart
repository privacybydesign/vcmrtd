// Created for nonce validation and replay attack prevention
// Manages nonce usage tracking and validation for secure authentication

import 'dart:collection';
import 'package:logging/logging.dart';
import 'package:crypto/crypto.dart';
import 'package:dmrtd/extensions.dart';

import '../models/authentication_context.dart';

/// Service for validating nonces and preventing replay attacks
class NonceValidationService {
  static final NonceValidationService _instance = NonceValidationService._internal();
  factory NonceValidationService() => _instance;
  NonceValidationService._internal();

  final Logger _logger = Logger('NonceValidationService');
  
  // Track used nonces with timestamps for cleanup
  final Map<String, DateTime> _usedNonces = <String, DateTime>{};
  final Queue<String> _nonceQueue = Queue<String>();
  
  // Configuration
  static const int _maxStoredNonces = 10000;
  static const Duration _nonceValidityPeriod = Duration(minutes: 30);
  static const Duration _cleanupInterval = Duration(minutes: 5);
  
  DateTime? _lastCleanup;

  /// Initialize the service
  void initialize() {
    _logger.info('Initializing Nonce Validation Service');
    _performPeriodicCleanup();
  }

  /// Validate a nonce from authentication context
  Future<NonceValidationResult> validateNonce(AuthenticationContext authContext) async {
    try {
      _logger.debug('Validating nonce for session: ${authContext.sessionId}');
      
      // Basic context validation
      if (!authContext.isValid) {
        return NonceValidationResult.invalid('Authentication context is invalid or expired');
      }

      // Nonce format validation
      if (!_isValidNonceFormat(authContext.nonce)) {
        return NonceValidationResult.invalid('Nonce format is invalid');
      }

      // Create composite key for tracking (session + nonce)
      final compositeKey = _createCompositeKey(authContext.sessionId, authContext.nonce);
      
      // Check for replay attack
      if (_isNonceUsed(compositeKey)) {
        _logger.warning('Replay attack detected - nonce already used: ${authContext.sessionId}');
        return NonceValidationResult.replayAttack('Nonce has already been used');
      }

      // Check nonce age
      if (_isNonceTooOld(authContext)) {
        return NonceValidationResult.expired('Authentication context has expired');
      }

      // Mark nonce as used
      _markNonceAsUsed(compositeKey);
      
      // Perform cleanup if needed
      _performPeriodicCleanup();
      
      _logger.info('Nonce validation successful for session: ${authContext.sessionId}');
      return NonceValidationResult.valid();
      
    } catch (e, stackTrace) {
      _logger.severe('Error validating nonce', e, stackTrace);
      return NonceValidationResult.error('Internal validation error');
    }
  }

  /// Validate nonce format and entropy
  bool _isValidNonceFormat(String nonce) {
    // Minimum length check
    if (nonce.length < 16) {
      _logger.debug('Nonce too short: ${nonce.length}');
      return false;
    }

    // Check for sufficient entropy (not all same character)
    final uniqueChars = nonce.split('').toSet();
    if (uniqueChars.length < 4) {
      _logger.debug('Nonce lacks sufficient entropy');
      return false;
    }

    // Check for reasonable character distribution
    if (nonce.length > 32) {
      final expectedUnique = (nonce.length * 0.3).ceil();
      if (uniqueChars.length < expectedUnique) {
        _logger.debug('Nonce entropy insufficient for length');
        return false;
      }
    }

    return true;
  }

  /// Create composite key for nonce tracking
  String _createCompositeKey(String sessionId, String nonce) {
    final combined = '$sessionId:$nonce';
    final bytes = combined.codeUnits;
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Check if nonce has been used
  bool _isNonceUsed(String compositeKey) {
    return _usedNonces.containsKey(compositeKey);
  }

  /// Check if nonce is too old
  bool _isNonceTooOld(AuthenticationContext authContext) {
    final age = DateTime.now().difference(authContext.createdAt);
    return age > _nonceValidityPeriod;
  }

  /// Mark nonce as used
  void _markNonceAsUsed(String compositeKey) {
    _usedNonces[compositeKey] = DateTime.now();
    _nonceQueue.add(compositeKey);
    
    // Prevent unlimited growth
    if (_usedNonces.length > _maxStoredNonces) {
      _removeOldestNonce();
    }
  }

  /// Remove oldest nonce to prevent memory growth
  void _removeOldestNonce() {
    if (_nonceQueue.isNotEmpty) {
      final oldest = _nonceQueue.removeFirst();
      _usedNonces.remove(oldest);
    }
  }

  /// Perform periodic cleanup of expired nonces
  void _performPeriodicCleanup() {
    final now = DateTime.now();
    
    // Only cleanup if enough time has passed
    if (_lastCleanup != null && 
        now.difference(_lastCleanup!) < _cleanupInterval) {
      return;
    }

    _logger.debug('Performing nonce cleanup');
    final beforeCount = _usedNonces.length;
    
    // Remove expired nonces
    final expiredKeys = <String>[];
    _usedNonces.forEach((key, timestamp) {
      if (now.difference(timestamp) > _nonceValidityPeriod) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      _usedNonces.remove(key);
      _nonceQueue.remove(key); // Also remove from queue
    }

    final afterCount = _usedNonces.length;
    _logger.debug('Cleanup completed: removed ${beforeCount - afterCount} expired nonces');
    
    _lastCleanup = now;
  }

  /// Get validation statistics
  NonceValidationStats getStats() {
    return NonceValidationStats(
      totalTrackedNonces: _usedNonces.length,
      oldestNonceAge: _getOldestNonceAge(),
      lastCleanupTime: _lastCleanup,
    );
  }

  /// Get age of oldest tracked nonce
  Duration? _getOldestNonceAge() {
    if (_usedNonces.isEmpty) return null;
    
    DateTime? oldest;
    for (final timestamp in _usedNonces.values) {
      if (oldest == null || timestamp.isBefore(oldest)) {
        oldest = timestamp;
      }
    }
    
    return oldest != null ? DateTime.now().difference(oldest) : null;
  }

  /// Clear all tracked nonces (for testing or reset)
  void clearAll() {
    _logger.info('Clearing all tracked nonces');
    _usedNonces.clear();
    _nonceQueue.clear();
    _lastCleanup = null;
  }

  /// Dispose of service resources
  void dispose() {
    _logger.info('Disposing Nonce Validation Service');
    clearAll();
  }
}

/// Result of nonce validation
class NonceValidationResult {
  final bool isValid;
  final NonceValidationStatus status;
  final String? message;

  const NonceValidationResult._(this.isValid, this.status, this.message);

  factory NonceValidationResult.valid() => 
      const NonceValidationResult._(true, NonceValidationStatus.valid, null);
  
  factory NonceValidationResult.invalid(String message) => 
      NonceValidationResult._(false, NonceValidationStatus.invalid, message);
  
  factory NonceValidationResult.replayAttack(String message) => 
      NonceValidationResult._(false, NonceValidationStatus.replayAttack, message);
  
  factory NonceValidationResult.expired(String message) => 
      NonceValidationResult._(false, NonceValidationStatus.expired, message);
  
  factory NonceValidationResult.error(String message) => 
      NonceValidationResult._(false, NonceValidationStatus.error, message);

  @override
  String toString() {
    return 'NonceValidationResult{isValid: $isValid, status: $status, message: $message}';
  }
}

/// Status of nonce validation
enum NonceValidationStatus {
  valid,
  invalid,
  replayAttack,
  expired,
  error,
}

/// Statistics about nonce validation
class NonceValidationStats {
  final int totalTrackedNonces;
  final Duration? oldestNonceAge;
  final DateTime? lastCleanupTime;

  const NonceValidationStats({
    required this.totalTrackedNonces,
    this.oldestNonceAge,
    this.lastCleanupTime,
  });

  @override
  String toString() {
    return 'NonceValidationStats{totalTracked: $totalTrackedNonces, '
        'oldestAge: ${oldestNonceAge?.inMinutes}min, '
        'lastCleanup: $lastCleanupTime}';
  }
}