import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:idem/l10n/l10n.dart';
import 'package:idem/theme/app_theme.dart';
import 'package:idem/theme/brand_theme.dart';
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
  group('app theme', () {
    test('defaults to the Idem branding in the guided layout', () {
      final theme = appTheme();
      final brand = theme.extension<BrandTheme>()!;
      expect(brand.name, 'Idem');
      expect(brand.logo, isNull);
      expect(brand.guided, isNotNull);
      expect(theme.colorScheme.primary, AppBranding.idem.primary);
    });

    test('highlights on the header stay readable, even with a near-black primary', () {
      const dark = AppBranding(name: 'Dark', primary: Color(0xFF18181B), secondary: Color(0xFF52525B));
      for (final branding in [AppBranding.idem, dark]) {
        final guided = appTheme(branding).extension<BrandTheme>()!.guided!;
        for (final color in [guided.heroAccent, guided.heroEyebrow, guided.stepLabelOnDark]) {
          expect(_contrast(color, guided.header), greaterThanOrEqualTo(3), reason: branding.name);
        }
      }
    });

    test('Idem\'s own buttons stand apart from its header and text', () {
      final guided = appTheme().extension<BrandTheme>()!.guided!;
      expect(_contrast(guided.action, guided.header), greaterThanOrEqualTo(1.5));
      expect(guided.action, isNot(guided.ink));
      expect(guided.heroButtonStyle, same(guided.primaryButtonStyle));
    });

    test('Idem has its own type and button shape; a tenant keeps the design\'s', () {
      final idem = appTheme().extension<BrandTheme>()!.guided!;
      expect(idem.headingFontFamily, isNull);
      expect(idem.primaryButtonStyle.shape?.resolve({}), isA<RoundedRectangleBorder>());

      const tenant = AppBranding(name: 'Acme', primary: Color(0xFF036BD2), secondary: Color(0xFF5412C7));
      final guided = appTheme(tenant).extension<BrandTheme>()!.guided!;
      expect(guided.headingFontFamily, AppFonts.heading);
      expect(guided.primaryButtonStyle.shape?.resolve({}), isA<StadiumBorder>());
    });

    test('a primary as dark as the header gets a white hero button', () {
      const branding = AppBranding(name: 'Dark', primary: Color(0xFF101E1E), secondary: Color(0xFF52525B));
      final guided = appTheme(branding).extension<BrandTheme>()!.guided!;
      expect(guided.heroButtonStyle.backgroundColor?.resolve({}), Colors.white);
      expect(guided.heroButtonStyle.foregroundColor?.resolve({}), guided.ink);
    });

    test('takes its colours from the branding', () {
      const branding = AppBranding(name: 'Acme', primary: Color(0xFF036BD2), secondary: Color(0xFF5412C7));
      final guided = appTheme(branding).extension<BrandTheme>()!.guided!;
      expect(guided.action, branding.primary);
      expect(guided.stepLabel, branding.secondary);
    });

    test('every font declared in pubspec.yaml is in the repo', () {
      final declared = RegExp(
        r'asset: (assets/fonts/\S+\.ttf)',
      ).allMatches(File('pubspec.yaml').readAsStringSync()).map((m) => m.group(1)!).toList();
      expect(declared, isNotEmpty);
      for (final path in declared) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('the default colours meet WCAG AA contrast on their backgrounds', () {
      final guided = appTheme().extension<BrandTheme>()!.guided!;
      expect(_contrast(guided.action, Colors.white), greaterThanOrEqualTo(4.5));
      expect(_contrast(guided.stepLabel, guided.badgeBackground), greaterThanOrEqualTo(4.5));
      expect(_contrast(AppColors.ink, AppColors.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(AppColors.bodyText, Colors.white), greaterThanOrEqualTo(4.5));
    });
  });

  group('home screen branding', () {
    testWidgets('without a logo shows the name as a wordmark and no attribution', (tester) async {
      await tester.pumpWidget(_home(appTheme()));
      await tester.pump();
      expect(find.text('Idem'), findsOneWidget);
      expect(find.text('Powered by Idem'), findsNothing);
    });

    testWidgets('with a logo shows the logo instead of the name', (tester) async {
      final png = img.encodePng(img.Image(width: 2, height: 2));
      final branding = AppBranding(
        name: 'Acme',
        primary: AppBranding.idem.primary,
        secondary: AppBranding.idem.secondary,
        logo: MemoryImage(png),
      );
      await tester.pumpWidget(_home(appTheme(branding)));
      await tester.pump();
      expect(find.bySemanticsLabel('Acme'), findsOneWidget);
      expect(find.text('Acme'), findsNothing);
    });
  });
}
