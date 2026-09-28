import 'package:flutter/services.dart';
import 'package:vcmrtd/vcmrtd.dart';

/// What a manually typed document entry has to look like, shared by
/// [ManualEntryScreen] and apps that draw their own manual entry form.
///
/// The validators return an error message, or null when the value is fine.
abstract final class ManualEntryRules {
  /// Driving licences are unlocked with the single MRZ line printed on them;
  /// passports and identity cards with document number, date of birth and
  /// expiry date.
  static bool usesMrzLine(DocumentType type) => type == DocumentType.drivingLicence;

  static const mrzLineLength = 30;

  static final documentNumberFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
    LengthLimitingTextInputFormatter(15),
  ];

  static final mrzLineFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9<]')),
    LengthLimitingTextInputFormatter(mrzLineLength),
  ];

  static String? documentNumber(String? value, {required String documentName}) {
    if (value == null || value.trim().isEmpty) return '$documentName number is required';
    if (value.trim().length < 6) return '$documentName number must be at least 6 characters';
    return null;
  }

  static String? dateOfBirth(DateTime? value, {DateTime? now}) {
    if (value == null) return 'Date of birth is required';
    if (value.isAfter(now ?? DateTime.now())) return 'Date of birth cannot be in the future';
    return null;
  }

  static String? dateOfExpiry(DateTime? value, {required String documentName, DateTime? dateOfBirth, DateTime? now}) {
    if (value == null) return 'Expiry date is required';
    if (value.isBefore(now ?? DateTime.now())) return '$documentName has expired';
    if (dateOfBirth != null && value.isBefore(dateOfBirth)) return 'Expiry date cannot be before date of birth';
    return null;
  }

  static String? mrzLine(String? value) {
    if (value == null || value.trim().isEmpty) return 'MRZ string is required';
    if (value.trim().length != mrzLineLength) return 'MRZ must be exactly $mrzLineLength characters';
    if (!value.startsWith('D1') && !value.startsWith('D2') && !value.startsWith('DL')) {
      return 'MRZ must start with D1, D2, or DL';
    }
    return null;
  }
}
