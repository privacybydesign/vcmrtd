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
import 'package:idem/providers/wallet_provider.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

  const SettingsScreen({
    super.key,
    required this.onBackPressed,
    this.onSavedDocumentsPressed,
    @visibleForTesting this.showOcrEngineForTesting,
  });

  /// Guided layout: opens the saved documents, listed under "Your documents".
  final VoidCallback? onSavedDocumentsPressed;

  @visibleForTesting
  final bool? showOcrEngineForTesting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guided = context.guided;
    if (guided != null) return _buildGuided(context, ref, guided);

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
              options: [for (final choice in FaceEngineChoice.values) (choice, _faceEngineLabel(l10n, choice))],
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
                  for (final mode in const [LivenessMode.passive, LivenessMode.active])
                    (mode, _livenessModeLabel(l10n, mode)),
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
                options: [for (final engine in OcrEngine.values) (engine, _ocrEngineLabel(engine))],
                onSelected: (engine) => ref.read(ocrEngineProvider.notifier).set(engine),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Guided layout: the same settings, grouped into cards with plain-language labels.
  Widget _buildGuided(BuildContext context, WidgetRef ref, GuidedStyle g) {
    Widget section(String title, List<Widget> rows) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.04, color: g.muted),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: g.subtleBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, row) in rows.indexed) ...[if (i > 0) Divider(height: 1, color: g.subtleBorder), row],
              ],
            ),
          ),
        ],
      ),
    );
    Widget row({required String title, required String subtitle, Widget? trailing, VoidCallback? onTap}) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: g.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 14, height: 1.4, color: g.bodyText)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            trailing ?? Icon(Icons.chevron_right, color: g.muted),
          ],
        ),
      ),
    );

    final l10n = context.l10n;
    final faceEngine = ref.watch(faceEngineProvider);
    return GuidedStatusBar(
      onDark: false,
      child: Scaffold(
        backgroundColor: g.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GuidedTopBar(
                leading: GuidedRoundButton(icon: Icons.chevron_left, tooltip: l10n.docBack, onPressed: onBackPressed),
                center: GuidedTopBarTitle(l10n.docSettingsTitle),
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (onSavedDocumentsPressed != null)
                      section(l10n.settingsYourDocuments, [
                        row(
                          title: l10n.settingsSavedDocuments,
                          subtitle: l10n.settingsSavedCount(ref.watch(walletProvider).length),
                          onTap: onSavedDocumentsPressed,
                        ),
                      ]),
                    section(l10n.settingsChipReading, [
                      MergeSemantics(
                        child: row(
                          title: l10n.settingsChipCheck,
                          subtitle: l10n.settingsChipCheckSubtitle,
                          trailing: Switch(
                            value: ref.watch(activeAuthenticationProvider),
                            activeTrackColor: g.action,
                            onChanged: (value) => ref.read(activeAuthenticationProvider.notifier).set(value),
                          ),
                        ),
                      ),
                    ]),
                    section(l10n.settingsSelfieCheck, [
                      row(
                        title: l10n.settingsFaceEngine,
                        subtitle: switch (faceEngine) {
                          FaceEngineChoice.regula => 'Regula',
                          FaceEngineChoice.onDevice => l10n.settingsFaceEngineOnDevice,
                          FaceEngineChoice.iris => 'Iris SDK',
                        },
                        onTap: () => _pickOption<FaceEngineChoice>(
                          context: context,
                          title: l10n.settingsFaceEngine,
                          current: ref.read(faceEngineProvider),
                          options: [
                            (FaceEngineChoice.regula, 'Regula'),
                            (FaceEngineChoice.onDevice, l10n.docFaceEngineOpenSource),
                            (FaceEngineChoice.iris, 'Iris SDK'),
                          ],
                          onSelected: (choice) => ref.read(faceEngineProvider.notifier).set(choice),
                        ),
                      ),
                      // Regula falls back to on-device when a session doesn't offer it.
                      if (faceEngine != FaceEngineChoice.iris)
                        row(
                          title: l10n.settingsLivenessCheck,
                          subtitle: switch (ref.watch(livenessModeProvider)) {
                            LivenessMode.passive => l10n.settingsLivenessPassive,
                            LivenessMode.active => l10n.settingsLivenessActive,
                          },
                          onTap: () => _pickOption<LivenessMode>(
                            context: context,
                            title: l10n.settingsLivenessCheck,
                            current: ref.read(livenessModeProvider),
                            options: [
                              (LivenessMode.passive, l10n.settingsLivenessPassive),
                              (LivenessMode.active, l10n.settingsLivenessActive),
                            ],
                            onSelected: (mode) => ref.read(livenessModeProvider.notifier).set(mode),
                          ),
                        ),
                    ]),
                    if (showOcrEngineForTesting ?? Platform.isAndroid)
                      section(l10n.settingsDocumentScanning, [
                        row(
                          title: l10n.settingsTextRecognition,
                          subtitle: _ocrEngineLabel(ref.watch(ocrEngineProvider)),
                          onTap: () => _pickOption<OcrEngine>(
                            context: context,
                            title: l10n.settingsTextRecognition,
                            current: ref.read(ocrEngineProvider),
                            options: const [
                              (OcrEngine.googleMlKit, 'Google ML Kit'),
                              (OcrEngine.tesseract4android, 'Tesseract4Android'),
                            ],
                            onSelected: (engine) => ref.read(ocrEngineProvider.notifier).set(engine),
                          ),
                        ),
                      ]),
                    const SizedBox(height: 32),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) => snapshot.hasData
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                l10n.settingsVersion(snapshot.data!.version),
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: g.muted),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ],
          ),
        ),
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
