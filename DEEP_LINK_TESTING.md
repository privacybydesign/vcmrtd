# MRTD Deep Link Testing Guide

## Overview
This document outlines the testing approach for MRTD (Machine Readable Travel Document) deep linking functionality, focusing on the `mrtd://` URL scheme for document validation workflows.

## Deep Link URL Structure

### Primary URL Format
```
mrtd://validate?sessionId=<uuid>&nonce=<base64>&timestamp=<unix>&signature=<hmac>
```

### Parameters Specification
- **sessionId**: UUID v4 format (e.g., `123e4567-e89b-12d3-a456-426614174000`)
- **nonce**: Base64-encoded random value (32 bytes minimum)
- **timestamp**: Unix timestamp (seconds since epoch)
- **signature**: HMAC-SHA256 signature of the concatenated parameters

### Example URL
```
mrtd://validate?sessionId=550e8400-e29b-41d4-a716-446655440000&nonce=YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY3ODkw&timestamp=1753450432&signature=a7b8c9d0e1f2g3h4i5j6k7l8m9n0o1p2q3r4s5t6u7v8w9x0y1z2
```

## Platform Configurations

### Android Configuration
**File**: `/example/android/app/src/main/AndroidManifest.xml`

```xml
<!-- Deep Link Intent Filter for MRTD Validation -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="mrtd" 
          android:host="validate" />
</intent-filter>

<!-- Additional intent filter for HTTP/HTTPS fallback -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https"
          android:host="mrtd.app"
          android:pathPrefix="/validate" />
</intent-filter>
```

**Key Features:**
- `android:autoVerify="true"`: Enables App Link verification
- Dual scheme support: Custom `mrtd://` and HTTPS fallback
- Host validation for security

### iOS Configuration
**File**: `/example/ios/Runner/Info.plist`

```xml
<!-- Deep Link URL Schemes Configuration -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.example.mrtdeg.deeplink</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>mrtd</string>
        </array>
    </dict>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.example.mrtdeg.https</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>https</string>
        </array>
    </dict>
</array>

<!-- Associated Domains for Universal Links -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:mrtd.app</string>
</array>
```

**Key Features:**
- Multiple URL scheme support
- Universal Links via Associated Domains
- Proper bundle identification

## Security Considerations

### 1. URL Validation
- **Host Verification**: Only accept `validate` as the host for `mrtd://` scheme
- **Parameter Validation**: Ensure all required parameters are present
- **Format Validation**: Validate UUID, Base64, and timestamp formats

### 2. Signature Verification
- **HMAC-SHA256**: Use a secure shared secret for signature generation
- **Timestamp Validation**: Reject URLs older than 5 minutes to prevent replay attacks
- **Nonce Tracking**: Store used nonces temporarily to prevent reuse

### 3. Content Security
- **Input Sanitization**: Sanitize all URL parameters before processing
- **Rate Limiting**: Implement rate limiting for deep link processing
- **Origin Validation**: Verify the link originates from trusted sources

### 4. Privacy Protection
- **Session Isolation**: Each sessionId should be unique and time-bound
- **Data Minimization**: Only include necessary parameters in URLs
- **Secure Storage**: Store sensitive data server-side, referenced by sessionId

## Testing Approach

### 1. Unit Tests

#### URL Parsing Tests
```dart
void testDeepLinkUrlParsing() {
  // Test valid URL parsing
  final url = 'mrtd://validate?sessionId=550e8400-e29b-41d4-a716-446655440000&nonce=YWJjZGVmZ2hpams&timestamp=1753450432&signature=abc123';
  final parsed = DeepLinkParser.parse(url);
  
  expect(parsed.sessionId, equals('550e8400-e29b-41d4-a716-446655440000'));
  expect(parsed.nonce, isNotNull);
  expect(parsed.timestamp, equals(1753450432));
  expect(parsed.signature, equals('abc123'));
}

void testInvalidUrlHandling() {
  // Test malformed URLs
  expect(() => DeepLinkParser.parse('invalid://url'), throwsA(isA<FormatException>()));
  expect(() => DeepLinkParser.parse('mrtd://invalid'), throwsA(isA<ValidationException>()));
}
```

#### Security Validation Tests
```dart
void testSignatureValidation() {
  final params = DeepLinkParameters(
    sessionId: '550e8400-e29b-41d4-a716-446655440000',
    nonce: 'YWJjZGVmZ2hpams',
    timestamp: 1753450432,
  );
  
  final validSignature = SecurityHelper.generateSignature(params, 'secret_key');
  expect(SecurityHelper.validateSignature(params, validSignature, 'secret_key'), isTrue);
  expect(SecurityHelper.validateSignature(params, 'invalid_sig', 'secret_key'), isFalse);
}

void testTimestampValidation() {
  final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final oldTimestamp = currentTime - 600; // 10 minutes ago
  final futureTimestamp = currentTime + 600; // 10 minutes future
  
  expect(SecurityHelper.isValidTimestamp(currentTime), isTrue);
  expect(SecurityHelper.isValidTimestamp(oldTimestamp), isFalse);
  expect(SecurityHelper.isValidTimestamp(futureTimestamp), isFalse);
}
```

### 2. Integration Tests

#### Platform Integration Tests
```dart
void testAndroidDeepLinkHandling() {
  // Test Android intent handling
  final testUrl = 'mrtd://validate?sessionId=test&nonce=test&timestamp=${DateTime.now().millisecondsSinceEpoch ~/ 1000}&signature=test';
  
  // Simulate intent reception
  when(mockMethodChannel.invokeMethod('handleDeepLink', testUrl))
    .thenAnswer((_) async => {'success': true});
    
  // Verify proper handling
  expect(DeepLinkHandler.handleUrl(testUrl), completes);
}

void testiOSUrlSchemeHandling() {
  // Test iOS URL scheme handling
  final testUrl = 'mrtd://validate?sessionId=test&nonce=test&timestamp=${DateTime.now().millisecondsSinceEpoch ~/ 1000}&signature=test';
  
  // Test URL handling through platform channel
  verify(mockMethodChannel.invokeMethod('handleDeepLink', testUrl)).called(1);
}
```

### 3. End-to-End Tests

#### Complete Flow Tests
```dart
void testCompleteValidationFlow() async {
  // 1. Generate valid deep link
  final sessionId = Uuid().v4();
  final nonce = base64Encode(List.generate(32, (i) => Random().nextInt(256)));
  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final signature = SecurityHelper.generateSignature(sessionId, nonce, timestamp, SECRET_KEY);
  
  final deepLinkUrl = 'mrtd://validate?sessionId=$sessionId&nonce=$nonce&timestamp=$timestamp&signature=$signature';
  
  // 2. Handle deep link
  final result = await DeepLinkHandler.handleUrl(deepLinkUrl);
  expect(result.success, isTrue);
  
  // 3. Verify session initialization
  final session = await SessionManager.getSession(sessionId);
  expect(session, isNotNull);
  expect(session.status, equals(SessionStatus.active));
  
  // 4. Test validation workflow
  final validationResult = await MRTDValidator.validateDocument(session);
  expect(validationResult, isNotNull);
}
```

### 4. Security Tests

#### Malicious URL Tests
```dart
void testMaliciousUrlHandling() {
  final maliciousUrls = [
    'mrtd://validate?sessionId=<script>alert("xss")</script>',
    'mrtd://validate?sessionId=../../../etc/passwd',
    'mrtd://validate?sessionId=DROP%20TABLE%20sessions',
    'mrtd://validate?nonce=${String.fromCharCodes(List.filled(10000, 65))}', // Buffer overflow attempt
  ];
  
  for (final url in maliciousUrls) {
    expect(() => DeepLinkParser.parse(url), throwsA(isA<SecurityException>()));
  }
}

void testReplayAttackPrevention() {
  final params = generateValidParams();
  final url = buildDeepLinkUrl(params);
  
  // First use should succeed
  expect(DeepLinkHandler.handleUrl(url), completes);
  
  // Second use should fail (replay attack)
  expect(() => DeepLinkHandler.handleUrl(url), throwsA(isA<ReplayAttackException>()));
}
```

### 5. Performance Tests

#### Load Testing
```dart
void testConcurrentDeepLinkHandling() async {
  final futures = List.generate(100, (i) async {
    final params = generateValidParams();
    final url = buildDeepLinkUrl(params);
    return DeepLinkHandler.handleUrl(url);
  });
  
  final results = await Future.wait(futures);
  expect(results.where((r) => r.success).length, equals(100));
}
```

## Manual Testing Procedures

### 1. Android Testing
```bash
# Test custom scheme deep link
adb shell am start -W -a android.intent.action.VIEW -d "mrtd://validate?sessionId=550e8400-e29b-41d4-a716-446655440000&nonce=YWJjZGVmZ2hpams&timestamp=1753450432&signature=abc123" com.example.mrtdeg

# Test HTTPS fallback
adb shell am start -W -a android.intent.action.VIEW -d "https://mrtd.app/validate?sessionId=550e8400-e29b-41d4-a716-446655440000&nonce=YWJjZGVmZ2hpams&timestamp=1753450432&signature=abc123" com.example.mrtdeg

# Verify intent filters
adb shell dumpsys package com.example.mrtdeg | grep -A 20 "intent-filter"
```

### 2. iOS Testing
```bash
# Test custom scheme (using iOS Simulator)
xcrun simctl openurl booted "mrtd://validate?sessionId=550e8400-e29b-41d4-a716-446655440000&nonce=YWJjZGVmZ2hpams&timestamp=1753450432&signature=abc123"

# Test Universal Links
xcrun simctl openurl booted "https://mrtd.app/validate?sessionId=550e8400-e29b-41d4-a716-446655440000&nonce=YWJjZGVmZ2hpams&timestamp=1753450432&signature=abc123"
```

### 3. Cross-Platform Testing
- Test URL generation and parsing consistency
- Verify security measures work identically
- Confirm user experience consistency
- Test fallback mechanisms

## Error Handling

### 1. URL Format Errors
- Invalid scheme detection
- Missing parameter handling
- Malformed parameter handling

### 2. Security Errors
- Invalid signature handling
- Expired timestamp handling
- Replay attack detection

### 3. System Errors
- Network connectivity issues
- App state handling
- Resource unavailability

## Performance Metrics

### Key Performance Indicators
- **Deep Link Processing Time**: < 100ms
- **Security Validation Time**: < 50ms
- **App Launch Time**: < 2 seconds
- **Memory Usage**: < 50MB during processing

### Monitoring
- Track deep link success/failure rates
- Monitor security validation performance
- Log all security events for analysis
- Track user engagement through deep links

## Compliance and Standards

### Security Standards
- **OWASP Mobile Top 10**: Address all relevant security risks
- **ISO/IEC 27001**: Information security management
- **NIST Cybersecurity Framework**: Risk management approach

### Privacy Standards
- **GDPR**: Data protection and privacy
- **CCPA**: Consumer privacy rights
- **PIPEDA**: Personal information protection

## Conclusion

This testing approach ensures comprehensive validation of the MRTD deep linking functionality, covering security, performance, and user experience aspects. Regular testing and monitoring will help maintain the integrity and reliability of the deep link system.

## Test Execution Checklist

- [ ] Unit tests for URL parsing
- [ ] Unit tests for security validation
- [ ] Integration tests for platform handling
- [ ] End-to-end validation flow tests
- [ ] Security and penetration tests
- [ ] Performance and load tests
- [ ] Manual testing on both platforms
- [ ] Cross-platform consistency verification
- [ ] Error handling validation
- [ ] Compliance and security audit