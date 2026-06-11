// Created by Nejc Skerjanc, copyright © 2023 ZeroPass. All rights reserved.

class DMRTDException implements Exception {
  final String message;
  String exceptionName = 'DMRTDException';

  DMRTDException(this.message);
  @override
  String toString() {
    return '$exceptionName: $message';
  }
}

/// Exception that contains sensitive data. The sensitive data is split from the generic data
/// so it's possible to know the sensitive part for debugging but it only logs the non-sensitive part
/// by default so it's harder to let sensitive data slip into logs where it doesn't belong.
class SensitiveException implements Exception {
  final String nonSensitive;
  final String? sensitive;

  SensitiveException({required this.nonSensitive, this.sensitive});

  @override
  String toString() {
    return "Exception with sensitive data:\n - Non-sensitive: $nonSensitive,\n - Sensitive: [OMITTED]";
  }

  String logWithSensitiveData() {
    return "Exception with sensitive data:\n - Non-sensitive: $nonSensitive,\n - Sensitive: $sensitive";
  }
}
