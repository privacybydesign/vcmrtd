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

/// Wrapper around ScannerPage to handle navigation callbacks
class ScannerWrapper extends StatefulWidget {
  final Function(MRZResult) onMrzScanned;
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
            onSuccess: (dynamic result) {
              if (!_hasNavigated) {
                _hasNavigated = true;
                if (result != null) {
                  widget.onMrzScanned(result);
                } else {
                  widget.onCancel();
                }
              }
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
}
