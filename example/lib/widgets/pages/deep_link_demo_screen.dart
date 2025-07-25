// Created for demonstrating deep linking functionality
// Example screen showing how to test and use universal links

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../../utils/deep_link_test_utility.dart';
import '../../services/universal_link_handler.dart';
import '../../models/authentication_context.dart';

/// Demo screen for testing deep linking functionality
class DeepLinkDemoScreen extends StatefulWidget {
  @override
  State<DeepLinkDemoScreen> createState() => _DeepLinkDemoScreenState();
}

class _DeepLinkDemoScreenState extends State<DeepLinkDemoScreen> {
  final Logger _logger = Logger('DeepLinkDemoScreen');
  final UniversalLinkHandler _linkHandler = UniversalLinkHandler();
  
  String _status = 'Ready';
  String _lastGeneratedLink = '';
  AuthenticationContext? _currentContext;
  
  final TextEditingController _sessionIdController = TextEditingController();
  final TextEditingController _nonceController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _initializeDemo();
  }

  Future<void> _initializeDemo() async {
    await _linkHandler.initialize();
    
    // Listen for authentication contexts
    _linkHandler.authContextStream.listen((context) {
      if (mounted) {
        setState(() {
          _currentContext = context;
          _status = 'Authentication context received';
        });
      }
    });
    
    // Pre-populate with test values
    _sessionIdController.text = 'demo-session-${DateTime.now().millisecondsSinceEpoch}';
    _nonceController.text = 'demo-nonce-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deep Link Demo'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildLinkGeneratorCard(),
            const SizedBox(height: 16),
            _buildTestButtonsCard(),
            const SizedBox(height: 16),
            _buildCurrentContextCard(),
            const SizedBox(height: 16),
            _buildInstructionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_status),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _currentContext?.isValid == true ? Icons.check_circle : Icons.error,
                  color: _currentContext?.isValid == true ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(_linkHandler.authStatusDescription),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkGeneratorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate Test Link',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _sessionIdController,
              decoration: const InputDecoration(
                labelText: 'Session ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nonceController,
              decoration: const InputDecoration(
                labelText: 'Nonce',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _generateTestLink,
                    child: const Text('Generate Link'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _lastGeneratedLink.isNotEmpty ? _copyToClipboard : null,
                  child: const Text('Copy'),
                ),
              ],
            ),
            if (_lastGeneratedLink.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _lastGeneratedLink,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTestButtonsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _simulateUniversalLink,
                    child: const Text('Simulate Link'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _runTestScenarios,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Run Tests'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _clearAuthContext,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Clear Context'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _refreshStatus,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Refresh'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentContextCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Authentication Context',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_currentContext == null) 
              const Text('No authentication context available')
            else ...[
              _buildContextRow('Session ID', _currentContext!.sessionId),
              _buildContextRow('Nonce', _currentContext!.nonce),
              _buildContextRow('Created', _currentContext!.createdAt.toString()),
              _buildContextRow('Valid', _currentContext!.isValid.toString()),
              _buildContextRow('Expired', _currentContext!.isExpired.toString()),
              if (_currentContext!.additionalData != null) ...[
                const SizedBox(height: 8),
                const Text('Additional Data:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...(_currentContext!.additionalData!.entries.map(
                  (entry) => _buildContextRow(entry.key, entry.value.toString()),
                )),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContextRow(String label, String value) {
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

  Widget _buildInstructionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Instructions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('1. Generate a test link with custom or default values'),
            const Text('2. Copy the link and test it in a browser or simulator'),
            const Text('3. Or use "Simulate Link" to test directly in the app'),
            const Text('4. Check the authentication context after processing'),
            const Text('5. Use "Run Tests" to execute comprehensive test scenarios'),
            const SizedBox(height: 8),
            const Text(
              'Expected Link Format:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'mrtdeg://auth?sessionId=<value>&nonce=<value>',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _generateTestLink() {
    final link = DeepLinkTestUtility.generateTestLink(
      sessionId: _sessionIdController.text.trim(),
      nonce: _nonceController.text.trim(),
    );
    
    setState(() {
      _lastGeneratedLink = link;
      _status = 'Test link generated';
    });
    
    _logger.info('Generated test link: $link');
  }

  Future<void> _simulateUniversalLink() async {
    if (_lastGeneratedLink.isEmpty) {
      _generateTestLink();
    }
    
    setState(() {
      _status = 'Processing universal link...';
    });
    
    final success = await _linkHandler.handleUniversalLink(_lastGeneratedLink);
    
    setState(() {
      _status = success ? 'Universal link processed successfully' : 'Failed to process universal link';
    });
  }

  Future<void> _runTestScenarios() async {
    setState(() {
      _status = 'Running test scenarios...';
    });
    
    await DeepLinkTestUtility.runTestScenarios();
    
    setState(() {
      _status = 'Test scenarios completed (check logs)';
    });
  }

  void _clearAuthContext() {
    _linkHandler.clearAuthContext();
    setState(() {
      _currentContext = null;
      _status = 'Authentication context cleared';
    });
  }

  void _refreshStatus() {
    setState(() {
      _currentContext = _linkHandler.currentAuthContext;
      _status = 'Status refreshed';
    });
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _lastGeneratedLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }

  @override
  void dispose() {
    _sessionIdController.dispose();
    _nonceController.dispose();
    super.dispose();
  }
}