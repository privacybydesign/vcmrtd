// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// ignore_for_file: constant_identifier_names

import 'dart:typed_data';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/lds/df1/passport_dg1.dart';
import '../../../vcmrtd.dart';
import 'edl_dg1.dart';

class EfDG1 extends DataGroup {
  static const FID = 0x0101;
  static const SFI = 0x01;
  static const TAG = DgTag(0x61);
  EDL_DG1? edlData;
  PassportDG1? passportData;

  final DocumentType documentType;

  late final PassportMRZ _mrz;

  EfDG1.fromBytes(super.data, this.documentType) : super.fromBytes();

  @override
  int get fid => FID;

  @override
  int get sfi => SFI;

  @override
  int get tag => TAG.value;

  @override
  void parseContent(final Uint8List content) {
    final tlv = TLV.fromBytes(content);

    if (documentType == DocumentType.passport) {
      if (tlv.tag != 0x5F1F) {
        throw EfParseError("Invalid data object tag=${tlv.tag.hex()}, expected object with tag=5F1F");
      }
      _mrz = PassportMRZ(tlv.value);
      passportData = PassportDG1(_mrz);
    } else if (documentType == DocumentType.driverLicense) {
      if (tlv.tag != 0x5f01) {
        throw EfParseError("Invalid data object tag=${tlv.tag.hex()}, expected object with tag=5F01");
      }
      edlData = EDL_DG1.fromBytes(content);
    }
  }
}
