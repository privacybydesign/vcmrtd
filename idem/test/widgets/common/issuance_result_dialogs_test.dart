import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/widgets/common/issuance_result_dialogs.dart';

Widget _host(void Function(BuildContext) onTap) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
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
  group('DialogHelpers.showInfoDialog', () {
    testWidgets('shows title and message, and OK dismisses it', (tester) async {
      await tester.pumpWidget(
        _host((context) => DialogHelpers.showInfoDialog(context: context, title: 'Note', message: 'Something')),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Something'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
