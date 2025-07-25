// Created for testing deep linking functionality
// Utility to simulate and test universal links in development

import 'dart:math';
import 'package:logging/logging.dart';

import '../services/universal_link_handler.dart';
import '../models/authentication_context.dart';

/// Utility class for testing deep linking functionality
class DeepLinkTestUtility {
  static final Logger _logger = Logger('DeepLinkTestUtility');

  /// Generate a test universal link with random session ID and nonce
  static String generateTestLink({
    String? sessionId,
    String? nonce,
    String scheme = 'mrtdeg',
    String host = 'auth',
    Map<String, String>? additionalParams,
  }) {
    final testSessionId = sessionId ?? _generateRandomId();
    final testNonce = nonce ?? _generateRandomId();
    
    final handler = UniversalLinkHandler();
    return handler.generateTestLink(
      sessionId: testSessionId,
      nonce: testNonce,
      scheme: scheme,
      host: host,
      additionalParams: additionalParams,
    );
  }

  /// Simulate processing a universal link
  static Future<bool> simulateUniversalLink({
    String? sessionId,
    String? nonce,
    Map<String, String>? additionalParams,
  }) async {
    final testLink = generateTestLink(
      sessionId: sessionId,
      nonce: nonce,
      additionalParams: additionalParams,
    );
    
    _logger.info('Simulating universal link: $testLink');
    
    final handler = UniversalLinkHandler();
    return await handler.handleUniversalLink(testLink);
  }

  /// Create a test authentication context directly
  static AuthenticationContext createTestAuthContext({
    String? sessionId,
    String? nonce,
    Map<String, String>? additionalParams,
  }) {
    final params = <String, String>{
      'sessionId': sessionId ?? _generateRandomId(),
      'nonce': nonce ?? _generateRandomId(),
      ...?additionalParams,
    };
    
    return AuthenticationContext.fromUniversalLink(params);
  }

  /// Generate a random ID for testing
  static String _generateRandomId() {
    final random = Random();
    final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(16, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Test various universal link scenarios
  static Future<void> runTestScenarios() async {
    _logger.info('Running deep link test scenarios...');
    
    // Test 1: Valid link with all required parameters
    _logger.info('Test 1: Valid universal link');
    final result1 = await simulateUniversalLink(
      sessionId: 'test-session-123',
      nonce: 'test-nonce-456',
    );
    _logger.info('Test 1 result: $result1');
    
    // Test 2: Link with additional parameters
    _logger.info('Test 2: Link with additional parameters');
    final result2 = await simulateUniversalLink(
      sessionId: 'test-session-456',
      nonce: 'test-nonce-789',
      additionalParams: {
        'userId': '12345',
        'returnUrl': 'https://example.com/callback',
      },
    );
    _logger.info('Test 2 result: $result2');
    
    // Test 3: Invalid link (missing nonce)
    _logger.info('Test 3: Invalid link (missing nonce)');
    final handler = UniversalLinkHandler();
    final invalidLink = 'mrtdeg://auth?sessionId=test-session-789';
    final result3 = await handler.handleUniversalLink(invalidLink);
    _logger.info('Test 3 result: $result3');
    
    // Test 4: Authentication context validation
    _logger.info('Test 4: Authentication context validation');
    final testContext = createTestAuthContext(
      sessionId: 'validation-test',
      nonce: 'validation-nonce',
    );
    _logger.info('Test context valid: ${testContext.isValid}');
    _logger.info('Test context expired: ${testContext.isExpired}');
    
    _logger.info('Deep link test scenarios completed');
  }

  /// Get current authentication status from the handler
  static String getAuthenticationStatus() {
    final handler = UniversalLinkHandler();
    return handler.authStatusDescription;
  }

  /// Clear current authentication context
  static void clearAuthContext() {
    final handler = UniversalLinkHandler();
    handler.clearAuthContext();
    _logger.info('Authentication context cleared');
  }
}