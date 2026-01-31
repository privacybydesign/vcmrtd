/// FaceTec SDK Configuration
///
/// Configure these values for your FaceTec integration.
/// Device key available at: https://dev.facetec.com/account
class FaceTecConfig {
  /// Device Key Identifier from FaceTec developer account
  /// Get this from: https://dev.facetec.com/account
  static const String deviceKeyIdentifier = "dlktYkAWrXGTIPAdNzlDRqpgLb7LKN6B";

  /// The URL to call to process FaceTec SDK Sessions
  /// In production, use your own middleware endpoint that forwards to FaceTec Server
  /// See: https://dev.facetec.com/security-best-practices#server-rest-endpoint-security
  static const String baseURL = "https://api.facetec.com/api/v4/biometrics";

  /// FaceScan Encryption Key for your application
  /// See: https://dev.facetec.com/facemap-encryption-keys
  static const String publicFaceScanEncryptionKey = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5PxZ3DLj+zP6T6HFgzzk
M77LdzP3fojBoLasw7EfzvLMnJNUlyRb5m8e5QyyJxI+wRjsALHvFgLzGwxM8ehz
DqqBZed+f4w33GgQXFZOS4AOvyPbALgCYoLehigLAbbCNTkeY5RDcmmSI/sbp+s6
mAiAKKvCdIqe17bltZ/rfEoL3gPKEfLXeN549LTj3XBp0hvG4loQ6eC1E1tRzSkf
GJD4GIVvR+j12gXAaftj3ahfYxioBH7F7HQxzmWkwDyn3bqU54eaiB7f0ftsPpWM
ceUaqkL2DZUvgN0efEJjnWy5y1/Gkq5GGWCROI9XG/SwXJ30BbVUehTbVcD70+ZF
8QIDAQAB
-----END PUBLIC KEY-----''';
}
