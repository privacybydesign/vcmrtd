// Created for UX improvement - Main navigation controller
// Handles the new flow: Choice Screen -> Scanner/Manual -> NFC Guidance -> Results

import 'package:flutter/material.dart';
import 'package:vcmrtd/helpers/mrz_data.dart';
import 'package:vcmrtd/widgets/pages/data_screen.dart';
import 'package:vcmrtd/widgets/pages/nfc_reading_screen.dart';

import 'choice_screen.dart';
import 'nfc_guidance_screen.dart';
import 'manual_entry_screen.dart';
import 'scanner_wrapper.dart';
import '../../models/mrtd_data.dart';

enum NavigationStep { choice, mrz, manual, nfcHelp, nfcReading, results }

/// Main navigation controller that manages the new UX flow
class AppNavigation extends StatefulWidget {
  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  NavigationStep _currentStep = NavigationStep.choice;
  MRZResult? _mrzResult;
  MrtdData? _mrtdData;
  
  // Manual entry data
  String? _manualDocNumber;
  DateTime? _manualDob;
  DateTime? _manualExpiry;

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
}