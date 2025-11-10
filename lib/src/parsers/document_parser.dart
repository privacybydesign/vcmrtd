import 'dart:typed_data';
import 'package:vcmrtd/vcmrtd.dart';

abstract class DocumentParser<DocType extends DocumentData> {
  EfCardAccess? _cardAccess;
  EfSOD? _sod;
  EfCOM? _com;

  EfCardAccess get cardAccess => _cardAccess!;
  EfSOD get sod => _sod!;
  EfCOM get com => _com!;

  void parseEfCardAccess(Uint8List bytes) {
    _cardAccess = EfCardAccess.fromBytes(bytes);
  }

  void parseEfSOD(Uint8List bytes) {
    _sod = EfSOD.fromBytes(bytes);
  }

  void parseEfCOM(Uint8List bytes) {
    _com = EfCOM.fromBytes(bytes);
  }

  bool documentContainsDataGroup(DataGroups dg);

  void parseDG1(Uint8List bytes);
  void parseDG2(Uint8List bytes);
  void parseDG3(Uint8List bytes);
  void parseDG4(Uint8List bytes);
  void parseDG5(Uint8List bytes);
  void parseDG6(Uint8List bytes);
  void parseDG7(Uint8List bytes);
  void parseDG8(Uint8List bytes);
  void parseDG9(Uint8List bytes);
  void parseDG10(Uint8List bytes);
  void parseDG11(Uint8List bytes);
  void parseDG12(Uint8List bytes);
  void parseDG13(Uint8List bytes);
  void parseDG14(Uint8List bytes);
  void parseDG15(Uint8List bytes);
  void parseDG16(Uint8List bytes);

  DocType createDocument();
}
