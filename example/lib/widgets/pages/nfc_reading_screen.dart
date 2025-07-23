import 'dart:typed_data';

import 'package:dmrtd/dmrtd.dart';
import 'package:dmrtd/extensions.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:mrtdeg/helpers/mrz_data.dart';
import 'package:mrtdeg/models/mrtd_data.dart';
import 'package:mrtdeg/widgets/common/alert_message_widget.dart';

class NfcReadingScreen extends StatefulWidget {
  final MRZResult? mrzResult;
  final String? manualDocNumber;
  final DateTime? manualDob;
  final DateTime? manualExpiry;
  final ValueChanged<MrtdData>? onDataRead;

  const NfcReadingScreen({
    Key? key, 
    this.mrzResult, 
    this.manualDocNumber,
    this.manualDob,
    this.manualExpiry,
    this.onDataRead
  }) : super(key: key);

  @override
  State<NfcReadingScreen> createState() => _NfcReadingScreenState();
}

class _NfcReadingScreenState extends State<NfcReadingScreen> {
  final NfcProvider _nfc = NfcProvider();
  String _alertMessage = "";
  final _log = Logger("mrtdeg.app");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NFC Reading'),
      ),
      body: Center(
        child: AlertMessageWidget(message: _alertMessage),
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
        _alertMessage = "Waiting for Passport tag ...";
      });

      try {
        bool demo = false;
        if (!demo) {
          await _nfc.connect(
            iosAlertMessage: "Hold your phone near Biometric Passport",
          );
        }

        final passport = Passport(_nfc);
        setState(() {
          _alertMessage = "Reading Passport ...";
        });

        await _performPassportReading(passport, accessKey, isPace);
      } on Exception catch (e) {
        _handlePassportError(e);
      } finally {
        await _cleanupNfcConnection();
      }
    } on Exception catch (e) {
      _log.error("Read MRTD error: $e");
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

    _nfc.setIosAlertMessage("Initiating session with PACE...");
    mrtdData.isPACE = isPace;
    mrtdData.isDBA = accessKey.PACE_REF_KEY_TAG == 0x01;

    setState(() {
      _alertMessage = "Authenticating with Passport ...";
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
      _alertMessage = "Reading Passport Data ...";
    });

    _nfc.setIosAlertMessage("Reading EF.COM ...");
    mrtdData.com = await passport.readEfCOM();

    _nfc.setIosAlertMessage("Reading Data Groups");

    if (mrtdData.com!.dgTags.contains(EfDG1.TAG)) {
      mrtdData.dg1 = await passport.readEfDG1();
    }

    if (mrtdData.com!.dgTags.contains(EfDG2.TAG)) {
      mrtdData.dg2 = await passport.readEfDG2();
    }

    // To read DG3 and DG4 session has to be established with CVCA certificate (not supported).
    if (mrtdData.com!.dgTags.contains(EfDG5.TAG)) {
      mrtdData.dg5 = await passport.readEfDG5();
    }

    if (mrtdData.com!.dgTags.contains(EfDG6.TAG)) {
      mrtdData.dg6 = await passport.readEfDG6();
    }

    if (mrtdData.com!.dgTags.contains(EfDG7.TAG)) {
      mrtdData.dg7 = await passport.readEfDG7();
    }

    if (mrtdData.com!.dgTags.contains(EfDG8.TAG)) {
      mrtdData.dg8 = await passport.readEfDG8();
    }

    if (mrtdData.com!.dgTags.contains(EfDG9.TAG)) {
      mrtdData.dg9 = await passport.readEfDG9();
    }

    if (mrtdData.com!.dgTags.contains(EfDG10.TAG)) {
      mrtdData.dg10 = await passport.readEfDG10();
    }

    if (mrtdData.com!.dgTags.contains(EfDG11.TAG)) {
      mrtdData.dg11 = await passport.readEfDG11();
    }

    if (mrtdData.com!.dgTags.contains(EfDG12.TAG)) {
      mrtdData.dg12 = await passport.readEfDG12();
    }

    if (mrtdData.com!.dgTags.contains(EfDG13.TAG)) {
      mrtdData.dg13 = await passport.readEfDG13();
    }

    if (mrtdData.com!.dgTags.contains(EfDG14.TAG)) {
      mrtdData.dg14 = await passport.readEfDG14();
    }

    // Read DG15 and perform Active Authentication
    if (mrtdData.com!.dgTags.contains(EfDG15.TAG)) {
      setState(() {
        _alertMessage = "Performing Active Authentication ...";
      });
      mrtdData.dg15 = await passport.readEfDG15();
      _nfc.setIosAlertMessage("Doing AA ...");
      mrtdData.aaSig = await passport.activeAuthenticate(Uint8List(8));
    }

    if (mrtdData.com!.dgTags.contains(EfDG16.TAG)) {
      mrtdData.dg16 = await passport.readEfDG16();
    }

    _nfc.setIosAlertMessage("Reading EF.SOD ...");
    mrtdData.sod = await passport.readEfSOD();
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
}
