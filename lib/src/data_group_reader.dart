import 'dart:typed_data';
import 'package:logging/logging.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/internal.dart';
import 'package:vcmrtd/vcmrtd.dart';

enum _DF { None, MF, DF1 }

class DataGroupReader {
  final MrtdApi _api;
  final Logger _log;
  final Uint8List _applicationAID;
  _DF _dfSelected = _DF.None;

  DataGroupReader(ComProvider provider, this._applicationAID)
    : _api = MrtdApi(provider),
      _log = Logger("Data Group bytes reader");



  Future<void> startSession(DBAKey keys) async {
    await _selectDF1();
    await _exec(() => _api.initSessionViaBAC(keys));
  }

  Future<void> startSessionPACE(AccessKey accessKey, EfCardAccess efCardAccess) async {
    await _exec(() => _api.initSessionViaPACE(accessKey, efCardAccess));
  }

  // Read raw data group bytes

  Future<Uint8List> readDG1() async {
    await _selectDF1();
    _log.debug("Reading EF.DG1");
    return await _exec(() => _api.readFileBySFI(0x01));
  }

  Future<Uint8List> readDG2() async {
    await _selectDF1();
    _log.debug("Reading EF.DG2");
    return await _exec(() => _api.readFileBySFI(0x02));
  }

  Future<Uint8List> readDG3() async {
    await _selectDF1();
    _log.debug("Reading EF.DG3");
    return await _exec(() => _api.readFileBySFI(0x03));
  }

  Future<Uint8List> readDG4() async {
    await _selectDF1();
    _log.debug("Reading EF.DG4");
    return await _exec(() => _api.readFileBySFI(0x04));
  }

  Future<Uint8List> readDG5() async {
    await _selectDF1();
    _log.debug("Reading EF.DG5");
    return await _exec(() => _api.readFileBySFI(0x05));
  }

  Future<Uint8List> readDG6() async {
    await _selectDF1();
    _log.debug("Reading EF.DG6");
    return await _exec(() => _api.readFileBySFI(0x06));
  }


  Future<Uint8List> readDG7() async {
    await _selectDF1();
    _log.debug("Reading EF.DG7");
    return await _exec(() => _api.readFileBySFI(0x07));
  }


  Future<Uint8List> readDG8() async {
    await _selectDF1();
    _log.debug("Reading EF.DG8");
    return await _exec(() => _api.readFileBySFI(0x08));
  }


  Future<Uint8List> readDG9() async {
    await _selectDF1();
    _log.debug("Reading EF.DG9");
    return await _exec(() => _api.readFileBySFI(0x09));
  }

  Future<Uint8List> readDG10() async {
    await _selectDF1();
    _log.debug("Reading EF.DG10");
    return await _exec(() => _api.readFileBySFI(0x0A));
  }


  Future<Uint8List> readDG11() async {
    await _selectDF1();
    _log.debug("Reading EF.DG11");
    return await _exec(() => _api.readFileBySFI(0x0B));
  }


  Future<Uint8List> readDG12() async {
    await _selectDF1();
    _log.debug("Reading EF.DG12");
    return await _exec(() => _api.readFileBySFI(0x0C));
  }


  Future<Uint8List> readDG13() async {
    await _selectDF1();
    _log.debug("Reading EF.DG13");
    return await _exec(() => _api.readFileBySFI(0x0D));
  }


  Future<Uint8List> readDG14() async {
    await _selectDF1();
    _log.debug("Reading EF.DG14");
    return await _exec(() => _api.readFileBySFI(0x0E));
  }

  Future<Uint8List> readDG15() async {
    await _selectDF1();
    _log.debug("Reading EF.DG15");
    return await _exec(() => _api.readFileBySFI(0x0F));
  }


  Future<Uint8List> readDG16() async {
    await _selectDF1();
    _log.debug("Reading EF.DG16");
    return await _exec(() => _api.readFileBySFI(0x10));
  }


  // ICC communication commands

  Future<EfCOM> readEfCOM() async {
    await _selectDF1();
    _log.debug("Reading EF.COM");
    return EfCOM.fromBytes(await _exec(() => _api.readFileBySFI(EfCOM.SFI)));
  }

  Future<EfSOD> readEfSOD() async {
    await _selectDF1();
    _log.debug("Reading EF.SOD");
    return EfSOD.fromBytes(await _exec(() => _api.readFileBySFI(EfSOD.SFI)));
  }

  Future<EfCardAccess> readEfCardAccess() async {
    await _selectMF();
    _log.debug("Reading EF.CardAccess");
    return EfCardAccess.fromBytes(await _exec(() => _api.readFileBySFI(EfCardAccess.SFI)));
  }

  Future<Uint8List> activeAuthenticate(Uint8List challenge) async {
    return await _exec(() => _api.activeAuthenticate(challenge));
  }

  // Selects document specific application on ICC
  Future<void> _selectDF1() async {
    if (_dfSelected != _DF.DF1) {
      _log.debug("Selecting DF1");
      await _exec(() => _api.selectEMrtdApplication(_applicationAID));
      _dfSelected = _DF.DF1;
    }
  }

  // Selects master file
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

  void reset() {
    _api.icc.sm = null;
  }
}
