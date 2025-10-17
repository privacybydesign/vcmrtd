// Created for UX improvement - Main navigation controller
// Handles the new flow: Choice Screen -> Scanner/Manual -> NFC Guidance -> Results

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vcmrtdapp/helpers/mrz_data.dart';
import 'package:vcmrtdapp/models/passport_result.dart';
import 'package:vcmrtdapp/services/deeplink_service.dart';
import 'package:vcmrtdapp/utils/nonce.dart';
import 'package:vcmrtdapp/widgets/pages/passport_data_screen.dart';
import 'package:vcmrtdapp/widgets/pages/nfc_reading_screen.dart';
import 'package:vcmrtdapp/widgets/pages/scanner_wrapper.dart';

import 'document_selection_screen.dart';
import 'driving_licence_data_screen.dart';
import 'driving_licence_screen.dart';
import 'nfc_guidance_screen.dart';
import 'manual_entry_screen.dart';
import '../../models/mrtd_data.dart';
import 'package:vcmrtd/vcmrtd.dart';

enum NavigationStep {
  documentType,
  passportMrz,
  edlMrz,
  manual,
  nfcHelp,
  nfcReading,
  results,
}

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
  DataResult? _documentDataResult;
  DocumentType? _currentDocumentType;
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
          _currentDocumentType = DocumentType.passport;
        });
      },
      onDrivingLicenceSelected: () {
        setState(() {
          _resetPassportFlow();
          _currentStep = NavigationStep.edlMrz;
          _currentDocumentType = DocumentType.driverLicence;
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
          _currentDocumentType = DocumentType.passport;
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
      documentType: _currentDocumentType ?? DocumentType.passport,
      onContinue: () {
        setState(() {
          _currentStep = NavigationStep.nfcHelp;
        });
      },
      onBack: () {
        setState(() {
          _currentStep = _currentDocumentType == DocumentType.driverLicence
              ? NavigationStep.edlMrz
              : NavigationStep.passportMrz;
        });
      },
      // Passport callback
      onDataEntered: (String docNumber, DateTime dob, DateTime expiry) {
        setState(() {
          _manualDocNumber = docNumber;
          _manualDob = dob;
          _manualExpiry = expiry;
        });
      },
      // Driver's license callback
      onMrzEntered: (String mrzString) {
        try {
          final result = DriverLicenseParser.parse([mrzString]);
          setState(() {
            _mrzResult = result;
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid MRZ format: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
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
          _currentStep =
              NavigationStep.passportMrz; // Back to scanner/manual entry
        });
      },
      onTroubleshooting: () {
        _showTroubleshootingDialog();
      },
    );
  }

  Widget _buildDataReadingScreen() {
    if (_currentDocumentType == DocumentType.passport) {
      return PassportDataScreen(
        mrtdData: _mrtdData!,
        passportDataResult: _documentDataResult!,
        sessionId: _sessionId,
        nonce: _nonce,
        onBackPressed: () {
          Navigator.of(context).pop();
          setState(() {
            _resetPassportFlow(clearSession: true);
            _currentDocumentType = DocumentType.passport;
            _currentStep =
                NavigationStep.documentType; // Back to doc type selection
          });
        },
      );
    } else {
      return DrivingLicenceDataScreen(
        mrtdData: _mrtdData!,
        onBackPressed: () {
          Navigator.of(context).pop();
          setState(() {
            _currentDocumentType = DocumentType.driverLicence;
            _currentStep = NavigationStep.documentType;
          });
        },
      );
    }
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
      onDataRead: (MrtdData data, DataResult passportDataResult) {
        setState(() {
          _mrtdData = data;
          _documentDataResult = passportDataResult;
          _currentStep = NavigationStep.results; // Show results
        });
      },
      documentType: _currentDocumentType ?? DocumentType.passport,
    );
  }

  Widget _buildDrivingLicenceScannerScreen() {
    return ScannerWrapper(
      documentType: DocumentType.driverLicence,
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
          _currentDocumentType = DocumentType.driverLicence;
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
              Text(
                  '• Ensure the passport has an electronic chip (newer passports)'),
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

  void _resetPassportFlow({bool clearSession = false}) {
    _mrzResult = null;
    _mrtdData = null;
    _documentDataResult = null;
    _manualDocNumber = null;
    _manualDob = null;
    _manualExpiry = null;

    if (clearSession) {
      _nonce = null;
      _sessionId = null;
    }
  }
}
