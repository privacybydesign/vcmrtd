// Created for UX improvement - Main navigation controller
// Handles the new flow: Choice Screen -> Scanner/Manual -> NFC Guidance -> Results

import 'package:flutter/material.dart';
import 'package:mrtdeg/helpers/mrz_data.dart';
import 'package:mrtdeg/widgets/pages/data_screen.dart';
import 'package:mrtdeg/widgets/pages/nfc_reading_screen.dart';

import 'choice_screen.dart';
import 'nfc_guidance_screen.dart';
import 'manual_entry_screen.dart';
import 'scanner_wrapper.dart';
import '../../models/mrtd_data.dart';
import '../../models/authentication_context.dart';
import '../../services/universal_link_handler.dart';
import 'deep_link_demo_screen.dart';

enum NavigationStep { choice, mrz, manual, nfcHelp, nfcReading, results, universalAuth }

/// Main navigation controller that manages the new UX flow
class AppNavigation extends StatefulWidget {
  final AuthenticationContext? initialAuthContext;

  const AppNavigation({Key? key, this.initialAuthContext}) : super(key: key);

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  NavigationStep _currentStep = NavigationStep.choice;
  MRZResult? _mrzResult;
  MrtdData? _mrtdData;
  AuthenticationContext? _authContext;
  UniversalLinkHandler? _linkHandler;
  
  // Manual entry data
  String? _manualDocNumber;
  DateTime? _manualDob;
  DateTime? _manualExpiry;

  @override
  void initState() {
    super.initState();
    _initializeUniversalLinkHandler();
    
    // Check if we were launched with an authentication context
    if (widget.initialAuthContext != null) {
      _authContext = widget.initialAuthContext;
      _currentStep = NavigationStep.universalAuth;
    }
  }

  Future<void> _initializeUniversalLinkHandler() async {
    _linkHandler = UniversalLinkHandler();
    await _linkHandler!.initialize();
    
    // Listen for incoming authentication contexts
    _linkHandler!.authContextStream.listen((context) {
      if (mounted) {
        setState(() {
          _authContext = context;
          _currentStep = NavigationStep.universalAuth;
        });
      }
    });
  }

  @override
  void dispose() {
    _linkHandler?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentStep) {
      case NavigationStep.choice:
        return _buildChoiceScreen();
      case NavigationStep.mrz:
        return _buildMrzScannerScreen();
      case NavigationStep.manual:
        return _buildManualEntryScreen();
      case NavigationStep.nfcHelp:
        return _buildNfcGuidanceScreen();
      case NavigationStep.nfcReading:
        return _buildNfcReadingScreen();
      case NavigationStep.results:
        return _buildDataReadingScreen();
      case NavigationStep.universalAuth:
        return _buildUniversalAuthScreen();
    }
  }

  Widget _buildChoiceScreen() {
    return ChoiceScreen(
      onScanMrzPressed: () {
        setState(() {
          _currentStep = NavigationStep.mrz;
        });
      },
      onEnterManuallyPressed: () {
        setState(() {
          _currentStep = NavigationStep.manual;
        });
      },
      onHelpPressed: () {
        _showHelpDialog();
      },
      onDeepLinkDemoPressed: () {
        _showDeepLinkDemo();
      },
    );
  }

  Widget _buildMrzScannerScreen() {
    return ScannerWrapper(
      onMrzScanned: (MRZResult result) {
        setState(() {
          _mrzResult = result;
          // Go to NFC guidance
          _currentStep = NavigationStep.nfcHelp;
        });
      },
      onCancel: () {
        setState(() {
          // Back to choice screen
          _currentStep = NavigationStep.choice;
        });
      },
    );
  }

  Widget _buildManualEntryScreen() {
    return ManualEntryScreen(
      onContinue: () {
        setState(() {
          // Go to NFC guidance
          _currentStep = NavigationStep.nfcHelp;
        });
      },
      onBack: () {
        setState(() {
          // Back to choice screen
          _currentStep = NavigationStep.choice;
        });
      },
      onDataEntered: (String docNumber, DateTime dob, DateTime expiry) {
        setState(() {
          _manualDocNumber = docNumber;
          _manualDob = dob;
          _manualExpiry = expiry;
        });
      },
    );
  }

  Widget _buildNfcGuidanceScreen() {
    return NfcGuidanceScreen(
      onStartReading: () {
        // Here we would typically start the actual NFC reading
        // For now, we'll navigate to results
        setState(() {
          _currentStep = NavigationStep.nfcReading;
        });
      },
      onBack: () {
        setState(() {
          _currentStep = NavigationStep.choice; // Back to scanner/manual entry
        });
      },
      onTroubleshooting: () {
        _showTroubleshootingDialog();
      },
    );
  }

  Widget _buildDataReadingScreen() {
    return DataScreen(
      mrtdData: _mrtdData,
      authContext: _authContext,
      onBackPressed: () {
        setState(() {
          _currentStep = NavigationStep.choice; // Back to choice screen
        });
      },
    );
  }

  Widget _buildNfcReadingScreen() {
    return NfcReadingScreen(
      mrzResult: _mrzResult,
      manualDocNumber: _manualDocNumber,
      manualDob: _manualDob,
      manualExpiry: _manualExpiry,
      onCancel: () {
        setState(() {
          _currentStep = NavigationStep.choice; // Return to choice screen
        });
      },
      onDataRead: (MrtdData data) {
        setState(() {
          _mrtdData = data;
          _currentStep = NavigationStep.results; // Show results
        });
      },
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Need Help?'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan MRZ Code (Recommended)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'The Machine Readable Zone (MRZ) is at the bottom of your passport with two lines of text and numbers. Scanning it is faster and more accurate.\n',
              ),
              Text(
                'Enter Details Manually',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'You can also type in your passport information by hand if scanning doesn\'t work or if you prefer this method.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  void _showTroubleshootingDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Troubleshooting Tips'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('If NFC reading isn\'t working:\n'),
              Text('• Make sure NFC is enabled in your phone settings'),
              Text('• Remove any thick phone case or metal objects'),
              Text('• Try different positions on the passport back cover'),
              Text('• Ensure the passport has an electronic chip (newer passports)'),
              Text('• Keep both devices completely still during reading'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUniversalAuthScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Universal Authentication'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _currentStep = NavigationStep.choice;
              _authContext = null;
            });
          },
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.verified_user,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            const Text(
              'Authentication Ready',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'You have been authenticated via universal link.\nSession ID: ${_authContext?.sessionId ?? 'Unknown'}',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${_linkHandler?.authStatusDescription ?? 'No status available'}',
              style: TextStyle(
                fontSize: 14,
                color: (_authContext?.isValid ?? false) ? Colors.green : Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentStep = NavigationStep.choice;
                });
              },
              child: const Text('Continue to Passport Reading'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _currentStep = NavigationStep.nfcHelp;
                });
              },
              child: const Text('Go Directly to NFC Reading'),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Authentication Details:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Session ID: ${_authContext?.sessionId ?? 'N/A'}'),
                    Text('Nonce: ${_authContext?.nonce ?? 'N/A'}'),
                    Text('Created: ${_authContext?.createdAt.toString() ?? 'N/A'}'),
                    Text('Valid: ${_authContext?.isValid ?? false}'),
                    Text('Expired: ${_authContext?.isExpired ?? 'Unknown'}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeepLinkDemo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DeepLinkDemoScreen(),
      ),
    );
  }
}