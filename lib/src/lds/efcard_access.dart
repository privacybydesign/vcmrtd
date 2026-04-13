// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// ignore_for_file: constant_identifier_names

import 'dart:typed_data';

import 'package:vcmrtd/extensions.dart';
import "package:vcmrtd/src/lds/df1/dg.dart";
import 'package:logging/logging.dart';

import '../lds/asn1ObjectIdentifiers.dart';
import 'ef.dart';
import 'substruct/pace_info.dart';
import 'substruct/security_infos.dart';

class EfCardAccess extends ElementaryFile {
  static const FID = 0x011C;
  static const SFI = 0x1C;
  static const TAG = DgTag(0x6C);

  SecurityInfos? _securityInfos;

  /// All SecurityInfos parsed from this EF.CardAccess file.
  ///
  /// EF.CardAccess is a `SET OF SecurityInfo` (ICAO 9303 Part 11 §9.2) and may
  /// contain heterogeneous entries — PACEInfo, PACEDomainParameterInfo,
  /// ChipAuthenticationInfo, ChipAuthenticationPublicKeyInfo,
  /// TerminalAuthenticationInfo, ActiveAuthenticationInfo, EFDIRInfo — in any
  /// combination. Use this getter when you need to inspect the full set;
  /// most callers want [paceInfo] for the preferred PACEInfo.
  SecurityInfos? get securityInfos => _securityInfos;

  /// Preferred `PACEInfo` for running a PACE session.
  ///
  /// When a chip advertises multiple PACEInfos (e.g. German ePassports
  /// advertise both `id-PACE-ECDH-GM-AES-CBC-CMAC-128` and
  /// `id-PACE-ECDH-CAM-AES-CBC-CMAC-128`), this getter returns the
  /// cryptographically strongest one: CAM is preferred over GM, GM is
  /// preferred over IM, and within the same mapping type a larger key
  /// length wins. Returns `null` if the file advertises no PACEInfo.
  PaceInfo? get paceInfo => _selectPreferredPaceInfo(_securityInfos?.paceInfos);

  bool get isPaceInfoSet => paceInfo != null;

  final _log = Logger("EfCardAccess");

  EfCardAccess.fromBytes(super.data) : super.fromBytes();

  @override
  int get fid => FID;

  @override
  int get sfi => SFI;

  @override
  void parse(Uint8List content) {
    _log.sdVerbose("Parsing EF.CardAccess${content.hex()}");

    _securityInfos = SecurityInfos.parse(content);

    _log.info(
      "Parsed EF.CardAccess SecurityInfos: "
      "total=${_securityInfos!.totalCount}, "
      "paceInfos=${_securityInfos!.paceInfos.length}, "
      "paceDomainParameterInfos=${_securityInfos!.paceDomainParameterInfos.length}, "
      "activeAuthenticationInfos=${_securityInfos!.activeAuthenticationInfos.length}, "
      "chipAuthenticationInfos=${_securityInfos!.chipAuthenticationInfos.length}, "
      "chipAuthenticationPublicKeyInfos=${_securityInfos!.chipAuthenticationPublicKeyInfos.length}, "
      "terminalAuthenticationInfos=${_securityInfos!.terminalAuthenticationInfos.length}, "
      "efDirInfos=${_securityInfos!.efDirInfos.length}, "
      "unhandled=${_securityInfos!.unhandledInfos.length}",
    );
  }
}

/// Selects the cryptographically strongest `PaceInfo` from [infos].
///
/// Preference order:
///   1. Mapping type: CAM > GM > IM (CAM additionally authenticates the chip
///      and is strictly stronger than GM; see ICAO 9303 p11 §4.4).
///   2. Key length (s256 > s192 > s128) within the same mapping type.
PaceInfo? _selectPreferredPaceInfo(List<PaceInfo>? infos) {
  if (infos == null || infos.isEmpty) {
    return null;
  }
  final sorted = [...infos];
  sorted.sort((a, b) {
    final byMapping = _mappingPreference(b.protocol.mappingType) - _mappingPreference(a.protocol.mappingType);
    if (byMapping != 0) return byMapping;
    return b.protocol.keyLength.value.compareTo(a.protocol.keyLength.value);
  });
  return sorted.first;
}

int _mappingPreference(MAPPING_TYPE mappingType) {
  switch (mappingType) {
    case MAPPING_TYPE.CAM:
      return 2;
    case MAPPING_TYPE.GM:
      return 1;
    case MAPPING_TYPE.IM:
      return 0;
  }
}
