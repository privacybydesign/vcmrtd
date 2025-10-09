// Scanner wrapper for new navigation flow
// Provides callbacks for the scanner page to integrate with navigation

import 'package:flutter/material.dart';
import 'package:vcmrtdapp/helpers/mrz_data.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import 'scan_screen.dart';
import '../../helpers/mrz_scanner.dart';

/// Wrapper around ScannerPage to handle navigation callbacks
class ScannerWrapper extends StatefulWidget {
  final Function(dynamic) onMrzScanned;
  final VoidCallback onCancel;
  final DocumentType documentType;

  const ScannerWrapper({
    Key? key,
    required this.onMrzScanned,
    required this.onCancel,
    this.documentType = DocumentType.passport,
  }) : super(key: key);

  @override
  State<ScannerWrapper> createState() => _ScannerWrapperState();
}

class _ScannerWrapperState extends State<ScannerWrapper> {
  bool _hasNavigated = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_hasNavigated) {
          widget.onCancel();
        }
        return false;
      },
      child: PlatformScaffold(
        body: ScannerPageDialog(
          documentType: widget.documentType,
          onResult: (dynamic result) {
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
      ),
    );
  }
}

/// Custom dialog wrapper to catch the MRZ result
class ScannerPageDialog extends StatefulWidget {
  final Function(dynamic) onResult;
  final DocumentType documentType;

  const ScannerPageDialog({
    Key? key,
    required this.onResult,
    this.documentType = DocumentType.passport,
  }) : super(key: key);

  @override
  State<ScannerPageDialog> createState() => _ScannerPageDialogState();
}

class _ScannerPageDialogState extends State<ScannerPageDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showScannerDialog();
    });
  }

  void _showScannerDialog() async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Material(
        child: ScannerPage(documentType: widget.documentType),
      ),
    );

    widget.onResult(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      ),
    );
  }
}