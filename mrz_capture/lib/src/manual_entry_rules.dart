import 'package:flutter/services.dart';
import 'package:vcmrtd/vcmrtd.dart';

import '../l10n/mrz_capture_localizations.dart';

/// What a manually typed document entry has to look like, shared by
/// [ManualEntryScreen] and apps that draw their own manual entry form.
///
/// The validators return an error message, or null when the value is fine.
/// Given [MrzCaptureLocalizations] (and the document's [DocumentType.name] as
/// `docType`), the message is in that language; English otherwise.
abstract final class ManualEntryRules {
  /// Driving licences are unlocked with the single MRZ line printed on them;
  /// passports and identity cards with document number, date of birth and
  /// expiry date.
  static bool usesMrzLine(DocumentType type) => type == DocumentType.drivingLicence;

  static const mrzLineLength = 30;

  /// How a driving licence's MRZ line starts.
  static const drivingLicenceMrzPrefixes = ['D1', 'D2', 'DL'];

  /// The `docType` of the messages when the caller names none.
  static const _otherDocType = 'other';

  static final documentNumberFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
    LengthLimitingTextInputFormatter(15),
  ];

  static final mrzLineFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9<]')),
    LengthLimitingTextInputFormatter(mrzLineLength),
  ];

  static String? documentNumber(
    String? value, {
    required String documentName,
    MrzCaptureLocalizations? l10n,
    String docType = _otherDocType,
  }) {
    if (value == null || value.trim().isEmpty) {
      return l10n?.mrzDocNumberRequired(docType) ?? '$documentName number is required';
    }
    if (value.trim().length < 6) {
      return l10n?.mrzDocNumberTooShort(docType) ?? '$documentName number must be at least 6 characters';
    }
    return null;
  }

  static String? dateOfBirth(DateTime? value, {DateTime? now, MrzCaptureLocalizations? l10n}) {
    if (value == null) return l10n?.mrzDobRequired ?? 'Date of birth is required';
    if (value.isAfter(now ?? DateTime.now())) return l10n?.mrzDobInFuture ?? 'Date of birth cannot be in the future';
    return null;
  }

  static String? dateOfExpiry(
    DateTime? value, {
    required String documentName,
    DateTime? dateOfBirth,
    DateTime? now,
    MrzCaptureLocalizations? l10n,
    String docType = _otherDocType,
  }) {
    if (value == null) return l10n?.mrzExpiryRequired ?? 'Expiry date is required';
    if (value.isBefore(now ?? DateTime.now())) return l10n?.mrzDocumentExpired(docType) ?? '$documentName has expired';
    if (dateOfBirth != null && value.isBefore(dateOfBirth)) {
      return l10n?.mrzExpiryBeforeDob ?? 'Expiry date cannot be before date of birth';
    }
    return null;
  }

  static String? mrzLine(String? value, {MrzCaptureLocalizations? l10n}) {
    if (value == null || value.trim().isEmpty) return l10n?.mrzStringRequired ?? 'MRZ string is required';
    if (value.trim().length != mrzLineLength) {
      return l10n?.mrzStringLength ?? 'MRZ must be exactly $mrzLineLength characters';
    }
    if (!drivingLicenceMrzPrefixes.any(value.startsWith)) {
      return l10n?.mrzStringPrefix ?? 'MRZ must start with D1, D2, or DL';
    }
    return null;
  }
}
