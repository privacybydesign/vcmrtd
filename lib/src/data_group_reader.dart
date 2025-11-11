import 'dart:typed_data';
import 'package:logging/logging.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/internal.dart';
import 'package:vcmrtd/vcmrtd.dart';

enum _DF { None, MF, DF1 }

class DataGroupReader {
  static const int DG1_SFI = 0x01;
  static const int DG2_SFI = 0x02;
  static const int DG3_SFI = 0x03;
  static const int DG4_SFI = 0x04;
  static const int DG5_SFI = 0x05;
  static const int DG6_SFI = 0x06;
  static const int DG7_SFI = 0x07;
  static const int DG8_SFI = 0x08;
  static const int DG9_SFI = 0x09;
  static const int DG10_SFI = 0x0A;
  static const int DG11_SFI = 0x0B;
  static const int DG12_SFI = 0x0C;
  static const int DG13_SFI = 0x0D;
  static const int DG14_SFI = 0x0E;
  static const int DG15_SFI = 0x0F;
  static const int DG16_SFI = 0x10;

  final MrtdApi _api;
  final Logger _log;
  final Uint8List _applicationAID;
  final AccessKey accessKey;
  _DF _dfSelected = _DF.None;
  final bool enableBac;
  final bool enablePace;

  DataGroupReader(
    ComProvider provider,
    this._applicationAID,
    this.accessKey, {
    this.enableBac = true,
    this.enablePace = true,
  }) : _api = MrtdApi(provider),
       _log = Logger("Data Group bytes reader");

  Future<void> startSession() async {
    if (!enableBac) {
      throw Exception('try BAC while BAC was not enabled');
    }
    if (accessKey is DBAKey) {
      await _selectDF1();
      await _exec(() => _api.initSessionViaBAC(accessKey as DBAKey));
    }
  }

  Future<void> startSessionPACE(EfCardAccess efCardAccess) async {
    if (!enablePace) {
      throw Exception('try BAC while BAC was not enabled');
    }
    await _selectMF();
    await _exec(() => _api.initSessionViaPACE(accessKey, efCardAccess));
  }

  Future<Uint8List> readDG1() async {
    await _selectDF1();
    _log.debug("Reading EF.DG1");
    return await _exec(() => _api.readFileBySFI(DG1_SFI));
  }

  Future<Uint8List> readDG2() async {
    await _selectDF1();
    _log.debug("Reading EF.DG2");
    return await _exec(() => _api.readFileBySFI(DG2_SFI));
  }

  Future<Uint8List> readDG3() async {
    await _selectDF1();
    _log.debug("Reading EF.DG3");
    return await _exec(() => _api.readFileBySFI(DG3_SFI));
  }

  Future<Uint8List> readDG4() async {
    await _selectDF1();
    _log.debug("Reading EF.DG4");
    return await _exec(() => _api.readFileBySFI(DG4_SFI));
  }

  Future<Uint8List> readDG5() async {
    await _selectDF1();
    _log.debug("Reading EF.DG5");
    return await _exec(() => _api.readFileBySFI(DG5_SFI));
  }

  Future<Uint8List> readDG6() async {
    await _selectDF1();
    _log.debug("Reading EF.DG6");
    return await _exec(() => _api.readFileBySFI(DG6_SFI));
  }

  Future<Uint8List> readDG7() async {
    await _selectDF1();
    _log.debug("Reading EF.DG7");
    return await _exec(() => _api.readFileBySFI(DG7_SFI));
  }

  Future<Uint8List> readDG8() async {
    await _selectDF1();
    _log.debug("Reading EF.DG8");
    return await _exec(() => _api.readFileBySFI(DG8_SFI));
  }

  Future<Uint8List> readDG9() async {
    await _selectDF1();
    _log.debug("Reading EF.DG9");
    return await _exec(() => _api.readFileBySFI(DG9_SFI));
  }

  Future<Uint8List> readDG10() async {
    await _selectDF1();
    _log.debug("Reading EF.DG10");
    return await _exec(() => _api.readFileBySFI(DG10_SFI));
  }

  Future<Uint8List> readDG11() async {
    await _selectDF1();
    _log.debug("Reading EF.DG11");
    return await _exec(() => _api.readFileBySFI(DG11_SFI));
  }

  Future<Uint8List> readDG12() async {
    await _selectDF1();
    _log.debug("Reading EF.DG12");
    return await _exec(() => _api.readFileBySFI(DG12_SFI));
  }

  Future<Uint8List> readDG13() async {
    await _selectDF1();
    _log.debug("Reading EF.DG13");
    return await _exec(() => _api.readFileBySFI(DG13_SFI));
  }

  Future<Uint8List> readDG14() async {
    await _selectDF1();
    _log.debug("Reading EF.DG14");
    return await _exec(() => _api.readFileBySFI(DG14_SFI));
  }

  Future<Uint8List> readDG15() async {
    await _selectDF1();
    _log.debug("Reading EF.DG15");
    return await _exec(() => _api.readFileBySFI(DG15_SFI));
  }

  Future<Uint8List> readDG16() async {
    await _selectDF1();
    _log.debug("Reading EF.DG16");
    return await _exec(() => _api.readFileBySFI(DG16_SFI));
  }

  Future<Uint8List> readEfCOM() async {
    await _selectDF1();
    _log.debug("Reading EF.COM");
    return await _exec(() => _api.readFileBySFI(EfCOM.SFI));
  }

  Future<Uint8List> readEfSOD() async {
    await _selectDF1();
    _log.debug("Reading EF.SOD");
    return await _exec(() => _api.readFileBySFI(EfSOD.SFI));
  }

  Future<Uint8List> readEfCardAccess() async {
    await _selectMF();
    _log.debug("Reading EF.CardAccess");
    return await _exec(() => _api.readFileBySFI(EfCardAccess.SFI));
  }

  Future<Uint8List> activeAuthenticate(Uint8List challenge) async {
    return await _exec(() => _api.activeAuthenticate(challenge));
  }

  Future<void> _selectDF1() async {
    if (_dfSelected != _DF.DF1) {
      _log.debug("Selecting DF1");
      await _exec(() => _api.selectEMrtdApplication(_applicationAID));
      _dfSelected = _DF.DF1;
    }
  }

  Future<void> _selectMF() async {
    if (_dfSelected != _DF.MF) {
      _log.debug("Selecting MF");
      await _exec(() => _api.selectMasterFile());
      _dfSelected = _DF.MF;
    }
  }

  Future<T> _exec<T>(Function f) async {
    try {
      return await f();
    } on ICCError catch (e) {
      var msg = e.sw.description();
      if (e.sw.sw1 == 0x63 && e.sw.sw2 == 0xcf) {
        msg = StatusWord.securityStatusNotSatisfied.description();
      }
      throw DocumentError(msg, code: e.sw);
    } on MrtdApiError catch (e) {
      throw DocumentError(e.message, code: e.code);
    }
  }
}
