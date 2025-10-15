// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// ignore_for_file: constant_identifier_names

import 'dart:typed_data';
import 'package:vcmrtd/extensions.dart';
import 'dg.dart';
import '../../types/data.dart';
import '../ef.dart';
import '../mrz.dart';
import '../tlv.dart';

abstract class EfDG1 extends DataGroup {
  static const FID = 0x0101;
  static const SFI = 0x01;
  static const TAG = DgTag(0x61);
  void parseMRZ(Uint8List mrzData);

  EfDG1._internal(Uint8List data) : super.fromBytes(data);

  factory EfDG1.fromBytes(Uint8List data, DocumentType docType) {
    switch (docType) {
      case DocumentType.passport:
        return PassportDG1.fromBytes(data);
      case DocumentType.driverLicence:
        return DrivingLicenseDG1.fromBytes(data);
      default:
        throw ArgumentError('Unsupported document type: $docType');
    }
  }

  @override
  void parseContent(final Uint8List content) {
    final tlv = TLV.fromBytes(content);
    if (tlv.tag != 0x5F1F) {
      throw EfParseError(
          "Invalid data object tag=${tlv.tag.hex()}, expected object with tag=5F1F");
    }
    parseMRZ(tlv.value);
  }

  @override
  int get fid => FID;

  @override
  int get sfi => SFI;

  @override
  int get tag => TAG.value;
}

class PassportDG1 extends EfDG1 {
  late final MRZ _mrz;
  MRZ get mrz => _mrz;

  PassportDG1.fromBytes(Uint8List data) : super._internal(data);

  @override
  void parseMRZ(Uint8List mrzData) {
    _mrz = MRZ(mrzData);
  }
}

class DrivingLicenseDG1 extends EfDG1 {

  DrivingLicenseDG1.fromBytes(Uint8List data) : super._internal(data);

  late final String _licenseNumber;
  late final String _country;
  late final int _generation;


  String get licenseNumber => _licenseNumber;
  String get country => _country;
  int get generation => _generation;

  @override
  void parseMRZ(Uint8List mrzData) {
    // Parse the 30 character DL MRZ
    final mrzString = String.fromCharCodes(mrzData);
    _country = mrzString.substring(2, 5); // "NLD"
    _generation = int.parse(mrzString[5]); // 1, 2, or 3
    _licenseNumber = mrzString.substring(6, 17);
  }
}
