// Created for UX improvement - Main navigation controller
// Handles the new flow: Choice Screen -> Scanner/Manual -> NFC Guidance -> Results

import 'package:flutter/material.dart';
import 'package:mrtdeg/helpers/mrz_data.dart';

import 'choice_screen.dart';
import 'nfc_guidance_screen.dart';
import 'mrtd_home_page.dart';
import 'scanner_wrapper.dart';
import '../../models/mrtd_data.dart';

/// Main navigation controller that manages the new UX flow
class AppNavigation extends StatefulWidget {
  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  int _currentStep = 0;
  MRZResult? _mrzResult;
  MrtdData? _mrtdData;
  bool _useManualEntry = false;

  @override
  Widget build(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return _buildChoiceScreen();
      case 1:
        return _useManualEntry 
            ? _buildManualEntryScreen() 
            : _buildMrzScannerScreen();
      case 2:
        return _buildNfcGuidanceScreen();
      case 3:
        return _buildResultsScreen();
      default:
        return _buildChoiceScreen();
    }
  }

  Widget _buildChoiceScreen() {
    return ChoiceScreen(
      onScanMrzPressed: () {
        setState(() {
          _useManualEntry = false;
          _currentStep = 1;
        });
      },
      onEnterManuallyPressed: () {
        setState(() {
          _useManualEntry = true;
          _currentStep = 1;
        });
      },
      onHelpPressed: () {
        _showHelpDialog();
      },
    );
  }

  Widget _buildMrzScannerScreen() {
    return ScannerWrapper(
      onMrzScanned: (MRZResult result) {
        setState(() {
          _mrzResult = result;
          _currentStep = 2; // Go to NFC guidance
        });
      },
      onCancel: () {
        setState(() {
          _currentStep = 0; // Back to choice screen
        });
      },
    );
  }

  Widget _buildManualEntryScreen() {
    return MrtdHomePage(
      onNfcReadyPressed: () {
        setState(() {
          _currentStep = 2; // Go to NFC guidance
        });
      },
      onBackPressed: () {
        setState(() {
          _currentStep = 0; // Back to choice screen
        });
      },
      initialMrzData: _mrzResult,
      showChoiceNavigation: true,
    );
  }

  Widget _buildNfcGuidanceScreen() {
    return NfcGuidanceScreen(
      onStartReading: () {
        // Here we would typically start the actual NFC reading
        // For now, we'll navigate to results
        setState(() {
          _currentStep = 3;
        });
      },
      onBack: () {
        setState(() {
          _currentStep = 1; // Back to scanner/manual entry
        });
      },
      onTroubleshooting: () {
        _showTroubleshootingDialog();
      },
    );
  }

  Widget _buildResultsScreen() {
    return MrtdHomePage(
      onBackPressed: () {
        setState(() {
          _currentStep = 0; // Back to choice screen
          _mrzResult = null;
          _mrtdData = null;
        });
      },
      initialMrzData: _mrzResult,
      showChoiceNavigation: true,
      showResultsOnly: true,
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
}