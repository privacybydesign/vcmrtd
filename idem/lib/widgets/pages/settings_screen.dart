import 'dart:io' show Platform;

import 'package:face_verification/face_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/providers/active_authenticiation_provider.dart';
import 'package:idem/providers/face_engine_provider.dart';
import 'package:idem/providers/liveness_mode_provider.dart';
import 'package:idem/providers/ocr_engine_provider.dart';

String _faceEngineLabel(AppLocalizations l10n, FaceEngineChoice choice) => switch (choice) {
  FaceEngineChoice.regula => 'Regula',
  FaceEngineChoice.onDevice => l10n.docFaceEngineOpenSource,
  FaceEngineChoice.iris => 'Iris SDK',
};

String _livenessModeLabel(AppLocalizations l10n, LivenessMode mode) => switch (mode) {
  LivenessMode.passive => l10n.docLivenessPassive,
  LivenessMode.active => l10n.docLivenessActive,
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
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.docSettingsTitle),
        leading: IconButton(tooltip: l10n.docBack, icon: const Icon(Icons.arrow_back), onPressed: onBackPressed),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l10n.docActiveAuthentication),
            subtitle: Text(l10n.docActiveAuthenticationSubtitle),
            value: ref.watch(activeAuthenticationProvider),
            onChanged: (value) => ref.read(activeAuthenticationProvider.notifier).set(value),
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(l10n.docFaceEngine),
            subtitle: Text(_faceEngineLabel(l10n, ref.watch(faceEngineProvider))),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickOption<FaceEngineChoice>(
              context: context,
              title: l10n.docFaceEngine,
              current: ref.read(faceEngineProvider),
              options: [
                (FaceEngineChoice.regula, _faceEngineLabel(l10n, FaceEngineChoice.regula)),
                (FaceEngineChoice.onDevice, _faceEngineLabel(l10n, FaceEngineChoice.onDevice)),
                (FaceEngineChoice.iris, _faceEngineLabel(l10n, FaceEngineChoice.iris)),
              ],
              onSelected: (choice) => ref.read(faceEngineProvider.notifier).set(choice),
            ),
          ),
          // Regula falls back to on-device when a session doesn't offer it.
          if (ref.watch(faceEngineProvider) != FaceEngineChoice.iris) ...[
            const Divider(height: 1),
            ListTile(
              title: Text(l10n.docLivenessDetection),
              subtitle: Text(_livenessModeLabel(l10n, ref.watch(livenessModeProvider))),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickOption<LivenessMode>(
                context: context,
                title: l10n.docLivenessDetection,
                current: ref.read(livenessModeProvider),
                options: [
                  (LivenessMode.passive, l10n.docLivenessPassive),
                  (LivenessMode.active, l10n.docLivenessActive),
                ],
                onSelected: (mode) => ref.read(livenessModeProvider.notifier).set(mode),
              ),
            ),
          ],
          if (showOcrEngineForTesting ?? Platform.isAndroid) ...[
            const Divider(height: 1),
            ListTile(
              title: Text(l10n.docOcrEngine),
              subtitle: Text(_ocrEngineLabel(ref.watch(ocrEngineProvider))),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickOption<OcrEngine>(
                context: context,
                title: l10n.docOcrEngine,
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
