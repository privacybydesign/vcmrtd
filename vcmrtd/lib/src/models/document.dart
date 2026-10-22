import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../vcmrtd.dart';

enum ImageType { jpeg, jpeg2000 }

/// The holder's portrait as the chip stores it: the bytes of the face image in
/// DG2 (passports, ID cards) or DG6 (driving licences), untouched.
///
/// [type] is what the document declared, which can be absent on a driving
/// licence. Nothing here re-encodes the image: a consumer that hands the bytes
/// to a decoder gets exactly what was on the chip, which is what any check
/// against the issuer's copy of the same portrait depends on.
class ChipPortrait {
  const ChipPortrait({required this.bytes, this.type});

  final Uint8List bytes;
  final ImageType? type;

  /// SHA-256 of [bytes] as lowercase hex.
  ///
  /// The on-device face verification method sends this with its verdict and
  /// the issuer compares it with its own hash of the portrait it
  /// authenticated, so a verdict cannot be carried over to another document.
  /// Both sides hash the chip's bytes untouched; anything that re-encoded the
  /// image on either side would break the comparison.
  String get sha256Hex => sha256.convert(bytes).toString();
}

abstract class DocumentData {
  /// The holder's portrait from the chip, or `null` when this document carried
  /// none that could be parsed.
  ///
  /// Deliberately part of the contract rather than a per-type extra: a
  /// document type that cannot answer this cannot take part in the face
  /// verification methods that match against the chip portrait, and that is
  /// worth a compile error rather than a silent `null`.
  ChipPortrait? get portrait;
}

class PassportData implements DocumentData {
  // From DG1
  final PassportMRZ mrz;

  // From DG2 (photo)
  final Uint8List photoImageData;
  final ImageType photoImageType;
  final int photoImageWidth;
  final int photoImageHeight;

  // From DG11 (additional personal details)
  final String? nameOfHolder;
  final List<String>? otherNames;
  final String? personalNumber;
  final DateTime? fullDateOfBirth;
  final List<String>? placeOfBirth;
  final List<String>? permanentAddress;
  final String? telephone;
  final String? profession;
  final String? title;
  final String? personalSummary;
  final Uint8List? proofOfCitizenship;
  final List<String>? otherValidTDNumbers;
  final String? custodyInformation;

  // From DG12 (document details)
  final DateTime? dateOfIssue;
  final String? issuingAuthority;

  // From DG15 (active auth)
  final AAPublicKey? aaPublicKey;

  // Raw bytes for unparsed DGs
  final Uint8List? dg3RawBytes;
  final Uint8List? dg4RawBytes;
  final Uint8List? dg5RawBytes;
  final Uint8List? dg6RawBytes;
  final Uint8List? dg7RawBytes;
  final Uint8List? dg8RawBytes;
  final Uint8List? dg9RawBytes;
  final Uint8List? dg10RawBytes;
  final Uint8List? dg13RawBytes;
  final Uint8List? dg14RawBytes;
  final Uint8List? dg16RawBytes;

  // Raw bytes for the DGs that are also individually parsed above (mrz,
  // photo*, DG11/DG12 fields, aaPublicKey). Passive Authentication hashes
  // the data group exactly as stored on the chip, so verifying it needs
  // these bytes verbatim — the parsed fields above can't be re-derived back
  // into a byte-identical encoding.
  final Uint8List? dg1RawBytes;
  final Uint8List? dg2RawBytes;
  final Uint8List? dg11RawBytes;
  final Uint8List? dg12RawBytes;
  final Uint8List? dg15RawBytes;

  PassportData({
    required this.mrz,
    required this.photoImageData,
    required this.photoImageType,
    required this.photoImageWidth,
    required this.photoImageHeight,
    this.nameOfHolder,
    this.otherNames,
    this.personalNumber,
    this.fullDateOfBirth,
    this.placeOfBirth,
    this.permanentAddress,
    this.telephone,
    this.profession,
    this.title,
    this.personalSummary,
    this.proofOfCitizenship,
    this.otherValidTDNumbers,
    this.custodyInformation,
    this.dateOfIssue,
    this.issuingAuthority,
    this.aaPublicKey,
    this.dg3RawBytes,
    this.dg4RawBytes,
    this.dg5RawBytes,
    this.dg6RawBytes,
    this.dg7RawBytes,
    this.dg8RawBytes,
    this.dg9RawBytes,
    this.dg10RawBytes,
    this.dg13RawBytes,
    this.dg14RawBytes,
    this.dg16RawBytes,
    this.dg1RawBytes,
    this.dg2RawBytes,
    this.dg11RawBytes,
    this.dg12RawBytes,
    this.dg15RawBytes,
  });

  @override
  ChipPortrait? get portrait =>
      photoImageData.isEmpty ? null : ChipPortrait(bytes: photoImageData, type: photoImageType);

  /// The holder's name as it should be displayed to the user.
  ///
  /// Prefers the DG11 `nameOfHolder` field, which is UTF-8 encoded and
  /// preserves diacritics and special characters (e.g. `Ć`) exactly as they
  /// appear in the visual inspection zone of the document. Falls back to the
  /// MRZ name — which is transliterated to basic Latin per ICAO 9303
  /// (e.g. `Ć` → `C`) — only when DG11 is absent or blank.
  ///
  /// Note: this is for display only. The MRZ remains the source of truth for
  /// machine-readable / check-digit logic.
  String get displayName {
    final dg11Name = nameOfHolder?.trim();
    if (dg11Name != null && dg11Name.isNotEmpty) {
      return dg11Name;
    }
    return '${mrz.firstName} ${mrz.lastName}';
  }
}

class DrivingLicenceData implements DocumentData {
  // From DG1
  final String issuingMemberState;
  final String holderSurname;
  final String holderOtherName;
  final String dateOfBirth;
  final String placeOfBirth;
  final String dateOfIssue;
  final String dateOfExpiry;
  final String issuingAuthority;
  final String documentNumber;
  final List<DrivingLicenceCategory> categories;

  // From DG5 (signature image)
  final ImageType? signatureImageType;
  final Uint8List? signatureImageData;

  // From DG6 (photo)
  final Uint8List photoImageData;
  final ImageType? photoImageType;
  final int? patronHeaderVersion;
  final int? biometricType;
  final int? numberOfInstances;

  // DG12
  final String bapInputString;
  final String saiType;

  // From DG13
  final AAPublicKey? aaPublicKey;

  // Raw bytes for unparsed DGs
  final Uint8List? dg2RawBytes;
  final Uint8List? dg3RawBytes;
  final Uint8List? dg4RawBytes;
  final Uint8List? dg5RawBytes;
  final Uint8List? dg7RawBytes;
  final Uint8List? dg8RawBytes;
  final Uint8List? dg9RawBytes;
  final Uint8List? dg10RawBytes;
  final Uint8List? dg11RawBytes;
  final Uint8List? dg12RawBytes;
  final Uint8List? dg13RawBytes;
  final Uint8List? dg14RawBytes;

  // Raw bytes for the DGs that are also individually parsed above (holder
  // fields, photoImageData). Passive Authentication hashes the data group
  // exactly as stored on the chip, so verifying it needs these bytes
  // verbatim — the parsed fields above can't be re-derived back into a
  // byte-identical encoding.
  final Uint8List? dg1RawBytes;
  final Uint8List? dg6RawBytes;

  DrivingLicenceData({
    required this.issuingMemberState,
    required this.holderSurname,
    required this.holderOtherName,
    required this.dateOfBirth,
    required this.placeOfBirth,
    required this.dateOfIssue,
    required this.dateOfExpiry,
    required this.issuingAuthority,
    required this.documentNumber,
    required this.photoImageData,
    required this.bapInputString,
    required this.saiType,
    required this.aaPublicKey,
    required this.categories,
    this.photoImageType,
    this.patronHeaderVersion,
    this.biometricType,
    this.numberOfInstances,
    this.signatureImageType,
    this.signatureImageData,
    this.dg2RawBytes,
    this.dg3RawBytes,
    this.dg4RawBytes,
    this.dg5RawBytes,
    this.dg7RawBytes,
    this.dg8RawBytes,
    this.dg9RawBytes,
    this.dg10RawBytes,
    this.dg11RawBytes,
    this.dg12RawBytes,
    this.dg13RawBytes,
    this.dg14RawBytes,
    this.dg1RawBytes,
    this.dg6RawBytes,
  });

  @override
  ChipPortrait? get portrait =>
      photoImageData.isEmpty ? null : ChipPortrait(bytes: photoImageData, type: photoImageType);
}
