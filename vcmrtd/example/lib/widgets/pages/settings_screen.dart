import 'dart:io' show Platform;

import 'package:face_verification/face_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtdapp/providers/active_authenticiation_provider.dart';
import 'package:vcmrtdapp/providers/face_engine_provider.dart';
import 'package:vcmrtdapp/providers/liveness_mode_provider.dart';
import 'package:vcmrtdapp/providers/ocr_engine_provider.dart';

String _faceEngineLabel(FaceEngineChoice choice) => switch (choice) {
  FaceEngineChoice.onDevice => 'Open source',
  FaceEngineChoice.iris => 'Iris SDK',
};

String _livenessModeLabel(LivenessMode mode) => switch (mode) {
  LivenessMode.passive => 'Passive',
  LivenessMode.active => 'Active',
};

String _ocrEngineLabel(OcrEngine engine) => switch (engine) {
  OcrEngine.googleMlKit => 'Google ML Kit',
  OcrEngine.tesseract4android => 'Tesseract4Android',
};

class SettingsScreen extends ConsumerWidget {
  final VoidCallback onBackPressed;

  const SettingsScreen({super.key, required this.onBackPressed, @visibleForTesting this.showOcrEngineForTesting});

  @visibleForTesting
  final bool? showOcrEngineForTesting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: onBackPressed),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Active authentication'),
            subtitle: const Text('Perform active authentication when reading the document'),
            value: ref.watch(activeAuthenticationProvider),
            onChanged: (value) => ref.read(activeAuthenticationProvider.notifier).set(value),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Face verification engine'),
            subtitle: Text(_faceEngineLabel(ref.watch(faceEngineProvider))),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickOption<FaceEngineChoice>(
              context: context,
              title: 'Face verification engine',
              current: ref.read(faceEngineProvider),
              options: const [
                (FaceEngineChoice.onDevice, 'Open source'),
                (FaceEngineChoice.iris, 'Iris SDK'),
              ],
              onSelected: (choice) => ref.read(faceEngineProvider.notifier).set(choice),
            ),
          ),
          if (ref.watch(faceEngineProvider) == FaceEngineChoice.onDevice) ...[
            const Divider(height: 1),
            ListTile(
              title: const Text('Liveness detection'),
              subtitle: Text(_livenessModeLabel(ref.watch(livenessModeProvider))),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickOption<LivenessMode>(
                context: context,
                title: 'Liveness detection',
                current: ref.read(livenessModeProvider),
                options: const [
                  (LivenessMode.passive, 'Passive'),
                  (LivenessMode.active, 'Active'),
                ],
                onSelected: (mode) => ref.read(livenessModeProvider.notifier).set(mode),
              ),
            ),
          ],
          if (showOcrEngineForTesting ?? Platform.isAndroid) ...[
            const Divider(height: 1),
            ListTile(
              title: const Text('OCR engine'),
              subtitle: Text(_ocrEngineLabel(ref.watch(ocrEngineProvider))),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickOption<OcrEngine>(
                context: context,
                title: 'OCR engine',
                current: ref.read(ocrEngineProvider),
                options: const [
                  (OcrEngine.googleMlKit, 'Google ML Kit'),
                  (OcrEngine.tesseract4android, 'Tesseract4Android'),
                ],
                onSelected: (engine) => ref.read(ocrEngineProvider.notifier).set(engine),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickOption<T>({
    required BuildContext context,
    required String title,
    required T current,
    required List<(T, String)> options,
    required void Function(T) onSelected,
  }) async {
    final selected = await showDialog<T>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: [
          RadioGroup<T>(
            groupValue: current,
            onChanged: (value) => Navigator.of(context).pop(value),
            child: Column(
              children: options.map((o) => RadioListTile<T>(title: Text(o.$2), value: o.$1)).toList(),
            ),
          ),
        ],
      ),
    );
    if (selected != null) onSelected(selected);
  }
}
