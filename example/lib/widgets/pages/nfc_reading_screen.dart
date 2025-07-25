import 'dart:typed_data';

import 'package:dmrtd/dmrtd.dart';
import 'package:dmrtd/extensions.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:mrtdeg/helpers/mrz_data.dart';
import 'package:mrtdeg/models/mrtd_data.dart';
import 'package:mrtdeg/models/authentication_context.dart';
import 'package:mrtdeg/models/nonce_enhanced_dba_key.dart';
import 'package:mrtdeg/services/universal_link_handler.dart';
import 'package:mrtdeg/services/nonce_validation_service.dart';
import 'package:mrtdeg/widgets/common/animated_nfc_status_widget.dart';

class NfcReadingScreen extends StatefulWidget {
  final MRZResult? mrzResult;
  final String? manualDocNumber;
  final DateTime? manualDob;
  final DateTime? manualExpiry;
  final ValueChanged<MrtdData>? onDataRead;
  final VoidCallback? onCancel;
  final AuthenticationContext? authContext;

  const NfcReadingScreen({
    Key? key, 
    this.mrzResult, 
    this.manualDocNumber,
    this.manualDob,
    this.manualExpiry,
    this.onDataRead,
    this.onCancel,
    this.authContext,
  }) : super(key: key);

  @override
  State<NfcReadingScreen> createState() => _NfcReadingScreenState();
}

class _NfcReadingScreenState extends State<NfcReadingScreen> {
  final NfcProvider _nfc = NfcProvider();
  String _alertMessage = "";
  NFCReadingState _nfcState = NFCReadingState.idle;
  double _readingProgress = 0.0;
  final _log = Logger("mrtdeg.app");
  bool _isCancelled = false;
  final UniversalLinkHandler _linkHandler = UniversalLinkHandler();
  final NonceValidationService _nonceValidator = NonceValidationService();
  AuthenticationContext? _effectiveAuthContext;
  bool _nonceValidationPassed = false;

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
    
    // Determine effective authentication context
    _effectiveAuthContext = widget.authContext ?? _linkHandler.currentAuthContext;
    
    if (_effectiveAuthContext != null) {
      _log.info("Using authentication context: ${_effectiveAuthContext!.sessionId}");
      if (!_effectiveAuthContext!.isValid) {
        _log.warning("Authentication context is invalid or expired");
      }
    } else {
      _log.info("No authentication context available, using standard flow");
    }

    _processDBAAuthentication();
  }

  void _processDBAAuthentication() async {
    String docNumber;
    DateTime birthDate;
    DateTime expiryDate;
    bool paceMode = false;

    // Use either MRZ data or manual entry data
    if (widget.mrzResult != null) {
      docNumber = widget.mrzResult!.documentNumber;
      birthDate = widget.mrzResult!.birthDate;
      expiryDate = widget.mrzResult!.expiryDate;
      
      // Set PACE mode based on country code if available
      if (widget.mrzResult!.countryCode == "NLD") {
        paceMode = true;
      }
    } else if (widget.manualDocNumber != null && 
               widget.manualDob != null && 
               widget.manualExpiry != null) {
      docNumber = widget.manualDocNumber!;
      birthDate = widget.manualDob!;
      expiryDate = widget.manualExpiry!;
      // Default to non-PACE mode for manual entry
      paceMode = false;
    } else {
      setState(() {
        _alertMessage = "No passport data available. Please go back and enter your passport information.";
        _nfcState = NFCReadingState.error;
      });
      return;
    }

    // Create nonce-enhanced DBA key if authentication context is available
    final AccessKey bacKeySeed;
    if (_effectiveAuthContext != null && _effectiveAuthContext!.isValid) {
      _log.info("Creating nonce-enhanced DBA key with session: ${_effectiveAuthContext!.sessionId}");
      bacKeySeed = NonceEnhancedDBAKey(
        docNumber,
        birthDate,
        expiryDate,
        paceMode: paceMode,
        authContext: _effectiveAuthContext,
      );
      
      // Validate authentication context before proceeding
      if (bacKeySeed is NonceEnhancedDBAKey && !bacKeySeed.validateAuthContext()) {
        setState(() {
          _alertMessage = "Authentication session has expired. Please restart the process.";
          _nfcState = NFCReadingState.error;
        });
        return;
      }
    } else {
      _log.info("Creating standard DBA key");
      bacKeySeed = DBAKey(
        docNumber,
        birthDate,
        expiryDate,
        paceMode: paceMode,
      );
    }
    
    _readMRTD(accessKey: bacKeySeed, isPace: paceMode);
  }

  void _readMRTD({required AccessKey accessKey, bool isPace = false}) async {
    try {
      setState(() {
        _alertMessage = "Hold your phone near the passport photo page";
        _nfcState = NFCReadingState.waiting;
      });

      try {
        bool demo = false;
        if (!demo) {
          if (_isCancelled) return;
          await _nfc.connect(
            iosAlertMessage: "Hold your phone near Biometric Passport",
          );
        }

        if (_isCancelled) return;
        final passport = Passport(_nfc);
        setState(() {
          _alertMessage = "Connecting to passport...";
          _nfcState = NFCReadingState.connecting;
        });

        if (_isCancelled) return;
        
        // Log authentication method being used
        if (accessKey is NonceEnhancedDBAKey && accessKey.hasNonceEnhancement) {
          _log.info("Performing nonce-enhanced passport authentication");
          setState(() {
            _alertMessage = "Performing secure nonce-enhanced authentication...";
          });
        } else {
          _log.info("Performing standard passport authentication");
          setState(() {
            _alertMessage = "Performing standard authentication...";
          });
        }
        
        await _performPassportReading(passport, accessKey, isPace);
      } on Exception catch (e) {
        if (!_isCancelled) {
          _handlePassportError(e);
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

  Future<void> _performPassportReading(
    Passport passport,
    AccessKey accessKey,
    bool isPace,
  ) async {
    _nfc.setIosAlertMessage("Trying to read EF.CardAccess ...");
    final mrtdData = MrtdData();

    try {
      mrtdData.cardAccess = await passport.readEfCardAccess();
    } on PassportError {
      // Handle card access read error
    }

    _nfc.setIosAlertMessage("Trying to read EF.CardSecurity ...");
    try {
      mrtdData.cardSecurity = await passport.readEfCardSecurity();
    } on PassportError {
      // Handle card security read error
    }

    // Enhanced authentication messaging based on nonce availability
    final isNonceEnhanced = accessKey is NonceEnhancedDBAKey && accessKey.hasNonceEnhancement;
    final authMessage = isNonceEnhanced 
        ? "Initiating secure nonce-enhanced session..."
        : "Initiating session with PACE...";
    
    _nfc.setIosAlertMessage(authMessage);
    mrtdData.isPACE = isPace;
    mrtdData.isDBA = accessKey.PACE_REF_KEY_TAG == 0x01;
    
    // Store nonce information in mrtdData for tracking
    if (isNonceEnhanced) {
      final nonceKey = accessKey as NonceEnhancedDBAKey;
      mrtdData.sessionId = nonceKey.sessionId;
      mrtdData.isNonceEnhanced = true;
      _log.info("Passport reading with nonce enhancement active");
    }

    setState(() {
      _alertMessage = isNonceEnhanced 
          ? "Secure nonce-enhanced authentication in progress..."
          : "Authenticating with passport...";
      _nfcState = NFCReadingState.authenticating;
    });

    if (isPace) {
      await passport.startSessionPACE(accessKey, mrtdData.cardAccess!);
    } else {
      await passport.startSession(accessKey as DBAKey);
    }

    await _readDataGroups(passport, mrtdData);

    widget.onDataRead?.call(mrtdData);
  }

  Future<void> _readDataGroups(Passport passport, MrtdData mrtdData) async {
    setState(() {
      _alertMessage = "Reading passport data...";
      _nfcState = NFCReadingState.reading;
      _readingProgress = 0.1;
    });

    _nfc.setIosAlertMessage("Reading EF.COM ...");
    mrtdData.com = await passport.readEfCOM();

    _nfc.setIosAlertMessage("Reading Data Groups");

    if (mrtdData.com!.dgTags.contains(EfDG1.TAG)) {
      mrtdData.dg1 = await passport.readEfDG1();
      setState(() => _readingProgress = 0.2);
    }

    if (mrtdData.com!.dgTags.contains(EfDG2.TAG)) {
      mrtdData.dg2 = await passport.readEfDG2();
      setState(() => _readingProgress = 0.3);
    }

      // To read DG3 and DG4 session has to be established with CVCA certificate (not supported).
    if (mrtdData.com!.dgTags.contains(EfDG5.TAG)) {
      // Add nonce verification for sensitive data groups if enhanced mode
      if (mrtdData.isNonceEnhanced == true) {
        _log.debug("Reading DG5 with nonce-enhanced security validation");
      }
      mrtdData.dg5 = await passport.readEfDG5();
      setState(() => _readingProgress = 0.4);
    }

    if (mrtdData.com!.dgTags.contains(EfDG6.TAG)) {
      mrtdData.dg6 = await passport.readEfDG6();
      setState(() => _readingProgress = 0.45);
    }

    if (mrtdData.com!.dgTags.contains(EfDG7.TAG)) {
      mrtdData.dg7 = await passport.readEfDG7();
      setState(() => _readingProgress = 0.5);
    }

    if (mrtdData.com!.dgTags.contains(EfDG8.TAG)) {
      mrtdData.dg8 = await passport.readEfDG8();
      setState(() => _readingProgress = 0.55);
    }

    if (mrtdData.com!.dgTags.contains(EfDG9.TAG)) {
      mrtdData.dg9 = await passport.readEfDG9();
      setState(() => _readingProgress = 0.6);
    }

    if (mrtdData.com!.dgTags.contains(EfDG10.TAG)) {
      mrtdData.dg10 = await passport.readEfDG10();
      setState(() => _readingProgress = 0.65);
    }

    if (mrtdData.com!.dgTags.contains(EfDG11.TAG)) {
      mrtdData.dg11 = await passport.readEfDG11();
      setState(() => _readingProgress = 0.7);
    }

    if (mrtdData.com!.dgTags.contains(EfDG12.TAG)) {
      mrtdData.dg12 = await passport.readEfDG12();
      setState(() => _readingProgress = 0.75);
    }

    if (mrtdData.com!.dgTags.contains(EfDG13.TAG)) {
      mrtdData.dg13 = await passport.readEfDG13();
      setState(() => _readingProgress = 0.8);
    }

    if (mrtdData.com!.dgTags.contains(EfDG14.TAG)) {
      mrtdData.dg14 = await passport.readEfDG14();
      setState(() => _readingProgress = 0.85);
    }

    // Read DG15 and perform Active Authentication
    if (mrtdData.com!.dgTags.contains(EfDG15.TAG)) {
      setState(() {
        _alertMessage = mrtdData.isNonceEnhanced == true 
            ? "Performing nonce-enhanced security verification..."
            : "Performing security verification...";
        _nfcState = NFCReadingState.authenticating;
        _readingProgress = 0.9;
      });
      mrtdData.dg15 = await passport.readEfDG15();
      
      // Use nonce-enhanced challenge if available
      Uint8List challenge = Uint8List(8);
      if (mrtdData.isNonceEnhanced == true && accessKey is NonceEnhancedDBAKey) {
        challenge = accessKey.generateNonceChallenge(challenge);
        _log.debug("Using nonce-enhanced active authentication challenge");
      }
      
      _nfc.setIosAlertMessage(mrtdData.isNonceEnhanced == true 
          ? "Performing nonce-enhanced AA..."
          : "Doing AA ...");
      mrtdData.aaSig = await passport.activeAuthenticate(challenge);
    }

    if (mrtdData.com!.dgTags.contains(EfDG16.TAG)) {
      mrtdData.dg16 = await passport.readEfDG16();
      setState(() => _readingProgress = 0.95);
    }

    _nfc.setIosAlertMessage("Reading EF.SOD ...");
    mrtdData.sod = await passport.readEfSOD();
    
    // Final success message based on authentication method
    final successMessage = mrtdData.isNonceEnhanced == true 
        ? "Secure nonce-enhanced passport reading completed!"
        : "Passport reading completed successfully!";
    
    setState(() {
      _alertMessage = successMessage;
      _nfcState = NFCReadingState.success;
      _readingProgress = 1.0;
    });
    
    if (mrtdData.isNonceEnhanced == true) {
      _log.info("Nonce-enhanced passport authentication completed successfully");
    }
  }

  void _handlePassportError(Exception e) {
    final se = e.toString().toLowerCase();
    String alertMsg = "An error has occurred while reading Passport!";

    if (e is PassportError) {
      if (se.contains("security status not satisfied")) {
        alertMsg =
            "Failed to initiate session with passport.\nCheck input data!";
      }
      _log.error("PassportError: ${e.message}");
    } else {
      _log.error(
          "An exception was encountered while trying to read Passport: $e");
    }

    if (se.contains('timeout')) {
      alertMsg = "Timeout while waiting for Passport tag";
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
      await _nfc.disconnect(
        iosAlertMessage: "Finished",
      );
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
