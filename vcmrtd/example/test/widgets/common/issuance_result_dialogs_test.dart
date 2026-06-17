import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/widgets/common/issuance_result_dialogs.dart';

Widget _host(void Function(BuildContext) onTap) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(onPressed: () => onTap(context), child: const Text('open')),
        ),
      ),
    ),
  );
}

void main() {
  group('DialogHelpers.showSuccessDialog', () {
    testWidgets('shows title, message and continue button that fires callback', (tester) async {
      var continued = false;
      await tester.pumpWidget(
        _host(
          (context) => DialogHelpers.showSuccessDialog(
            context: context,
            title: 'Done',
            message: 'All good',
            onContinue: () => continued = true,
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsOneWidget);
      expect(find.text('All good'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(continued, isTrue);
    });
  });

  group('DialogHelpers.showErrorDialog', () {
    testWidgets('shows error text and OK dismisses dialog', (tester) async {
      await tester.pumpWidget(
        _host(
          (context) => DialogHelpers.showErrorDialog(
            context: context,
            title: 'Failed',
            message: 'Something broke',
            error: 'StackTrace: boom',
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Something broke'), findsOneWidget);
      expect(find.text('StackTrace: boom'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
      // No retry guidance text when onRetry is null.
      expect(find.textContaining('make an issue in GitHub'), findsNothing);
      expect(find.text('Retry'), findsNothing);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Failed'), findsNothing);
    });

    testWidgets('with onRetry shows retry guidance and fires callback', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _host(
          (context) => DialogHelpers.showErrorDialog(
            context: context,
            title: 'Failed',
            message: 'Something broke',
            error: 'boom',
            onRetry: () => retried = true,
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('make an issue in GitHub'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(retried, isTrue);
      // Dialog dismissed before retry callback ran.
      expect(find.text('Failed'), findsNothing);
    });
  });
}
