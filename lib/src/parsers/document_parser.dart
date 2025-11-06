import 'dart:typed_data';
import '../models/document.dart';

abstract class DocumentParser<DocType extends DocumentData> {
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

  void parseDG15(Uint8List bytes) {
    throw UnimplementedError('DG15 parsing not implemented for this document type');
  }

  void parseDG16(Uint8List bytes) {
    throw UnimplementedError('DG16 parsing not implemented for this document type');
  }

  DocType createDocument();
}
