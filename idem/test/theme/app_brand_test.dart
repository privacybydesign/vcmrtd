import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/theme/app_brand.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/theme/brands/cm_theme.dart';
import 'package:idem/widgets/pages/document_selection_screen.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _home(ThemeData theme) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: theme,
      home: DocumentTypeSelectionScreen(
        onDocumentTypeSelected: (_) {},
        onSettingsPressed: () {},
        onScanQrPressed: () {},
      ),
    ),
  );
}

void main() {
  group('AppBrand.fromName', () {
    test('parses brand names case- and whitespace-insensitively', () {
      expect(AppBrand.fromName('cm'), AppBrand.cm);
      expect(AppBrand.fromName(' CM '), AppBrand.cm);
      expect(AppBrand.fromName('idem'), AppBrand.idem);
    });

    test('rejects an unknown brand instead of falling back to the default', () {
      expect(() => AppBrand.fromName('acme'), throwsArgumentError);
    });

    test('defaults to idem when no BRAND is defined', () {
      expect(AppBrand.current, AppBrand.idem);
    });
  });

  group('brand themes', () {
    test('the idem theme carries the no-override brand', () {
      expect(AppBrand.idem.theme.extension<BrandTheme>(), same(BrandTheme.idem));
    });

    test('the cm theme carries the CM brand', () {
      final theme = AppBrand.cm.theme;
      expect(theme.extension<BrandTheme>(), same(cmBrandTheme));
      expect(theme.colorScheme.primary, CmColors.action);
    });

    test('every asset the CM brand names is in the repo', () {
      for (final path in [cmBrandTheme.appBarLogoAsset!, cmBrandTheme.markAsset!]) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('every brand font declared in pubspec.yaml is in the repo', () {
      final declared = RegExp(
        r'asset: (assets/brands/\S+\.ttf)',
      ).allMatches(File('pubspec.yaml').readAsStringSync()).map((m) => m.group(1)!).toList();
      expect(declared, isNotEmpty);
      for (final path in declared) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('CM button and text colours meet WCAG AA contrast on their backgrounds', () {
      expect(_contrast(CmColors.action, Colors.white), greaterThanOrEqualTo(4.5));
      expect(_contrast(CmColors.ink, CmColors.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(CmColors.bodyText, Colors.white), greaterThanOrEqualTo(4.5));
      expect(_contrast(CmColors.purple, CmColors.purpleTint), greaterThanOrEqualTo(4.5));
    });
  });

  group('home screen branding', () {
    testWidgets('idem shows the text title and no attribution', (tester) async {
      await tester.pumpWidget(_home(AppBrand.idem.theme));
      await tester.pump();
      expect(find.text('VCMRTD'), findsOneWidget);
      expect(find.text('Powered by Idem'), findsNothing);
    });

    testWidgets('cm shows its logo and the Powered by Idem line', (tester) async {
      await tester.pumpWidget(_home(AppBrand.cm.theme));
      await tester.pump();
      expect(find.bySemanticsLabel('CM.com'), findsOneWidget);
      expect(find.text('VCMRTD'), findsNothing);
      expect(find.text('Powered by Idem'), findsOneWidget);
    });
  });
}
