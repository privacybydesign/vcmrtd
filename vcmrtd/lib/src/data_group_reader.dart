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

  final ComProvider _com;
  final Logger _log;
  final Uint8List _applicationAID;
  final AccessKey? bacAccessKey;
  final AccessKey? paceAccessKey;
  _DF _dfSelected = _DF.None;
  MrtdApi _api;

  // Per-SFI partial read progress, so that if the connection drops part-way
  // through a large file (e.g. DG2's face image) a retry resumes from the
  // last byte read instead of re-reading the whole file. Deliberately not
  // cleared by reset(): reset() rebuilds the SM session (which does not
  // survive a reconnect anyway) but the file content already read is still
  // valid and worth keeping.
  final Map<int, MrtdFileReadState> _fileReadState = {};

  DataGroupReader(ComProvider provider, this._applicationAID, {this.bacAccessKey, this.paceAccessKey})
    : _com = provider,
      _api = MrtdApi(provider),
      _log = Logger("Data Group bytes reader");

  /// Reset all the api settings and start fresh
  void reset() {
    _api = MrtdApi(_com);
    _dfSelected = _DF.None;
  }

  Future<void> startSession() async {
    if (bacAccessKey == null) {
      throw Exception('trying BAC while BAC was not enabled');
    }
    await _selectDF1();
    if (bacAccessKey is DBAKey) {
      await _exec(() => _api.initSessionViaBAC(bacAccessKey as DBAKey));
    } else if (bacAccessKey is BapKey) {
      await _exec(() => _api.initSessionViaBAC(bacAccessKey as BapKey));
    }
  }

  Future<void> startSessionPACE(EfCardAccess efCardAccess) async {
    if (paceAccessKey == null) {
      throw Exception('trying PACE while PACE was not enabled');
    }
    await _selectMF();
    await _exec(() => _api.initSessionViaPACE(paceAccessKey as PaceKey, efCardAccess));
  }

  Future<Uint8List> readDG1() async {
    await _selectDF1();
    _log.debug("Reading EF.DG1");
    return await _readFileBySFI(DG1_SFI);
  }

  Future<Uint8List> readDG2() async {
    await _selectDF1();
    _log.debug("Reading EF.DG2");
    return await _readFileBySFI(DG2_SFI);
  }

  Future<Uint8List> readDG3() async {
    await _selectDF1();
    _log.debug("Reading EF.DG3");
    return await _readFileBySFI(DG3_SFI);
  }

  Future<Uint8List> readDG4() async {
    await _selectDF1();
    _log.debug("Reading EF.DG4");
    return await _readFileBySFI(DG4_SFI);
  }

  Future<Uint8List> readDG5() async {
    await _selectDF1();
    _log.debug("Reading EF.DG5");
    return await _readFileBySFI(DG5_SFI);
  }

  Future<Uint8List> readDG6() async {
    await _selectDF1();
    _log.debug("Reading EF.DG6");
    return await _readFileBySFI(DG6_SFI);
  }

  Future<Uint8List> readDG7() async {
    await _selectDF1();
    _log.debug("Reading EF.DG7");
    return await _readFileBySFI(DG7_SFI);
  }

  Future<Uint8List> readDG8() async {
    await _selectDF1();
    _log.debug("Reading EF.DG8");
    return await _readFileBySFI(DG8_SFI);
  }

  Future<Uint8List> readDG9() async {
    await _selectDF1();
    _log.debug("Reading EF.DG9");
    return await _readFileBySFI(DG9_SFI);
  }

  Future<Uint8List> readDG10() async {
    await _selectDF1();
    _log.debug("Reading EF.DG10");
    return await _readFileBySFI(DG10_SFI);
  }

  Future<Uint8List> readDG11() async {
    await _selectDF1();
    _log.debug("Reading EF.DG11");
    return await _readFileBySFI(DG11_SFI);
  }

  Future<Uint8List> readDG12() async {
    await _selectDF1();
    _log.debug("Reading EF.DG12");
    return await _readFileBySFI(DG12_SFI);
  }

  Future<Uint8List> readDG13() async {
    await _selectDF1();
    _log.debug("Reading EF.DG13");
    return await _readFileBySFI(DG13_SFI);
  }

  Future<Uint8List> readDG14() async {
    await _selectDF1();
    _log.debug("Reading EF.DG14");
    return await _readFileBySFI(DG14_SFI);
  }

  Future<Uint8List> readDG15() async {
    await _selectDF1();
    _log.debug("Reading EF.DG15");
    return await _readFileBySFI(DG15_SFI);
  }

  Future<Uint8List> readDG16() async {
    await _selectDF1();
    _log.debug("Reading EF.DG16");
    return await _readFileBySFI(DG16_SFI);
  }

  Future<Uint8List> readEfCOM() async {
    await _selectDF1();
    _log.debug("Reading EF.COM");
    return await _readFileBySFI(EfCOM.SFI);
  }

  Future<Uint8List> readEfSOD() async {
    await _selectDF1();
    _log.debug("Reading EF.SOD");
    return await _readFileBySFI(EfSOD.SFI);
  }

  Future<Uint8List> readEfCardAccess() async {
    await _selectMF();
    _log.debug("Reading EF.CardAccess");
    return await _readFileBySFI(EfCardAccess.SFI);
  }

  /// Reads the file identified by [sfi], resuming from any progress left over
  /// by a previous, interrupted attempt. Only clears the cached progress once
  /// the file has been read in full, so a further failure keeps resuming
  /// rather than starting over.
  Future<Uint8List> _readFileBySFI(int sfi) async {
    final readState = _fileReadState.putIfAbsent(sfi, () => MrtdFileReadState());
    final bytes = await _exec(() => _api.readFileBySFI(sfi, state: readState));
    _fileReadState.remove(sfi);
    return bytes;
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
