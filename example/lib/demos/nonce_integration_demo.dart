// Created to demonstrate nonce integration for passport authentication
// Shows how universal link nonce validation enhances DMRTD security

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../models/authentication_context.dart';
import '../models/nonce_enhanced_dba_key.dart';
import '../services/universal_link_handler.dart';
import '../services/nonce_validation_service.dart';

/// Demo page to showcase nonce integration features
class NonceIntegrationDemo extends StatefulWidget {
  const NonceIntegrationDemo({Key? key}) : super(key: key);

  @override
  State<NonceIntegrationDemo> createState() => _NonceIntegrationDemoState();
}

class _NonceIntegrationDemoState extends State<NonceIntegrationDemo> {
  final Logger _logger = Logger('NonceIntegrationDemo');
  final UniversalLinkHandler _linkHandler = UniversalLinkHandler();
  final NonceValidationService _nonceValidator = NonceValidationService();
  
  AuthenticationContext? _currentContext;
  NonceEnhancedDBAKey? _enhancedKey;
  String _demoStatus = 'Ready';
  List<String> _demoLogs = [];

  @override
  void initState() {
    super.initState();
    _nonceValidator.initialize();
    _linkHandler.initialize();
    _log('Nonce Integration Demo initialized');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nonce Integration Demo'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildControlButtons(),
            const SizedBox(height: 16),
            _buildContextInfo(),
            const SizedBox(height: 16),
            _buildLogsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Demo Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _demoStatus,
              style: TextStyle(
                color: _getDemoStatusColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_currentContext != null) ...[
              const SizedBox(height: 8),
              Text('Session: ${_currentContext!.sessionId}'),
              Text('Valid: ${_currentContext!.isValid ? 'Yes' : 'No'}'),
              Text('Enhanced: ${_enhancedKey?.hasNonceEnhancement ?? false ? 'Yes' : 'No'}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton(
          onPressed: _generateUniversalLink,
          child: const Text('Generate Universal Link'),
        ),
        ElevatedButton(
          onPressed: _simulateAuthentication,
          child: const Text('Simulate Authentication'),
        ),
        ElevatedButton(
          onPressed: _testReplayAttack,
          child: const Text('Test Replay Attack'),
        ),
        ElevatedButton(
          onPressed: _showValidationStats,
          child: const Text('Show Stats'),
        ),
        ElevatedButton(
          onPressed: _clearLogs,
          child: const Text('Clear Logs'),
        ),
      ],
    );
  }

  Widget _buildContextInfo() {
    if (_currentContext == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No authentication context available'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Authentication Context',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Session ID', _currentContext!.sessionId),
            _buildInfoRow('Nonce', _currentContext!.nonce),
            _buildInfoRow('Created', _currentContext!.createdAt.toIso8601String()),
            _buildInfoRow('Valid', _currentContext!.isValid.toString()),
            _buildInfoRow('Expired', _currentContext!.isExpired.toString()),
            if (_enhancedKey != null) ...[
              const Divider(),
              Text(
                'Enhanced DBA Key',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Has Enhancement', _enhancedKey!.hasNonceEnhancement.toString()),
              _buildInfoRow('Session Bound', _enhancedKey!.isSessionBound.toString()),
              _buildInfoRow('Context Valid', _enhancedKey!.validateAuthContext().toString()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSection() {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Demo Logs',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    itemCount: _demoLogs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Text(
                          _demoLogs[index],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDemoStatusColor() {
    switch (_demoStatus) {
      case 'Success':
        return Colors.green;
      case 'Error':
      case 'Replay Attack Detected':
        return Colors.red;
      case 'Processing':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  void _generateUniversalLink() {
    setState(() {
      _demoStatus = 'Processing';
    });

    final sessionId = 'demo_${DateTime.now().millisecondsSinceEpoch}';
    final nonce = _generateSecureNonce();

    final link = _linkHandler.generateTestLink(
      sessionId: sessionId,
      nonce: nonce,
      additionalParams: {
        'demo': 'true',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    _log('Generated universal link: $link');

    // Simulate processing the link
    _linkHandler.handleUniversalLink(link).then((success) {
      if (success) {
        setState(() {
          _currentContext = _linkHandler.currentAuthContext;
          _demoStatus = 'Universal Link Generated';
        });
        _log('Universal link processed successfully');
      } else {
        setState(() {
          _demoStatus = 'Error';
        });
        _log('Failed to process universal link');
      }
    });
  }

  void _simulateAuthentication() async {
    if (_currentContext == null) {
      _log('No authentication context available. Generate a universal link first.');
      return;
    }

    setState(() {
      _demoStatus = 'Processing';
    });

    _log('Starting nonce validation...');

    try {
      // Validate nonce
      final validationResult = await _nonceValidator.validateNonce(_currentContext!);

      if (validationResult.isValid) {
        _log('✓ Nonce validation successful');

        // Create enhanced DBA key
        _enhancedKey = NonceEnhancedDBAKey(
          'demo123456789', // Demo document number
          DateTime(1990, 1, 1), // Demo date of birth
          DateTime(2030, 12, 31), // Demo expiry date
          authContext: _currentContext,
          paceMode: true,
        );

        _log('✓ Created nonce-enhanced DBA key');
        _log('✓ Key has nonce enhancement: ${_enhancedKey!.hasNonceEnhancement}');
        _log('✓ Key is session bound: ${_enhancedKey!.isSessionBound}');

        // Simulate key operations
        final nonceBytes = _enhancedKey!.nonceAsBytes;
        if (nonceBytes != null) {
          _log('✓ Nonce bytes generated: ${nonceBytes.length} bytes');
        }

        setState(() {
          _demoStatus = 'Success';
        });
        _log('Authentication simulation completed successfully');

      } else {
        setState(() {
          _demoStatus = 'Error';
        });
        _log('✗ Nonce validation failed: ${validationResult.message}');
      }
    } catch (e) {
      setState(() {
        _demoStatus = 'Error';
      });
      _log('✗ Authentication simulation error: $e');
    }
  }

  void _testReplayAttack() async {
    if (_currentContext == null) {
      _log('No authentication context available. Generate a universal link first.');
      return;
    }

    setState(() {
      _demoStatus = 'Processing';
    });

    _log('Testing replay attack prevention...');

    try {
      // First validation should succeed
      final firstResult = await _nonceValidator.validateNonce(_currentContext!);
      _log('First validation: ${firstResult.isValid ? 'Success' : 'Failed'}');

      // Second validation should fail (replay attack)
      final secondResult = await _nonceValidator.validateNonce(_currentContext!);
      _log('Second validation: ${secondResult.isValid ? 'Success' : 'Failed'}');

      if (!secondResult.isValid) {
        setState(() {
          _demoStatus = 'Replay Attack Detected';
        });
        _log('✓ Replay attack successfully detected and prevented');
        _log('Status: ${secondResult.status}');
        _log('Message: ${secondResult.message}');
      } else {
        setState(() {
          _demoStatus = 'Error';
        });
        _log('✗ Replay attack detection failed');
      }
    } catch (e) {
      setState(() {
        _demoStatus = 'Error';
      });
      _log('✗ Replay attack test error: $e');
    }
  }

  void _showValidationStats() {
    final stats = _nonceValidator.getStats();
    _log('Validation Statistics:');
    _log('- Total tracked nonces: ${stats.totalTrackedNonces}');
    _log('- Oldest nonce age: ${stats.oldestNonceAge?.inMinutes ?? 0} minutes');
    _log('- Last cleanup: ${stats.lastCleanupTime ?? 'Never'}');
  }

  String _generateSecureNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logEntry = '[$timestamp] $message';
    
    setState(() {
      _demoLogs.add(logEntry);
      // Keep only last 100 log entries
      if (_demoLogs.length > 100) {
        _demoLogs.removeAt(0);
      }
    });
    
    _logger.info(message);
  }

  void _clearLogs() {
    setState(() {
      _demoLogs.clear();
      _demoStatus = 'Logs Cleared';
    });
  }

  @override
  void dispose() {
    _nonceValidator.dispose();
    _linkHandler.dispose();
    super.dispose();
  }
}