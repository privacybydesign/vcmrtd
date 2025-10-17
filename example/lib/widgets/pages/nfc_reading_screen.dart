import 'dart:typed_data';

import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:vcmrtdapp/helpers/document_type_extract.dart';
import 'package:vcmrtdapp/helpers/mrz_data.dart';
import 'package:vcmrtdapp/models/data_group_config.dart';
import 'package:vcmrtdapp/models/mrtd_data.dart';
import 'package:vcmrtdapp/models/passport_result.dart';
import 'package:vcmrtdapp/widgets/common/animated_nfc_status_widget.dart';

class NfcReadingScreen extends StatefulWidget {
  final MRZResult? mrzResult;
  final String? manualDocNumber;
  final DateTime? manualDob;
  final DateTime? manualExpiry;
  final DocumentType documentType;
  final Document? document;
  final String? sessionId;
  final Uint8List? nonce;
  final Function(MrtdData, DataResult)? onDataRead;
  final VoidCallback? onCancel;

  const NfcReadingScreen(
      {Key? key,
      this.mrzResult,
      this.manualDocNumber,
      this.manualDob,
      this.manualExpiry,
      required this.documentType,
      this.document,
      this.sessionId,
      this.nonce,
      this.onDataRead,
      this.onCancel})
      : super(key: key);

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
    } else {
      setState(() {
        _alertMessage =
            "No ${widget.documentType.displayName} data available. Please go back and enter your passport information.";
        _nfcState = NFCReadingState.error;
      });
      return;
    }

    final bacKeySeed = DBAKey(
      docNumber,
      birthDate,
      expiryDate,
      paceMode: paceMode,
    );
    _readMRTD(accessKey: bacKeySeed, isPace: paceMode);
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
          await _nfc.connect(
            iosAlertMessage: "Hold your phone near Biometric ${widget.documentType.displayName}",
          );
        }

        if (_isCancelled) return;
        final Document document = widget.documentType == DocumentType.passport
            ? Passport(_nfc)
            : DrivingLicence(_nfc);
        setState(() {
          _alertMessage = "Connecting to ${widget.documentType.displayNameLowerCase}...";
          _nfcState = NFCReadingState.connecting;
        });

        if (_isCancelled) return;
        await _performDocumentReading(document, accessKey, isPace);
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

  Future<void> _performDocumentReading(
    Document document,
    AccessKey accessKey,
    bool isPace,
  ) async {
    _nfc.setIosAlertMessage("Trying to read EF.CardAccess ...");
    final mrtdData = MrtdData();

    try {
      mrtdData.cardAccess = await document.readEfCardAccess();
    } on DocumentError {
      // Handle card access read error
    }

    _nfc.setIosAlertMessage("Trying to read EF.CardSecurity ...");
    try {
      mrtdData.cardSecurity = await document.readEfCardSecurity();
    } on DocumentError {
      // Handle card security read error
    }

    _nfc.setIosAlertMessage("Initiating session with PACE...");
    mrtdData.isPACE = isPace;
    mrtdData.isDBA = accessKey.PACE_REF_KEY_TAG == 0x01;

    setState(() {
      _alertMessage = "Authenticating with ${widget.documentType.displayNameLowerCase}...";
      _nfcState = NFCReadingState.authenticating;
    });

    if (isPace) {
      await document.startSessionPACE(accessKey, mrtdData.cardAccess!);
    } else {
      await document.startSession(accessKey as DBAKey);
    }

    final dataResult = await _readDataGroups(document, mrtdData);
    widget.onDataRead?.call(mrtdData, dataResult);
  }

  Future<DataResult> _readDataGroups(
      Document document, MrtdData mrtdData) async {
    setState(() {
      _alertMessage = "Reading ${widget.documentType.displayNameLowerCase} data...";
      _nfcState = NFCReadingState.reading;
      _readingProgress = 0.1;
    });

    try {
      final reader = DocumentReader.from(document);
      // Read EF.COM first
      _nfc.setIosAlertMessage("Reading EF.COM ...");
      mrtdData.com = await reader.readEfCOM();

      // Configure data groups with their read functions and progress increments
      final dataGroupConfigs = [
        DataGroupConfig(
          tag: EfDG1.TAG,
          name: "DG1",
          progressIncrement: 0.1,
          readFunction: (r) async {
            final dg = await r.readEfDG1();
            mrtdData.dg1 = dg;
            return dg;
          },
        ),
        DataGroupConfig(
          tag: EfDG2.TAG,
          name: "DG2",
          progressIncrement: 0.1,
          readFunction: (r) async {
            final dg = await r.readEfDG2();
            mrtdData.dg2 = dg;
            return dg;
          },
        ),
        DataGroupConfig(
          tag: EfDG5.TAG,
          name: "DG5",
          progressIncrement: 0.1,
          readFunction: (r) async {
            final dg = await r.readEfDG5();
            mrtdData.dg5 = dg;
            return dg;
          },
        ),
        DataGroupConfig(
          tag: EfDG6.TAG,
          name: "DG6",
          progressIncrement: 0.05,
          readFunction: (r) async {
            final dg = await r.readEfDG6();
            mrtdData.dg6 = dg;
            return dg;
          },
        ),
        DataGroupConfig(
          tag: EfDG7.TAG,
          name: "DG7",
          progressIncrement: 0.05,
          readFunction: (r) async {
            final dg = await r.readEfDG7();
            mrtdData.dg7 = dg;
            return dg;
          },
        ),
        DataGroupConfig(
          tag: EfDG8.TAG,
          name: "DG8",
          progressIncrement: 0.05,
          readFunction: (r) async {
            final dg = await r.readEfDG8();
            mrtdData.dg8 = dg;
            return dg;
          },
        ),
        DataGroupConfig(
          tag: EfDG9.TAG,
          name: "DG9",
          progressIncrement: 0.05,
          readFunction: (r) async {
            final dg = await r.readEfDG9();
            mrtdData.dg9 = dg;
            return dg;
          },
        ),
        DataGroupConfig(
          tag: EfDG10.TAG,
          name: "DG10",
          progressIncrement: 0.05,
          readFunction: (r) async {
            final dg = await r.readEfDG10();
            mrtdData.dg10 = dg;
            return dg;
          },
        ),
        DataGroupConfig(
          tag: EfDG11.TAG,
          name: "DG11",
          progressIncrement: 0.05,
          readFunction: (r) async {
            final dg = await r.readEfDG11();
            mrtdData.dg11 = dg;
            return dg;
          },
        ),
        DataGroupConfig(
          tag: EfDG12.TAG,
          name: "DG12",
          progressIncrement: 0.05,
          readFunction: (r) async {
            final dg = await r.readEfDG12();
            mrtdData.dg12 = dg;
            return dg;
          },
        ),
        DataGroupConfig(
          tag: EfDG13.TAG,
          name: "DG13",
          progressIncrement: 0.05,
          readFunction: (r) async {
            final dg = await r.readEfDG13();
            mrtdData.dg13 = dg;
            return dg;
          },
        ),
        DataGroupConfig(
          tag: EfDG14.TAG,
          name: "DG14",
          progressIncrement: 0.05,
          readFunction: (r) async {
            final dg = await r.readEfDG14();
            mrtdData.dg14 = dg;
            return dg;
          },
        ),
        DataGroupConfig(
          tag: EfDG16.TAG,
          name: "DG16",
          progressIncrement: 0.05,
          readFunction: (r) async {
            final dg = await r.readEfDG16();
            mrtdData.dg16 = dg;
            return dg;
          },
        ),
      ];

      _nfc.setIosAlertMessage("Reading Data Groups");

      final Map<String, String> dataGroups = {};
      double currentProgress = 0.2;

      // Process each data group
      for (final config in dataGroupConfigs) {
        if (mrtdData.com!.dgTags.contains(config.tag)) {
          try {
            final dgData = await config.readFunction(reader);

            // Convert data group to hex string
            final hexData = dgData.toBytes().hex();
            if (hexData.isNotEmpty) {
              dataGroups[config.name] = hexData;
            }
          } catch (e) {
            _log.warning("Failed to read ${config.name}: $e");
            // Continue with other data groups even if one fails
          }
        }

        currentProgress += config.progressIncrement;
        setState(() => _readingProgress = currentProgress.clamp(0.0, 0.9));
      }

      // Handle DG15 and Active Authentication separately
      if (widget.sessionId != null &&
          widget.nonce != null &&
          mrtdData.com!.dgTags.contains(EfDG15.TAG)) {
        setState(() {
          _alertMessage = "Performing security verification...";
          _nfcState = NFCReadingState.authenticating;
          _readingProgress = 0.9;
        });

        try {
          mrtdData.dg15 = await reader.readEfDG15();
          if (mrtdData.dg15 != null) {
            final hexData = mrtdData.dg15!.toBytes().hex();
            if (hexData.isNotEmpty) {
              dataGroups["DG15"] = hexData;
            }
          }

          _nfc.setIosAlertMessage("Doing AA ...");
          mrtdData.aaSig = await document.activeAuthenticate(widget.nonce!);
        } catch (e) {
          _log.warning("Failed to read DG15 or perform AA: $e");
        }
      }

      // Read EF.SOD
      _nfc.setIosAlertMessage("Reading EF.SOD ...");
      mrtdData.sod = await reader.readEfSOD();

      final efSodHex = mrtdData.sod?.toBytes().hex() ?? '';
      _log.info("EF.SOD: $efSodHex");

      setState(() {
        _alertMessage = "${widget.documentType.displayName} reading completed successfully!";
        _nfcState = NFCReadingState.success;
        _readingProgress = 1.0;
      });

      return DataResult(
          dataGroups: dataGroups,
          efSod: efSodHex,
          nonce: widget.nonce,
          sessionId: widget.sessionId,
          aaSignature: mrtdData.aaSig);
    } catch (e) {
      _log.severe("Error reading ${widget.documentType.displayNameLowerCase} data: $e");
      setState(() {
        _alertMessage = "Failed to read passport data";
        _nfcState = NFCReadingState.error;
      });
      rethrow;
    }
  }

  void _handlePassportError(Exception e) {
    final se = e.toString().toLowerCase();
    String alertMsg = "An error has occurred while reading ${widget.documentType.displayNameLowerCase}!";

    if (e is DocumentError) {
      if (se.contains("security status not satisfied")) {
        alertMsg =
            "Failed to initiate session with ${widget.documentType.displayNameLowerCase}.\nCheck input data!";
      }
      _log.error("PassportError: ${e.message}");
    } else {
      _log.error(
          "An exception was encountered while trying to read Passport: $e");
    }

    if (se.contains('timeout')) {
      alertMsg = "Timeout while waiting for ${widget.documentType.displayNameLowerCase} tag";
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
