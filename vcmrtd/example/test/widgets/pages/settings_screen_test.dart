import 'package:face_verification/face_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtdapp/providers/active_authenticiation_provider.dart';
import 'package:vcmrtdapp/providers/face_engine_provider.dart';
import 'package:vcmrtdapp/providers/liveness_mode_provider.dart';
import 'package:vcmrtdapp/providers/ocr_engine_provider.dart';
import 'package:vcmrtdapp/widgets/pages/settings_screen.dart';

void main() {
  group('SettingsScreen', () {
    testWidgets('back button calls onBackPressed', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: SettingsScreen(onBackPressed: () => pressed = true)),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Back'));
      expect(pressed, isTrue);
    });

    testWidgets('active authentication switch updates provider state', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SettingsScreen(onBackPressed: () {})),
        ),
      );
      await tester.pump();

      expect(container.read(activeAuthenticationProvider), isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(container.read(activeAuthenticationProvider), isTrue);
    });

    testWidgets('face verification engine tile shows current value and updates provider via picker', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SettingsScreen(onBackPressed: () {})),
        ),
      );
      await tester.pump();

      expect(find.text('Face verification engine'), findsOneWidget);
      expect(find.text('Open source'), findsOneWidget);

      await tester.tap(find.text('Face verification engine'));
      await tester.pumpAndSettle();

      expect(find.text('Iris SDK'), findsOneWidget);
      await tester.tap(find.text('Iris SDK'));
      await tester.pumpAndSettle();

      expect(container.read(faceEngineProvider), FaceEngineChoice.iris);
      expect(find.text('Iris SDK'), findsOneWidget);
    });

    testWidgets('liveness detection tile defaults to passive and updates provider via picker', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SettingsScreen(onBackPressed: () {})),
        ),
      );
      await tester.pump();

      expect(find.text('Liveness detection'), findsOneWidget);
      expect(find.text('Passive'), findsOneWidget);
      expect(container.read(livenessModeProvider), LivenessMode.passive);

      await tester.tap(find.text('Liveness detection'));
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsOneWidget);
      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();

      expect(container.read(livenessModeProvider), LivenessMode.active);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('liveness detection tile is hidden when the Iris SDK is selected', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SettingsScreen(onBackPressed: () {})),
        ),
      );
      await tester.pump();

      expect(find.text('Liveness detection'), findsOneWidget);

      container.read(faceEngineProvider.notifier).set(FaceEngineChoice.iris);
      await tester.pump();

      expect(find.text('Liveness detection'), findsNothing);
    });

    testWidgets('OCR engine tile can be shown and updates provider via picker', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SettingsScreen(onBackPressed: () {}, showOcrEngineForTesting: true)),
        ),
      );
      await tester.pump();

      expect(find.text('OCR engine'), findsOneWidget);
      expect(find.text('Google ML Kit'), findsOneWidget);

      await tester.tap(find.text('OCR engine'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tesseract4Android'));
      await tester.pumpAndSettle();

      expect(container.read(ocrEngineProvider), OcrEngine.tesseract4android);
    });
  });
}
