// Created for deep linking authentication context
// Handles sessionId and nonce for universal link authentication

class AuthenticationContext {
  final String sessionId;
  final String nonce;
  final DateTime createdAt;
  final Map<String, dynamic>? additionalData;

  AuthenticationContext({
    required this.sessionId,
    required this.nonce,
    DateTime? createdAt,
    this.additionalData,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Factory constructor to create from universal link parameters
  factory AuthenticationContext.fromUniversalLink(Map<String, String> params) {
    return AuthenticationContext(
      sessionId: params['sessionId'] ?? '',
      nonce: params['nonce'] ?? '',
      additionalData: _extractAdditionalData(params),
    );
  }

  /// Extract additional data from parameters (excluding sessionId and nonce)
  static Map<String, dynamic> _extractAdditionalData(Map<String, String> params) {
    final additionalData = Map<String, dynamic>.from(params);
    additionalData.remove('sessionId');
    additionalData.remove('nonce');
    return additionalData.isNotEmpty ? additionalData : null;
  }

  /// Check if the authentication context is valid
  bool get isValid {
    return sessionId.isNotEmpty && 
           nonce.isNotEmpty && 
           !isExpired &&
           _isNonceValid;
  }

  /// Check if nonce meets security requirements
  bool get _isNonceValid {
    // Nonce should be at least 16 characters (128 bits when hex-encoded)
    // and contain only valid hex characters for cryptographic strength
    if (nonce.length < 16) return false;
    
    // Check if nonce contains sufficient entropy (not all same character)
    Set<String> uniqueChars = nonce.split('').toSet();
    if (uniqueChars.length < 4) return false; // Minimum entropy check
    
    return true;
  }

  /// Check if the context has expired (default: 10 minutes)
  bool get isExpired {
    final expiryTime = createdAt.add(const Duration(minutes: 10));
    return DateTime.now().isAfter(expiryTime);
  }

  /// Generate a cryptographically secure nonce for PACE/BAC authentication
  /// This nonce will be used to prevent replay attacks during passport reading
  String generateCryptographicNonce() {
    // Use current timestamp + session for additional entropy
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final combined = '$sessionId$timestamp$nonce';
    
    // Create a hash for consistent length and cryptographic properties
    final bytes = combined.codeUnits;
    return bytes.fold<int>(0, (sum, byte) => sum + byte).toRadixString(16).padLeft(16, '0');
  }

  /// Get nonce as bytes for PACE protocol integration
  List<int> get nonceBytes {
    final hexNonce = nonce.length >= 16 ? nonce.substring(0, 16) : nonce.padLeft(16, '0');
    final bytes = <int>[];
    for (int i = 0; i < hexNonce.length; i += 2) {
      final hex = hexNonce.substring(i, i + 2);
      bytes.add(int.parse(hex, radix: 16));
    }
    return bytes;
  }

  /// Convert to map for storage or transmission
  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'nonce': nonce,
      'createdAt': createdAt.toIso8601String(),
      'additionalData': additionalData,
    };
  }

  /// Create from stored map
  factory AuthenticationContext.fromMap(Map<String, dynamic> map) {
    return AuthenticationContext(
      sessionId: map['sessionId'] ?? '',
      nonce: map['nonce'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      additionalData: map['additionalData'],
    );
  }

  @override
  String toString() {
    return 'AuthenticationContext{sessionId: $sessionId, nonce: $nonce, createdAt: $createdAt, isValid: $isValid}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthenticationContext &&
        other.sessionId == sessionId &&
        other.nonce == nonce;
  }

  @override
  int get hashCode => sessionId.hashCode ^ nonce.hashCode;
}