// Scanner wrapper for new navigation flow
// Provides callbacks for the scanner page to integrate with navigation

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mrz_parser/mrz_parser.dart';

import 'scan_screen.dart';
import 'package:vcmrtd/vcmrtd.dart';

class MrzReaderRouteParams {
  final DocumentType documentType;

  MrzReaderRouteParams({required this.documentType});

  static MrzReaderRouteParams fromQueryParams(Map<String, String> params) {
    return MrzReaderRouteParams(documentType: stringToDocumentType(params['document_type']!));
  }

  Map<String, String> toQueryParams() {
    return {'document_type': documentTypeToString(documentType)};
  }
}

class MrzScanResult {
  final DocumentType documentType;
  final String documentNumber;
  final DateTime dateOfBirth;
  final DateTime dateOfExpiry;
  final String? countryCode;
  final String rawMrz;
  final dynamic rawResult;

  const MrzScanResult({
    required this.documentType,
    required this.documentNumber,
    required this.dateOfBirth,
    required this.dateOfExpiry,
    required this.rawMrz,
    this.countryCode,
    this.rawResult,
  });
}

/// Wrapper around ScannerPage to handle navigation callbacks
class ScannerWrapper extends StatefulWidget {
  final Function(MrzScanResult) onMrzScanned;
  final VoidCallback onManualEntry;
  final VoidCallback onCancel;
  final VoidCallback onBack;
  final DocumentType documentType;

  const ScannerWrapper({
    super.key,
    required this.onMrzScanned,
    required this.onManualEntry,
    required this.onCancel,
    required this.onBack,
    this.documentType = DocumentType.passport,
  });

  @override
  State<ScannerWrapper> createState() => _ScannerWrapperState();
}

class _ScannerWrapperState extends State<ScannerWrapper> {
  bool _hasNavigated = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan ${_getDocumentTypeName()}'),
        leading: IconButton(icon: Icon(PlatformIcons(context).back), onPressed: widget.onBack),
      ),
      body: Stack(
        children: [
          ScannerPage(
            documentType: widget.documentType,
            onSuccess: (dynamic result, List<String> lines) {
              if (_hasNavigated) {
                return;
              }

              if (result == null) {
                _hasNavigated = true;
                widget.onCancel();
                return;
              }

              final scanResult = _createScanResult(result, lines);
              if (scanResult != null) {
                _hasNavigated = true;
                widget.onMrzScanned(scanResult);
                return;
              }

              _hasNavigated = true;
              _showDriverLicenceFallbackMessage(context);
              widget.onManualEntry();
            },
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomControls(context)),
        ],
      ),
    );
  }

  Widget _buildOverlayCard(BuildContext context) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Position the ${widget.documentType.displayName}',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              'Align the Machine Readable Zone (MRZ) with the frame at the bottom of the screen. Hold steady until scanning completes.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 24, 24, 32),
      decoration: BoxDecoration(color: Colors.transparent),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildOverlayCard(context),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              onPressed: () {
                widget.onManualEntry();
              },
              child: Text('Enter ${_getDocumentTypeName()} details manually', style: TextStyle(color: Colors.black)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _getDocumentTypeName() {
    return widget.documentType.displayName;
  }

  MrzScanResult? _createScanResult(dynamic result, List<String> lines) {
    if (result is MRZResult) {
      return MrzScanResult(
        documentType: widget.documentType,
        documentNumber: result.documentNumber,
        dateOfBirth: result.birthDate,
        dateOfExpiry: result.expiryDate,
        countryCode: result.countryCode,
        rawMrz: lines.join('\n'),
        rawResult: result,
      );
    }

    if (widget.documentType == DocumentType.driverLicense && result is MRZDriverLicenseResult) {
      final digits = _collectDriverLicenceDigits(result, lines);
      if (digits.length >= 12) {
        final dob = _parseMrzDate(digits.substring(0, 6), expectFuture: false);
        final expiry = _parseMrzDate(digits.substring(6, 12), expectFuture: true);
        if (dob != null && expiry != null) {
          final rawMrz = lines.isNotEmpty ? lines.first : '';
          return MrzScanResult(
            documentType: widget.documentType,
            documentNumber: result.documentNumber,
            dateOfBirth: dob,
            dateOfExpiry: expiry,
            countryCode: result.countryCode,
            rawMrz: rawMrz,
            rawResult: result,
          );
        }
      }
    }

    return null;
  }

  DateTime? _parseMrzDate(String yyMMdd, {required bool expectFuture}) {
    if (!RegExp(r'^\d{6}$').hasMatch(yyMMdd)) {
      return null;
    }

    final yy = int.tryParse(yyMMdd.substring(0, 2));
    final mm = int.tryParse(yyMMdd.substring(2, 4));
    final dd = int.tryParse(yyMMdd.substring(4, 6));

    if (yy == null || mm == null || dd == null) {
      return null;
    }

    final now = DateTime.now();
    final centuries = <int>{(now.year ~/ 100) * 100, ((now.year ~/ 100) - 1) * 100, ((now.year ~/ 100) + 1) * 100};

    DateTime? selected;
    for (final base in centuries) {
      final year = base + yy;
      try {
        final candidate = DateTime(year, mm, dd);
        if (expectFuture) {
          if (candidate.isAfter(now)) {
            if (selected == null || candidate.isBefore(selected)) {
              selected = candidate;
            }
          }
        } else {
          if (!candidate.isAfter(now)) {
            if (selected == null || candidate.isAfter(selected)) {
              selected = candidate;
            }
          }
        }
      } catch (_) {
        continue;
      }
    }

    return selected;
  }

  String _collectDriverLicenceDigits(MRZDriverLicenseResult result, List<String> lines) {
    final buffer = StringBuffer();

    void appendDigits(String source) {
      for (final rune in source.runes) {
        if (rune >= 48 && rune <= 57) {
          buffer.writeCharCode(rune);
        }
      }
    }

    appendDigits(result.randomData);

    if (buffer.length < 12 && lines.isNotEmpty) {
      final rawLine = lines.first;
      if (rawLine.length >= 29) {
        appendDigits(rawLine.substring(16, 29));
      }
    }

    return buffer.toString();
  }

  void _showDriverLicenceFallbackMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not extract all required data from the MRZ. Please enter the driver\'s licence details manually.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }
}
