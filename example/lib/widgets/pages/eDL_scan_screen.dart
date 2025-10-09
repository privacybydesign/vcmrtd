import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import '../../helpers/mrz_data.dart';

import '../../controllers/mrz_controller.dart';
import '../../helpers/mrz_scanner.dart';

class EdlScanScreen extends StatefulWidget {
  const EdlScanScreen({
    super.key,
    required this.onMrzScanned,
    required this.onManualEntry,
    required this.onBack,
  });

  final ValueChanged<MRZResult> onMrzScanned;
  final VoidCallback onManualEntry;
  final VoidCallback onBack;

  @override
  State<EdlScanScreen> createState() => _EdlScanScreenState();
}

class _EdlScanScreenState extends State<EdlScanScreen> {
  final MRZController _controller = MRZController();
  bool _hasCompletedScan = false;

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      material: (_, __) => MaterialScaffoldData(
        backgroundColor: Colors.black,
        extendBody: true,
      ),
      cupertino: (_, __) => CupertinoPageScaffoldData(
        backgroundColor: Colors.black,
      ),
      appBar: PlatformAppBar(
        backgroundColor: Colors.black,
        title: const Text('Scan Driving Licence Front Side'),
        leading: PlatformIconButton(
          icon: Icon(PlatformIcons(context).back),
          onPressed: widget.onBack,
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: MRZScanner(
                controller: _controller,
                onSuccess: (mrzResult, lines) {
                  if (_hasCompletedScan) return;
                  _hasCompletedScan = true;
                  widget.onMrzScanned(mrzResult);
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomControls(context),
            ),
          ],
        ),
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
          children: const [
            Text(
              'Position the driving licence front side',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
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
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildOverlayCard(context),
            const SizedBox(height: 20),
            PlatformElevatedButton(
              onPressed: () {
                widget.onManualEntry();
              },
              material: (_, __) => MaterialElevatedButtonData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              ),
              cupertino: (_, __) => CupertinoElevatedButtonData(
                color: Colors.white,
              ),
              child: const Text(
                'Enter passport details manually',
                style: TextStyle(color: Colors.black),
              ),
            ),
            const SizedBox(height: 12),
            PlatformTextButton(
              onPressed: () {
                setState(() {
                  _hasCompletedScan = false;
                  _controller.currentState?.resetScanning();
                });
              },
              material: (_, __) => MaterialTextButtonData(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
              cupertino: (_, __) => CupertinoTextButtonData(
                color: Colors.transparent,
              ),
              child: const Text(
                'Rescan MRZ',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
