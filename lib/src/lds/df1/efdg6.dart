// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// ignore_for_file: constant_identifier_names

import 'dart:typed_data';
import 'package:vcmrtd/extensions.dart';
import '../../../vcmrtd.dart';
import 'edl_dg6.dart';
import 'dg.dart';
import '../ef.dart';

class EfDG6 extends DataGroup {
  static const FID = 0x0106;
  static const SFI = 0x06;
  static const TAG_PASSPORT = DgTag(0x66);
  static const TAG_DRIVING_LICENSE = DgTag(0x75);

  // Static method to get the correct TAG based on document type
  static DgTag getTag(DocumentType documentType) {
    return documentType == DocumentType.driverLicense
        ? TAG_DRIVING_LICENSE
        : TAG_PASSPORT;
  }

  final DocumentType documentType;
  EDL_DG6? edlImageData;

  EfDG6.fromBytes(Uint8List data, this.documentType) : super.fromBytes(data);

  @override
  int get fid => FID;

  @override
  int get sfi => SFI;

  @override
  int get tag => getTag(documentType).value;

  Uint8List? get imageData => edlImageData?.imageData;

  ImageType? get imageType => edlImageData?.imageType;

  @override
  void parseContent(final Uint8List content) {
    if (documentType == DocumentType.driverLicense) {
      edlImageData = EDL_DG6.fromBytes(content);
    } else {
      throw EfParseError("DG6 parsing for passports not implemented (reserved for future)");
    }
  }
}