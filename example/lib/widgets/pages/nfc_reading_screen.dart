import 'dart:typed_data';

import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:vcmrtdapp/helpers/document_type_extract.dart';
import 'package:vcmrtdapp/helpers/read_data_groups.dart';
import 'package:vcmrtdapp/models/mrtd_data.dart';
import 'package:vcmrtdapp/models/document_result.dart';
import 'package:vcmrtdapp/widgets/common/animated_nfc_status_widget.dart';

class NfcReadingScreen extends StatefulWidget {
  final dynamic mrzResult;
  final String? manualDocNumber;
  final DateTime? manualDob;
  final DateTime? manualExpiry;
  final DocumentType documentType;
  final Document? document;
  final String? sessionId;
  final Uint8List? nonce;
  final Function(MrtdData, DocumentResult)? onDataRead;
  final VoidCallback? onCancel;

  const NfcReadingScreen({
    super.key,
    this.mrzResult,
    this.manualDocNumber,
    this.manualDob,
    this.manualExpiry,
    required this.documentType,
    this.document,
    this.sessionId,
    this.nonce,
    this.onDataRead,
    this.onCancel,
  });

  @override
  State<NfcReadingScreen> createState() => _NfcReadingScreenState();
}

class _NfcReadingScreenState extends State<NfcReadingScreen> {
  final NfcProvider _nfc = NfcProvider();
  String _alertMessage = "";
  NFCReadingState _nfcState = NFCReadingState.idle;
  double _readingProgress = 0.0;
  final _log = Logger("vcmrtd.app");
  bool _isCancelled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AnimatedNFCStatusWidget(
          state: _nfcState,
          message: _alertMessage,
          progress: _readingProgress,
          onRetry: _nfcState == NFCReadingState.error ? _retryNfcReading : null,
          onCancel: _canShowCancel() ? _handleCancellation : null,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _processDBAAuthentication();
  }

  void _processDBAAuthentication() async {
    String docNumber;
    // Passport fields
    DateTime birthDate;
    DateTime expiryDate;

    bool paceMode = false;

    if (widget.documentType == DocumentType.passport) {
      // Use either MRZ data or manual entry data
      if (widget.mrzResult != null) {
        docNumber = widget.mrzResult!.documentNumber;
        birthDate = widget.mrzResult!.birthDate;
        expiryDate = widget.mrzResult!.expiryDate;

        // Set PACE mode based on country code if available
        if (widget.mrzResult!.countryCode == "NLD") {
          paceMode = true;
        }
      } else if (widget.manualDocNumber != null && widget.manualDob != null && widget.manualExpiry != null) {
        docNumber = widget.manualDocNumber!;
        birthDate = widget.manualDob!;
        expiryDate = widget.manualExpiry!;
      } else {
        setState(() {
          _alertMessage =
              "No ${widget.documentType.displayName} data available. Please go back and enter your passport information.";
          _nfcState = NFCReadingState.error;
        });
        return;
      }
      // DBAKey needs to be refactored to work with driver's licence, for now we force pace with can key directly on driver's licence
      final bacKeySeed = DBAKey(docNumber, birthDate, expiryDate, paceMode: paceMode);
      _readMRTD(accessKey: bacKeySeed, isPace: paceMode);
    } else if (widget.documentType == DocumentType.driverLicense) {
      docNumber = widget.mrzResult!.documentNumber;
      final canKey = CanKey(docNumber);
      paceMode = true;
      _readMRTD(accessKey: canKey, isPace: paceMode);
    }
  }

  void _readMRTD({required AccessKey accessKey, bool isPace = false}) async {
    try {
      setState(() {
        _alertMessage = "Hold your phone near the ${widget.documentType.displayName} photo page";
        _nfcState = NFCReadingState.waiting;
      });

      try {
        bool demo = false;
        if (!demo) {
          if (_isCancelled) return;
          await _nfc.connect(iosAlertMessage: "Hold your phone near Biometric ${widget.documentType.displayName}");
        }

        if (_isCancelled) return;
        final Document document = widget.documentType == DocumentType.passport ? Passport(_nfc) : DrivingLicence(_nfc);
        setState(() {
          _alertMessage = "Connecting to ${widget.documentType.displayName.toLowerCase()}...";
          _nfcState = NFCReadingState.connecting;
        });

        if (_isCancelled) return;
        await performDocumentReading(
          document: document,
          nfcProvider: _nfc,
          accessKey: accessKey,
          isPace: isPace,
          documentType: widget.documentType,
          log: _log,
          sessionId: widget.sessionId,
          nonce: widget.nonce,
          updateStatus: ({String? message, NFCReadingState? state, double? progress}) {
            if (!mounted) {
              return;
            }
            setState(() {
              if (message != null) {
                _alertMessage = message;
              }
              if (state != null) {
                _nfcState = state;
              }
              if (progress != null) {
                _readingProgress = progress;
              }
            });
          },
          onDataRead: widget.onDataRead,
        );
      } on Exception catch (e) {
        if (!_isCancelled) {
          _handleDocumentError(e);
        }
      } finally {
        await _cleanupNfcConnection();
      }
    } on Exception catch (e) {
      if (!_isCancelled) {
        _log.error("Read MRTD error: $e");
      }
    }
  }

  void _handleDocumentError(Exception e) {
    final se = e.toString().toLowerCase();
    String alertMsg = "An error has occurred while reading ${widget.documentType.displayName.toLowerCase()}!";

    if (e is DocumentError) {
      if (se.contains("security status not satisfied")) {
        alertMsg =
            "Failed to initiate session with ${widget.documentType.displayName.toLowerCase()}.\nCheck input data!";
      }
      _log.error("PassportError: ${e.message}");
    } else {
      _log.error(
        "An exception was encountered while trying to read ${widget.documentType.displayName.toLowerCase()}: $e",
      );
    }

    if (se.contains('timeout')) {
      alertMsg = "Timeout while waiting for ${widget.documentType.displayName.toLowerCase()} tag";
    } else if (se.contains("tag was lost")) {
      alertMsg = "Tag was lost. Please try again!";
    } else if (se.contains("invalidated by user")) {
      alertMsg = "";
    }

    setState(() {
      _alertMessage = alertMsg;
      _nfcState = NFCReadingState.error;
    });
  }

  Future<void> _cleanupNfcConnection() async {
    if (_alertMessage.isNotEmpty) {
      await _nfc.disconnect(iosErrorMessage: _alertMessage);
    } else {
      await _nfc.disconnect(iosAlertMessage: "Finished");
    }
  }

  void _retryNfcReading() {
    setState(() {
      _alertMessage = "";
      _nfcState = NFCReadingState.idle;
      _readingProgress = 0.0;
      _isCancelled = false;
    });
    _processDBAAuthentication();
  }

  bool _canShowCancel() {
    return _nfcState == NFCReadingState.waiting ||
        _nfcState == NFCReadingState.connecting ||
        _nfcState == NFCReadingState.reading;
  }

  void _handleCancellation() async {
    setState(() {
      _isCancelled = true;
      _nfcState = NFCReadingState.cancelling;
      _alertMessage = "Cancelling...";
    });

    try {
      // Cleanup NFC connection
      await _cleanupNfcConnection();

      // Call the cancel callback to navigate back
      widget.onCancel?.call();
    } catch (e) {
      _log.error("Error during cancellation: $e");
      // Even if cleanup fails, still navigate back
      widget.onCancel?.call();
    }
  }
}
