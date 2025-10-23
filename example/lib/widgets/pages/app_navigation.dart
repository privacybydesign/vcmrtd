// Created for UX improvement - Main navigation controller
// Handles the new flow: Choice Screen -> Scanner/Manual -> NFC Guidance -> Results

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/helpers/mrz_data.dart';
import 'package:vcmrtdapp/services/deeplink_service.dart';
import 'package:vcmrtdapp/utils/nonce.dart';
import 'package:vcmrtdapp/widgets/pages/data_screen.dart';
import 'package:vcmrtdapp/widgets/pages/nfc_reading_screen.dart';
import 'package:vcmrtdapp/widgets/pages/scanner_wrapper.dart';

import 'document_selection_screen.dart';
import 'nfc_guidance_screen.dart';
import 'manual_entry_screen.dart';

enum NavigationStep { documentType, passportMrz, edlMrz, manual, nfcHelp, nfcReading, results }

/// Main navigation controller that manages the new UX flow
class AppNavigation extends StatefulWidget {
  const AppNavigation({super.key, required this.deepLinkService});
  final DeepLinkService deepLinkService;

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  NavigationStep _currentStep = NavigationStep.documentType;
  dynamic _mrzResult;
  MrtdData? _mrtdData;
  PassportDataResult? _passportDataResult;

  StreamSubscription? _sub;
  String? _sessionId;
  Uint8List? _nonce;

  // Manual entry data
  String? _manualDocNumber;
  DateTime? _manualDob;
  DateTime? _manualExpiry;

  @override
  void initState() {
    super.initState();
    _sub = widget.deepLinkService.stream.listen((data) async {
      try {
        // Convert string to 8 bytes nonce
        final parsed = stringToUint8List(data.nonce);

        setState(() {
          _sessionId = data.sessionId;
          _nonce = parsed;
        });
      } on ArgumentError {
        // Show warning invalid nonce.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Invalid nonce received'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 3),
            ),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentStep) {
      case NavigationStep.documentType:
        return _buildDocumentSelectionScreen();
      case NavigationStep.passportMrz:
        return _buildPassportScannerScreen();
      case NavigationStep.manual:
        return _buildManualEntryScreen();
      case NavigationStep.nfcHelp:
        return _buildNfcGuidanceScreen();
      case NavigationStep.nfcReading:
        return _buildNfcReadingScreen();
      case NavigationStep.results:
        return _buildDataReadingScreen();
      case NavigationStep.edlMrz:
        return _buildDrivingLicenceScannerScreen();
    }
  }

  Widget _buildDocumentSelectionScreen() {
    return DocumentTypeSelectionScreen(
      onPassportSelected: () {
        setState(() {
          _resetPassportFlow();
          _currentStep = NavigationStep.passportMrz;
        });
      },
      onDrivingLicenceSelected: () {
        setState(() {
          _resetPassportFlow();
          _currentStep = NavigationStep.edlMrz;
        });
      },
    );
  }

  Widget _buildPassportScannerScreen() {
    return ScannerWrapper(
      onMrzScanned: (dynamic result) {
        setState(() {
          _mrzResult = result;
          // Go to NFC guidance
          _currentStep = NavigationStep.nfcHelp;
        });
      },
      onCancel: () {
        setState(() {
          // Back to choice screen
          _currentStep = NavigationStep.documentType;
        });
      },
      onManualEntry: () {
        setState(() {
          _currentStep = NavigationStep.manual;
        });
      },
      onBack: () {
        setState(() {
          // Back to MRZ scanner
          _currentStep = NavigationStep.documentType;
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
          // Back to MRZ scanner
          _currentStep = NavigationStep.passportMrz;
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
          _currentStep = NavigationStep.passportMrz; // Back to scanner/manual entry
        });
      },
      onTroubleshooting: () {
        _showTroubleshootingDialog();
      },
    );
  }

  Widget _buildDataReadingScreen() {
    return DataScreen(
      mrtdData: _mrtdData!,
      passportDataResult: _passportDataResult!,
      sessionId: _sessionId,
      nonce: _nonce,
      onBackPressed: () {
        Navigator.of(context).pop();
        setState(() {
          _resetPassportFlow(clearSession: true);
          _currentStep = NavigationStep.documentType; // Back to doc type selection
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
      sessionId: _sessionId,
      nonce: _nonce,
      onCancel: () {
        setState(() {
          _currentStep = NavigationStep.passportMrz; // Return to scanner screen
        });
      },
      onSuccess: (PassportDataResult passportDataResult, MrtdData data) {
        setState(() {
          _mrtdData = data;
          _passportDataResult = passportDataResult;
          _currentStep = NavigationStep.results; // Show results
        });
      },
    );
  }

  Widget _buildDrivingLicenceScannerScreen() {
    return ScannerWrapper(
      documentType: DocumentType.driverLicense,
      onMrzScanned: (dynamic result) {
        setState(() {
          _mrzResult = result;
          // Go to NFC guidance
          _currentStep = NavigationStep.nfcHelp;
        });
      },
      onCancel: () {
        setState(() {
          // Back to choice screen
          _currentStep = NavigationStep.documentType;
        });
      },
      onManualEntry: () {
        setState(() {
          _currentStep = NavigationStep.manual;
        });
      },
      onBack: () {
        setState(() {
          _currentStep = NavigationStep.documentType;
        });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
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
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        );
      },
    );
  }

  void _resetPassportFlow({bool clearSession = false}) {
    _mrzResult = null;
    _mrtdData = null;
    _passportDataResult = null;
    _manualDocNumber = null;
    _manualDob = null;
    _manualExpiry = null;

    if (clearSession) {
      _nonce = null;
      _sessionId = null;
    }
  }
}
