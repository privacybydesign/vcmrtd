// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// ignore_for_file: constant_identifier_names

import 'dart:typed_data';
import 'package:vcmrtd/extensions.dart';
import 'dg.dart';
import '../../types/data.dart';
import '../ef.dart';
import '../mrz.dart';
import '../tlv.dart';
import '../../parsing/parser.dart';

class EfDG1 extends DataGroup {
  static const FID = 0x0101;
  static const SFI = 0x01;
  static const TAG = DgTag(0x61);

  final DocumentType documentType;

  MRZ? _passportMrz;

  // Driving licence-specific fields.
  String? _driverLicenceNumber;
  String? _driverLicenceCountry;
  int? _driverLicenceGeneration;

  EfDG1._internal(this.documentType, Uint8List data) : super.fromBytes(data);

  factory EfDG1.fromBytes(Uint8List data,
      [DocumentType docType = DocumentType.passport]) {
    return EfDG1._internal(docType, data);
  }

  MRZ get passportMrz {
    if (_passportMrz == null) {
      throw StateError(
          'Passport MRZ not available for $documentType documents');
    }
    return _passportMrz!;
  }

  String? get driverLicenceNumber => _driverLicenceNumber;
  String? get driverLicenceCountry => _driverLicenceCountry;
  int? get driverLicenceGeneration => _driverLicenceGeneration;

  bool get hasPassportMrz => _passportMrz != null;

  @override
  void parseContent(final Uint8List content) {
    final tlv = TLV.fromBytes(content);
    if (tlv.tag != 0x5F1F) {
      throw EfParseError(
        "Invalid data object tag=${tlv.tag.hex()}, expected object with tag=5F1F",
      );
    }

    final result = Dg1Parser.parse(documentType, tlv.value);
    _passportMrz = result.passportMrz;
    _driverLicenceCountry = result.driverLicenceCountry;
    _driverLicenceGeneration = result.driverLicenceGeneration;
    _driverLicenceNumber = result.driverLicenceNumber;
  }

  @override
  int get fid => FID;

  @override
  int get sfi => SFI;

  @override
  int get tag => TAG.value;
}
