import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/widgets/common/animated_nfc_status_widget.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

Future<void> _pumpAnim(WidgetTester tester) async {
  // Advance animation frames without settling (continuous animations never settle).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  group('AnimatedNFCStatusWidget', () {
    testWidgets('renders message and icon for each state', (tester) async {
      final expectedIcons = <NFCReadingState, IconData>{
        NFCReadingState.waiting: Icons.nfc,
        NFCReadingState.connecting: Icons.wifi_find,
        NFCReadingState.reading: Icons.sync,
        NFCReadingState.authenticating: Icons.security,
        NFCReadingState.success: Icons.check_circle,
        NFCReadingState.error: Icons.error,
        NFCReadingState.cancelling: Icons.cancel,
        NFCReadingState.idle: Icons.nfc,
      };

      for (final entry in expectedIcons.entries) {
        await tester.pumpWidget(_wrap(AnimatedNFCStatusWidget(state: entry.key, message: 'msg-${entry.key.name}')));
        await _pumpAnim(tester);

        expect(find.text('msg-${entry.key.name}'), findsOneWidget, reason: 'message for ${entry.key}');
        expect(find.byIcon(entry.value), findsOneWidget, reason: 'icon for ${entry.key}');
      }
    });

    testWidgets('reading state shows linear progress with percentage text', (tester) async {
      await tester.pumpWidget(
        _wrap(const AnimatedNFCStatusWidget(state: NFCReadingState.reading, message: 'Reading', progress: 0.42)),
      );
      await _pumpAnim(tester);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
    });

    testWidgets('authenticating state shows indeterminate progress when progress is zero', (tester) async {
      await tester.pumpWidget(
        _wrap(const AnimatedNFCStatusWidget(state: NFCReadingState.authenticating, message: 'Auth')),
      );
      await _pumpAnim(tester);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // No percentage text when progress <= 0.
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('non-progress states hide the progress indicator', (tester) async {
      await tester.pumpWidget(_wrap(const AnimatedNFCStatusWidget(state: NFCReadingState.waiting, message: 'Waiting')));
      await _pumpAnim(tester);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('error state shows retry button and fires callback', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          AnimatedNFCStatusWidget(
            state: NFCReadingState.error,
            message: 'Something failed',
            onRetry: () => retried = true,
          ),
        ),
      );
      await _pumpAnim(tester);

      expect(find.text('Try Again'), findsOneWidget);
      await tester.tap(find.text('Try Again'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('error state without onRetry hides retry button', (tester) async {
      await tester.pumpWidget(_wrap(const AnimatedNFCStatusWidget(state: NFCReadingState.error, message: 'failed')));
      await _pumpAnim(tester);
      expect(find.text('Try Again'), findsNothing);
    });

    testWidgets('cancel button shown for waiting/connecting/reading and fires callback', (tester) async {
      for (final state in [NFCReadingState.waiting, NFCReadingState.connecting, NFCReadingState.reading]) {
        var cancelled = false;
        await tester.pumpWidget(
          _wrap(AnimatedNFCStatusWidget(state: state, message: 'm', onCancel: () => cancelled = true)),
        );
        await _pumpAnim(tester);

        expect(find.text('Cancel'), findsOneWidget, reason: 'cancel for $state');
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        expect(cancelled, isTrue, reason: 'cancel callback for $state');
      }
    });

    testWidgets('cancel button hidden for success state even with onCancel', (tester) async {
      await tester.pumpWidget(
        _wrap(AnimatedNFCStatusWidget(state: NFCReadingState.success, message: 'ok', onCancel: () {})),
      );
      await _pumpAnim(tester);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('transitioning between states triggers didUpdateWidget animation update', (tester) async {
      await tester.pumpWidget(_wrap(const AnimatedNFCStatusWidget(state: NFCReadingState.waiting, message: 'waiting')));
      await _pumpAnim(tester);

      // Move through several states to cover didUpdateWidget + each switch branch.
      for (final state in [
        NFCReadingState.connecting,
        NFCReadingState.reading,
        NFCReadingState.authenticating,
        NFCReadingState.success,
        NFCReadingState.error,
        NFCReadingState.cancelling,
        NFCReadingState.idle,
      ]) {
        await tester.pumpWidget(_wrap(AnimatedNFCStatusWidget(state: state, message: 'state-${state.name}')));
        await _pumpAnim(tester);
        expect(find.text('state-${state.name}'), findsOneWidget);
      }
    });

    testWidgets('error transition runs shake animation forward and reverse', (tester) async {
      await tester.pumpWidget(_wrap(const AnimatedNFCStatusWidget(state: NFCReadingState.waiting, message: 'waiting')));
      await tester.pump();

      await tester.pumpWidget(_wrap(const AnimatedNFCStatusWidget(state: NFCReadingState.error, message: 'err')));
      // Drive the shake controller (500ms forward then reverse).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('err'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });
  });
}
