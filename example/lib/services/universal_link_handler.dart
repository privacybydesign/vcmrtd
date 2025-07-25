// Created for deep linking functionality
// Handles incoming universal links and manages authentication flow

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logging/logging.dart';

import '../models/authentication_context.dart';

/// Service to handle universal link processing and navigation
class UniversalLinkHandler {
  static final UniversalLinkHandler _instance = UniversalLinkHandler._internal();
  factory UniversalLinkHandler() => _instance;
  UniversalLinkHandler._internal();

  final Logger _logger = Logger('UniversalLinkHandler');
  final StreamController<AuthenticationContext> _linkStreamController = 
      StreamController<AuthenticationContext>.broadcast();

  AuthenticationContext? _currentAuthContext;

  /// Stream of authentication contexts from universal links
  Stream<AuthenticationContext> get authContextStream => _linkStreamController.stream;

  /// Current authentication context (if any)
  AuthenticationContext? get currentAuthContext => _currentAuthContext;

  /// Initialize the universal link handler
  Future<void> initialize() async {
    _logger.info('Initializing Universal Link Handler');
    
    // Note: In a real implementation, you would set up platform-specific
    // listeners here. For now, we'll provide a method to manually handle links.
    
    _logger.info('Universal Link Handler initialized');
  }

  /// Process an incoming universal link
  Future<bool> handleUniversalLink(String link) async {
    try {
      _logger.info('Processing universal link: $link');
      
      final uri = Uri.parse(link);
      final params = Map<String, String>.from(uri.queryParameters);
      
      // Validate required parameters
      if (!_validateLinkParameters(params)) {
        _logger.warning('Invalid link parameters: $params');
        return false;
      }

      // Create authentication context
      final authContext = AuthenticationContext.fromUniversalLink(params);
      
      if (!authContext.isValid) {
        _logger.warning('Invalid authentication context: $authContext');
        return false;
      }

      _currentAuthContext = authContext;
      _linkStreamController.add(authContext);
      
      _logger.info('Successfully processed universal link for session: ${authContext.sessionId}');
      return true;
      
    } catch (e, stackTrace) {
      _logger.severe('Error processing universal link: $e', e, stackTrace);
      return false;
    }
  }

  /// Validate that link has required parameters
  bool _validateLinkParameters(Map<String, String> params) {
    return params.containsKey('sessionId') && 
           params.containsKey('nonce') &&
           params['sessionId']!.isNotEmpty &&
           params['nonce']!.isNotEmpty;
  }

  /// Generate a test universal link (for development/testing)
  String generateTestLink({
    required String sessionId,
    required String nonce,
    String scheme = 'mrtdeg',
    String host = 'auth',
    Map<String, String>? additionalParams,
  }) {
    final uri = Uri(
      scheme: scheme,
      host: host,
      queryParameters: {
        'sessionId': sessionId,
        'nonce': nonce,
        ...?additionalParams,
      },
    );
    
    return uri.toString();
  }

  /// Launch a URL (for external authentication flows)
  Future<bool> launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri);
      
      if (launched) {
        _logger.info('Successfully launched URL: $url');
      } else {
        _logger.warning('Failed to launch URL: $url');
      }
      
      return launched;
    } catch (e) {
      _logger.severe('Error launching URL: $e');
      return false;
    }
  }

  /// Clear current authentication context
  void clearAuthContext() {
    _logger.info('Clearing authentication context');
    _currentAuthContext = null;
  }

  /// Check if we have a valid authentication context
  bool get hasValidAuthContext {
    return _currentAuthContext?.isValid ?? false;
  }

  /// Get authentication status as a readable string
  String get authStatusDescription {
    if (_currentAuthContext == null) {
      return 'No authentication context';
    }
    
    if (_currentAuthContext!.isExpired) {
      return 'Authentication context expired';
    }
    
    if (_currentAuthContext!.isValid) {
      return 'Authentication context valid (Session: ${_currentAuthContext!.sessionId})';
    }
    
    return 'Invalid authentication context';
  }

  /// Dispose resources
  void dispose() {
    _logger.info('Disposing Universal Link Handler');
    _linkStreamController.close();
    _currentAuthContext = null;
  }
}