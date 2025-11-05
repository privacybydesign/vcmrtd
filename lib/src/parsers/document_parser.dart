import 'dart:typed_data';
import '../models/document.dart';

abstract class DocumentParser<DocType extends DocumentData> {
  void parseDG1(Uint8List bytes) {
    throw UnimplementedError('DG1 parsing not implemented for this document type');
  }

  void parseDG2(Uint8List bytes) {
    throw UnimplementedError('DG2 parsing not implemented for this document type');
  }

  void parseDG3(Uint8List bytes) {
    throw UnimplementedError('DG3 parsing not implemented for this document type');
  }

  void parseDG4(Uint8List bytes) {
    throw UnimplementedError('DG4 parsing not implemented for this document type');
  }

  void parseDG5(Uint8List bytes) {
    throw UnimplementedError('DG5 parsing not implemented for this document type');
  }

  void parseDG6(Uint8List bytes) {
    throw UnimplementedError('DG6 parsing not implemented for this document type');
  }

  void parseDG7(Uint8List bytes) {
    throw UnimplementedError('DG7 parsing not implemented for this document type');
  }

  void parseDG8(Uint8List bytes) {
    throw UnimplementedError('DG8 parsing not implemented for this document type');
  }

  void parseDG9(Uint8List bytes) {
    throw UnimplementedError('DG9 parsing not implemented for this document type');
  }

  void parseDG10(Uint8List bytes) {
    throw UnimplementedError('DG10 parsing not implemented for this document type');
  }

  void parseDG11(Uint8List bytes) {
    throw UnimplementedError('DG11 parsing not implemented for this document type');
  }

  void parseDG12(Uint8List bytes) {
    throw UnimplementedError('DG12 parsing not implemented for this document type');
  }

  void parseDG13(Uint8List bytes) {
    throw UnimplementedError('DG13 parsing not implemented for this document type');
  }

  void parseDG14(Uint8List bytes) {
    throw UnimplementedError('DG14 parsing not implemented for this document type');
  }

  void parseDG15(Uint8List bytes) {
    throw UnimplementedError('DG15 parsing not implemented for this document type');
  }

  void parseDG16(Uint8List bytes) {
    throw UnimplementedError('DG16 parsing not implemented for this document type');
  }

  DocType createDocument();
}
