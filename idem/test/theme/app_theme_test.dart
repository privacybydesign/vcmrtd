import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:idem/l10n/l10n.dart';
import 'package:idem/services/proofing_session_client.dart';
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

    test('takes its colours from the branding', () {
      const branding = AppBranding(name: 'Acme', primary: Color(0xFF036BD2), secondary: Color(0xFF5412C7));
      final guided = appTheme(branding).extension<BrandTheme>()!.guided!;
      expect(guided.action, branding.primary);
      expect(guided.stepLabel, branding.secondary);
    });

    test('a session\'s branding dresses the whole app, keeping the design\'s own for what it leaves out', () {
      final branding = AppBranding.fromSession(
        const ProofingBranding(
          name: 'CM.com',
          primaryColor: '#036BD2',
          secondaryColor: '#5412C7',
          textColor: '#101E1E',
          surfaceColor: '#FBFBFC',
          headerColor: '#13156A',
          errorColor: '#B00020',
          fontFamily: '"Alexandria", system-ui, sans-serif',
        ),
      );
      final theme = appTheme(branding);
      final brand = theme.extension<BrandTheme>()!;
      final guided = brand.guided!;
      expect(brand.name, 'CM.com');
      expect(theme.colorScheme.primary, const Color(0xFF036BD2));
      expect(guided.stepLabel, const Color(0xFF5412C7));
      expect(guided.ink, const Color(0xFF101E1E));
      expect(guided.surface, const Color(0xFFFBFBFC));
      expect(guided.header, const Color(0xFF13156A));
      expect(guided.error, const Color(0xFFB00020));
      expect(guided.success, AppColors.success);
      expect(guided.headingFontFamily, 'Alexandria');
      expect(theme.textTheme.bodyMedium!.fontFamily, 'Alexandria');
    });

    test('a header too light for white text keeps the design\'s dark one', () {
      final branding = AppBranding.fromSession(const ProofingBranding(name: 'Acme', headerColor: '#F5F5F5'));
      expect(appTheme(branding).extension<BrandTheme>()!.guided!.header, AppColors.ink);
    });

    test('a light primary colour gets dark text on its buttons', () {
      final theme = appTheme(AppBranding.fromSession(const ProofingBranding(name: 'Acme', primaryColor: '#FFD500')));
      expect(theme.colorScheme.onPrimary, AppColors.ink);
    });

    test('a theme font the app does not bundle falls back to the platform\'s; none keeps the design\'s', () {
      expect(AppFont.fromCss('Georgia, "Times New Roman", serif'), AppFont.platform);
      expect(AppFont.fromCss(''), AppFont.design);
      expect(AppFont.fromCss(null), AppFont.design);
      expect(AppFont.fromCss("'Alexandria', sans-serif").heading, 'Alexandria');
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
