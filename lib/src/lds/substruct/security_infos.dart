// Heterogeneous SecurityInfos parsing, modelled on gmrtd's reference
// implementation (document/security_infos.go).
//
// Per ICAO 9303 Part 11 §9.2:
//
//   SecurityInfos ::= SET OF SecurityInfo
//   SecurityInfo  ::= SEQUENCE {
//     protocol      OBJECT IDENTIFIER,
//     requiredData  ANY DEFINED BY protocol,
//     optionalData  ANY DEFINED BY protocol OPTIONAL
//   }
//
// Concrete SecurityInfo types are distinguished by the protocol OID, not by
// position in the SET. DER `SET OF` orders elements lexicographically by
// encoded value (X.690 §11.6), so a German ePassport advertising EAC will
// typically place a `TerminalAuthenticationInfo` ahead of its `PACEInfo`
// entries. This parser iterates every element in the SET and dispatches
// through per-type handlers — matching gmrtd's `DecodeSecurityInfos` — and
// records anything unrecognised as an `UnhandledInfo` rather than throwing.

import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:pointycastle/asn1/asn1_parser.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart';
import 'package:pointycastle/asn1/primitives/asn1_object_identifier.dart';
import 'package:pointycastle/asn1/primitives/asn1_octet_string.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:pointycastle/asn1/primitives/asn1_set.dart';

import '../ef.dart';
import 'pace_info.dart';

// ----------------------------------------------------------------------------
// Base OIDs (ICAO 9303 Part 11 §9.2), matching gmrtd/oid/oid.go.
// ----------------------------------------------------------------------------

const String _oidPaceDhGm = '0.4.0.127.0.7.2.2.4.1';
const String _oidPaceEcdhGm = '0.4.0.127.0.7.2.2.4.2';
const String _oidPaceDhIm = '0.4.0.127.0.7.2.2.4.3';
const String _oidPaceEcdhIm = '0.4.0.127.0.7.2.2.4.4';
const String _oidPaceEcdhCam = '0.4.0.127.0.7.2.2.4.6';
const String _oidTa = '0.4.0.127.0.7.2.2.2';
const String _oidCaDh = '0.4.0.127.0.7.2.2.3.1';
const String _oidCaEcdh = '0.4.0.127.0.7.2.2.3.2';
const String _oidPkDh = '0.4.0.127.0.7.2.2.1.1';
const String _oidPkEcdh = '0.4.0.127.0.7.2.2.1.2';
const String _oidAaProtocol = '2.23.136.1.1.5';
const String _oidEfDir = '1.3.27.1.1.13';

/// Strict OID prefix test: `oid` must have strictly more arcs than `prefix`
/// (matches gmrtd's `OidHasPrefix`).
bool _oidHasPrefix(String oid, String prefix) =>
    oid.startsWith('$prefix.');

// ----------------------------------------------------------------------------
// Type predicates — mirror the `isXxx` helpers in gmrtd/document/security_infos.go.
// ----------------------------------------------------------------------------

/// `PACEInfo` — OID is a strict child of one of the 5 PACE base OIDs.
bool _isPaceInfo(String oid) =>
    _oidHasPrefix(oid, _oidPaceDhGm) ||
    _oidHasPrefix(oid, _oidPaceEcdhGm) ||
    _oidHasPrefix(oid, _oidPaceDhIm) ||
    _oidHasPrefix(oid, _oidPaceEcdhIm) ||
    _oidHasPrefix(oid, _oidPaceEcdhCam);

/// `PACEDomainParameterInfo` — OID is exactly one of the 5 PACE base OIDs.
bool _isPaceDomainParameterInfo(String oid) =>
    oid == _oidPaceDhGm ||
    oid == _oidPaceEcdhGm ||
    oid == _oidPaceDhIm ||
    oid == _oidPaceEcdhIm ||
    oid == _oidPaceEcdhCam;

/// `ActiveAuthenticationInfo` — OID is `id-icao-mrtd-security-aaProtocolObject`.
bool _isActiveAuthenticationInfo(String oid) => oid == _oidAaProtocol;

/// `ChipAuthenticationInfo` — OID is a strict child of `id-CA-DH` or
/// `id-CA-ECDH`.
bool _isChipAuthenticationInfo(String oid) =>
    _oidHasPrefix(oid, _oidCaDh) || _oidHasPrefix(oid, _oidCaEcdh);

/// `ChipAuthenticationPublicKeyInfo` — OID is exactly `id-PK-DH` or `id-PK-ECDH`.
bool _isChipAuthenticationPublicKeyInfo(String oid) =>
    oid == _oidPkDh || oid == _oidPkEcdh;

/// `TerminalAuthenticationInfo` — OID is `id-TA` or a child of `id-TA`.
bool _isTerminalAuthenticationInfo(String oid) =>
    oid == _oidTa || _oidHasPrefix(oid, _oidTa);

/// `EFDIRInfo` — OID is exactly `id-EFDIR`.
bool _isEfDirInfo(String oid) => oid == _oidEfDir;

// ----------------------------------------------------------------------------
// Concrete SecurityInfo record types.
// ----------------------------------------------------------------------------

class PaceDomainParameterInfo {
  final String protocol;
  final ASN1Sequence domainParameter;
  final int? parameterId;

  PaceDomainParameterInfo({
    required this.protocol,
    required this.domainParameter,
    required this.parameterId,
  });
}

class ActiveAuthenticationInfo {
  final String protocol;
  final int version;
  final String signatureAlgorithm;

  ActiveAuthenticationInfo({
    required this.protocol,
    required this.version,
    required this.signatureAlgorithm,
  });
}

class ChipAuthenticationInfo {
  final String protocol;
  final int version;
  final int? keyId;

  ChipAuthenticationInfo({
    required this.protocol,
    required this.version,
    required this.keyId,
  });
}

class ChipAuthenticationPublicKeyInfo {
  final String protocol;
  final ASN1Sequence chipAuthenticationPublicKey; // SubjectPublicKeyInfo
  final int? keyId;

  ChipAuthenticationPublicKeyInfo({
    required this.protocol,
    required this.chipAuthenticationPublicKey,
    required this.keyId,
  });
}

class TerminalAuthenticationInfo {
  final String protocol;
  final int version;

  TerminalAuthenticationInfo({required this.protocol, required this.version});
}

class EfDirInfo {
  final String protocol;
  final Uint8List efDir;

  EfDirInfo({required this.protocol, required this.efDir});
}

class UnhandledInfo {
  final String protocol;
  final ASN1Sequence raw;

  UnhandledInfo({required this.protocol, required this.raw});
}

// ----------------------------------------------------------------------------
// SecurityInfos — container + parser.
// ----------------------------------------------------------------------------

class SecurityInfos {
  final Uint8List rawData;
  final List<PaceInfo> paceInfos = [];
  final List<PaceDomainParameterInfo> paceDomainParameterInfos = [];
  final List<ActiveAuthenticationInfo> activeAuthenticationInfos = [];
  final List<ChipAuthenticationInfo> chipAuthenticationInfos = [];
  final List<ChipAuthenticationPublicKeyInfo> chipAuthenticationPublicKeyInfos =
      [];
  final List<TerminalAuthenticationInfo> terminalAuthenticationInfos = [];
  final List<EfDirInfo> efDirInfos = [];
  final List<UnhandledInfo> unhandledInfos = [];

  static final _log = Logger('SecurityInfos');

  SecurityInfos._(this.rawData);

  /// Total number of recognised + unhandled SecurityInfo entries.
  int get totalCount =>
      paceInfos.length +
      paceDomainParameterInfos.length +
      activeAuthenticationInfos.length +
      chipAuthenticationInfos.length +
      chipAuthenticationPublicKeyInfos.length +
      terminalAuthenticationInfos.length +
      efDirInfos.length +
      unhandledInfos.length;

  /// Parses `SecurityInfos ::= SET OF SecurityInfo` from [data].
  factory SecurityInfos.parse(Uint8List data) {
    final secInfos = SecurityInfos._(data);

    final parser = ASN1Parser(data);
    if (!parser.hasNext()) {
      throw EfParseError("Invalid SecurityInfos. No data to parse.");
    }
    final top = parser.nextObject();
    if (top is! ASN1Set) {
      throw EfParseError(
        "Invalid SecurityInfos. Top-level object is not an ASN.1 SET.",
      );
    }

    final elements = top.elements;
    if (elements == null) {
      return secInfos;
    }

    for (final element in elements) {
      if (element is! ASN1Sequence) {
        _log.warning("Skipping non-SEQUENCE element in SecurityInfos SET");
        continue;
      }
      secInfos._dispatch(element);
    }

    return secInfos;
  }

  void _dispatch(ASN1Sequence seq) {
    final seqElements = seq.elements;
    if (seqElements == null || seqElements.isEmpty) {
      _log.warning("Skipping empty SecurityInfo SEQUENCE");
      return;
    }
    final first = seqElements.first;
    if (first is! ASN1ObjectIdentifier) {
      _log.warning("Skipping SecurityInfo with non-OID first element");
      return;
    }
    final oid = first.objectIdentifierAsString;
    if (oid == null) {
      _log.warning("Skipping SecurityInfo with unreadable OID");
      return;
    }

    // Dispatch chain mirrors gmrtd's `securityInfoHandleFnArr`. Handlers are
    // tried in order; anything left unhandled is recorded as `UnhandledInfo`.
    //
    // Individual handlers may fail to fully parse a record that is present
    // on the chip but malformed — treat those as unhandled (with a log line)
    // rather than aborting the whole SecurityInfos parse.
    try {
      if (_isPaceInfo(oid)) {
        paceInfos.add(PaceInfo(content: seq));
        return;
      }
      if (_isPaceDomainParameterInfo(oid)) {
        paceDomainParameterInfos.add(_parsePaceDomainParameterInfo(oid, seq));
        return;
      }
      if (_isActiveAuthenticationInfo(oid)) {
        activeAuthenticationInfos.add(_parseActiveAuthenticationInfo(oid, seq));
        return;
      }
      if (_isChipAuthenticationInfo(oid)) {
        chipAuthenticationInfos.add(_parseChipAuthenticationInfo(oid, seq));
        return;
      }
      if (_isChipAuthenticationPublicKeyInfo(oid)) {
        chipAuthenticationPublicKeyInfos
            .add(_parseChipAuthenticationPublicKeyInfo(oid, seq));
        return;
      }
      if (_isTerminalAuthenticationInfo(oid)) {
        terminalAuthenticationInfos
            .add(_parseTerminalAuthenticationInfo(oid, seq));
        return;
      }
      if (_isEfDirInfo(oid)) {
        efDirInfos.add(_parseEfDirInfo(oid, seq));
        return;
      }
    } catch (e) {
      _log.warning("Failed to parse SecurityInfo (OID $oid): $e");
      // fall through and record as unhandled
    }

    unhandledInfos.add(UnhandledInfo(protocol: oid, raw: seq));
  }

  PaceDomainParameterInfo _parsePaceDomainParameterInfo(
    String oid,
    ASN1Sequence seq,
  ) {
    final els = seq.elements!;
    final domainParameter = els[1] as ASN1Sequence;
    int? parameterId;
    if (els.length >= 3) {
      parameterId = (els[2] as ASN1Integer).integer?.toInt();
    }
    return PaceDomainParameterInfo(
      protocol: oid,
      domainParameter: domainParameter,
      parameterId: parameterId,
    );
  }

  ActiveAuthenticationInfo _parseActiveAuthenticationInfo(
    String oid,
    ASN1Sequence seq,
  ) {
    final els = seq.elements!;
    final version = (els[1] as ASN1Integer).integer!.toInt();
    final sigAlg =
        (els[2] as ASN1ObjectIdentifier).objectIdentifierAsString!;
    return ActiveAuthenticationInfo(
      protocol: oid,
      version: version,
      signatureAlgorithm: sigAlg,
    );
  }

  ChipAuthenticationInfo _parseChipAuthenticationInfo(
    String oid,
    ASN1Sequence seq,
  ) {
    final els = seq.elements!;
    final version = (els[1] as ASN1Integer).integer!.toInt();
    int? keyId;
    if (els.length >= 3) {
      keyId = (els[2] as ASN1Integer).integer?.toInt();
    }
    return ChipAuthenticationInfo(
      protocol: oid,
      version: version,
      keyId: keyId,
    );
  }

  ChipAuthenticationPublicKeyInfo _parseChipAuthenticationPublicKeyInfo(
    String oid,
    ASN1Sequence seq,
  ) {
    final els = seq.elements!;
    final spki = els[1] as ASN1Sequence;
    int? keyId;
    if (els.length >= 3) {
      keyId = (els[2] as ASN1Integer).integer?.toInt();
    }
    return ChipAuthenticationPublicKeyInfo(
      protocol: oid,
      chipAuthenticationPublicKey: spki,
      keyId: keyId,
    );
  }

  TerminalAuthenticationInfo _parseTerminalAuthenticationInfo(
    String oid,
    ASN1Sequence seq,
  ) {
    final els = seq.elements!;
    final version = (els[1] as ASN1Integer).integer!.toInt();
    return TerminalAuthenticationInfo(protocol: oid, version: version);
  }

  EfDirInfo _parseEfDirInfo(String oid, ASN1Sequence seq) {
    final els = seq.elements!;
    final octetString = els[1] as ASN1OctetString;
    return EfDirInfo(
      protocol: oid,
      efDir: Uint8List.fromList(octetString.octets ?? Uint8List(0)),
    );
  }
}
