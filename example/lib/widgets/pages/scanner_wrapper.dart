// Scanner wrapper for new navigation flow
// Provides callbacks for the scanner page to integrate with navigation

import 'package:flutter/material.dart';
import 'package:vcmrtdapp/helpers/mrz_data.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import 'scan_screen.dart';

/// Wrapper around ScannerPage to handle navigation callbacks
class ScannerWrapper extends StatefulWidget {
  final Function(MRZResult) onMrzScanned;
  final VoidCallback onCancel;

  const ScannerWrapper({
    Key? key,
    required this.onMrzScanned,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<ScannerWrapper> createState() => _ScannerWrapperState();
}

class _ScannerWrapperState extends State<ScannerWrapper> {
  bool _hasNavigated = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        if (!_hasNavigated) {
          widget.onCancel();
        }
      },
      child: PlatformScaffold(
        body: ScannerPageDialog(
          onResult: (MRZResult? result) {
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
  final Function(MRZResult?) onResult;

  const ScannerPageDialog({
    Key? key,
    required this.onResult,
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
    final result = await showDialog<MRZResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Material(
        child: ScannerPage(),
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
