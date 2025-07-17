// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// MRTD home page widget extracted from main.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:dmrtd/dmrtd.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:intl/intl.dart';
import 'package:dmrtd/src/proto/can_key.dart';
import 'package:dmrtd/extensions.dart';
import 'package:logging/logging.dart';
import 'package:mrtdeg/helpers/mrz_data.dart';
import 'package:mrtdeg/view/scan_page.dart';

import '../../models/mrtd_data.dart';
import '../../utils/formatters.dart';
import '../common/alert_message_widget.dart';
import '../common/nfc_status_widget.dart';
import '../displays/mrtd_data_list_widget.dart';
import '../forms/auth_form_widget.dart';

/// Main page widget for MRTD application
class MrtdHomePage extends StatefulWidget {
  @override
  State<MrtdHomePage> createState() => _MrtdHomePageState();
}

class _MrtdHomePageState extends State<MrtdHomePage>
    with TickerProviderStateMixin {
  var _alertMessage = "";
  final _log = Logger("mrtdeg.app");
  var _isNfcAvailable = false;
  var _isReading = false;

  // Form keys
  final _mrzData = GlobalKey<FormState>();
  final _canData = GlobalKey<FormState>();

  // Controllers
  final _docNumber = TextEditingController();
  final _dob = TextEditingController();
  final _doe = TextEditingController();
  final _can = TextEditingController();

  bool _checkBoxPACE = false;
  MrtdData? _mrtdData;

  final NfcProvider _nfc = NfcProvider();
  late Timer _timerStateUpdater;
  final _scrollController = ScrollController();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _initPlatformState();

    // Update platform state every 3 sec
    _timerStateUpdater = Timer.periodic(
      const Duration(seconds: 3),
      (Timer t) {
        _initPlatformState();
      },
    );
  }

  @override
  void dispose() {
    _timerStateUpdater.cancel();
    _tabController.dispose();
    _docNumber.dispose();
    _dob.dispose();
    _doe.dispose();
    _can.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initPlatformState() async {
    bool isNfcAvailable;
    try {
      NfcStatus status = await NfcProvider.nfcStatus;
      isNfcAvailable = status == NfcStatus.enabled;
    } on PlatformException {
      isNfcAvailable = false;
    }

    if (!mounted) return;

    setState(() {
      _isNfcAvailable = isNfcAvailable;
    });
  }

  DateTime? _getDOBDate() {
    if (_dob.text.isEmpty) {
      return null;
    }
    return DateFormat.yMd().parse(_dob.text);
  }

  DateTime? _getDOEDate() {
    if (_doe.text.isEmpty) {
      return null;
    }
    return DateFormat.yMd().parse(_doe.text);
  }

  void _readMRZPressed() async {
    final MRZResult? mrzResult = await showDialog(
        context: context,
        builder: (context) {
          return Material(child: ScannerPage());
        });
    if (mrzResult != null) {
      setState(() {
        _docNumber.text = mrzResult.documentNumber;
        _dob.text = DateFormat.yMd().format(mrzResult.birthDate);
        _doe.text = DateFormat.yMd().format(mrzResult.expiryDate);
      });
    }
  }

  void _buttonPressed() async {
    if (_tabController.index == 0) {
      // DBA tab
      _processDBAAuthentication();
    } else {
      // PACE tab
      _processPACEAuthentication();
    }
  }

  void _processDBAAuthentication() async {
    String errorText = "";
    if (_doe.text.isEmpty) {
      errorText += "Please enter date of expiry!\n";
    }
    if (_dob.text.isEmpty) {
      errorText += "Please enter date of birth!\n";
    }
    if (_docNumber.text.isEmpty) {
      errorText += "Please enter passport number!";
    }

    setState(() {
      _alertMessage = errorText;
    });

    if (errorText.isNotEmpty) return;

    final bacKeySeed = DBAKey(
      _docNumber.text,
      _getDOBDate()!,
      _getDOEDate()!,
      paceMode: _checkBoxPACE,
    );
    _readMRTD(accessKey: bacKeySeed, isPace: _checkBoxPACE);
  }

  void _processPACEAuthentication() async {
    String errorText = "";
    if (_can.text.isEmpty) {
      errorText = "Please enter CAN number!";
    } else if (_can.text.length != 6) {
      errorText = "CAN number must be exactly 6 digits long!";
    }

    setState(() {
      _alertMessage = errorText;
    });

    if (errorText.isNotEmpty) return;

    final canKeySeed = CanKey(_can.text);
    _readMRTD(accessKey: canKeySeed, isPace: true);
  }

  void _readMRTD({required AccessKey accessKey, bool isPace = false}) async {
    try {
      setState(() {
        _mrtdData = null;
        _alertMessage = "Waiting for Passport tag ...";
        _isReading = true;
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

    setState(() {
      _mrtdData = mrtdData;
      _alertMessage = "";
    });

    _scrollController.animateTo(
      300.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.ease,
    );
  }

  String extractImageData(String inputHex) {
    // Find the index of the first occurrence of 'FFD8'
    int startIndex = inputHex.indexOf('ffd8');
    // Find the index of the first occurrence of 'FFD9'
    int endIndex = inputHex.indexOf('ffd9');

    // If both 'FFD8' and 'FFD9' are found, extract the substring between them
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      String extractedImageData = inputHex.substring(
          startIndex, endIndex + 4); // Include 'FFD9' in the substring

      // Return the extracted image data
      return extractedImageData;
    } else {
      // 'FFD8' or 'FFD9' not found, handle accordingly (e.g., return an error or the original input)
      print("FFD8 and/or FFD9 markers not found in the input hex string.");
      return inputHex;
    }
  }


  Future<void> _readDataGroups(Passport passport, MrtdData mrtdData) async {
    setState(() {
      _alertMessage = "Reading Passport Data ...";
    });

    _nfc.setIosAlertMessage(formatProgressMsg("Reading EF.COM ...", 0));
    mrtdData.com = await passport.readEfCOM();

    _nfc.setIosAlertMessage(formatProgressMsg("Reading Data Groups ...", 20));

    if (mrtdData.com!.dgTags.contains(EfDG1.TAG)) {
      mrtdData.dg1 = await passport.readEfDG1();
    }

    if (mrtdData.com!.dgTags.contains(EfDG2.TAG)) {
      mrtdData.dg2 = await passport.readEfDG2();

      // String? imageHex = extractImageData(mrtdData.dg2!.toBytes().hex());
      // Uint8List? decodeImageHex =
      //       Uint8List.fromList(List<int>.from(hex.decode(imageHex)));
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
      _nfc.setIosAlertMessage(formatProgressMsg("Doing AA ...", 60));
      mrtdData.aaSig = await passport.activeAuthenticate(Uint8List(8));
    }

    if (mrtdData.com!.dgTags.contains(EfDG16.TAG)) {
      mrtdData.dg16 = await passport.readEfDG16();
    }

    _nfc.setIosAlertMessage(formatProgressMsg("Reading EF.SOD ...", 80));
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
        iosAlertMessage: formatProgressMsg("Finished", 100),
      );
    }
    setState(() {
      _isReading = false;
    });
  }

  bool _disabledInput() {
    return _isReading || !_isNfcAvailable;
  }

  @override
  Widget build(BuildContext context) {
    return PlatformProvider(
      builder: (BuildContext context) => _buildPage(context),
    );
  }

  PlatformScaffold _buildPage(BuildContext context) => PlatformScaffold(
        appBar: PlatformAppBar(title: const Text('MRTD Example App')),
        iosContentPadding: false,
        iosContentBottomPadding: false,
        body: Material(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    AuthFormWidget(
                      tabController: _tabController,
                      mrzFormKey: _mrzData,
                      canFormKey: _canData,
                      docNumberController: _docNumber,
                      dobController: _dob,
                      doeController: _doe,
                      canController: _can,
                      checkBoxPACE: _checkBoxPACE,
                      inputDisabled: _disabledInput(),
                      onPACEChanged: (value) {
                        setState(() {
                          _checkBoxPACE = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    PlatformElevatedButton(
                      onPressed: _buttonPressed,
                      child: PlatformText(
                        _isReading ? 'Reading ...' : 'Read Passport',
                      ),
                    ),
                    const SizedBox(height: 20),
                    PlatformElevatedButton(
                      onPressed: _readMRZPressed,
                      child: PlatformText(
                        _isReading ? 'Reading ...' : 'Scan MRZ',
                      ),
                    ),
                    const SizedBox(height: 20),
                    NfcStatusWidget(isNfcAvailable: _isNfcAvailable),
                    const SizedBox(height: 15),
                    AlertMessageWidget(message: _alertMessage),
                    const SizedBox(height: 15),
                    MrtdDataListWidget(mrtdData: _mrtdData),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
