import 'dart:io';

import 'package:flutter/foundation.dart';
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

/// WCAG AA contrast for normal text, and for large text and highlights.
const _aaNormalText = 4.5;
const _aaLargeText = 3.0;

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
          expect(_contrast(color, guided.header), greaterThanOrEqualTo(_aaLargeText), reason: branding.name);
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
      const branding = AppBranding(name: 'Acme', primary: Color(0xFFFFD500), secondary: Color(0xFF52525B));
      expect(appTheme(branding).colorScheme.onPrimary, AppColors.ink);
    });

    test('a session colour that doesn\'t read on its background keeps the design\'s', () {
      final branding = AppBranding.fromSession(
        const ProofingBranding(
          name: 'Acme',
          primaryColor: '#7FB2FF',
          secondaryColor: '#FFF3B0',
          errorColor: '#FFC0C0',
          textColor: '#999999',
          linkColor: '#99BBFF',
          surfaceColor: '#1A1A1A',
        ),
      );
      expect(branding.primary, AppBranding.idem.primary);
      expect(branding.secondary, AppBranding.idem.secondary);
      expect(branding.error, isNull);
      expect(branding.text, isNull);
      expect(branding.link, isNull);
      expect(branding.surface, isNull);
    });

    test('a session\'s colours stay when they read on each other', () {
      final branding = AppBranding.fromSession(
        const ProofingBranding(name: 'Acme', textColor: '#101E1E', surfaceColor: '#F0F4F8', linkColor: '#0A58CA'),
      );
      expect(branding.text, const Color(0xFF101E1E));
      expect(branding.surface, const Color(0xFFF0F4F8));
      expect(branding.link, const Color(0xFF0A58CA));
    });

    test('every font the businesswallet offers is drawn as that font', () {
      // Its theme font options (frontend/src/lib/theme.ts's FONT_OPTIONS).
      expect(AppFont.fromCss('"Montserrat", system-ui, sans-serif').heading, 'Montserrat');
      expect(AppFont.fromCss('"Nunito", system-ui, sans-serif').heading, 'Nunito');
      expect(AppFont.fromCss('"Open Sans", system-ui, sans-serif').heading, 'Open Sans');
      expect(AppFont.fromCss('"Alexandria", system-ui, sans-serif').heading, 'Alexandria');
      expect(AppFont.fromCss('system-ui, -apple-system, "Segoe UI", Roboto, sans-serif'), AppFont.platform);
      expect(AppFont.fromCss('Georgia, "Times New Roman", serif').body, 'serif');
      expect(AppFont.fromCss('ui-monospace, SFMono-Regular, Menlo, Consolas, monospace').body, 'monospace');
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(AppFont.fromCss('Georgia, "Times New Roman", serif').body, 'Georgia');
      expect(AppFont.fromCss('"Helvetica Neue", Arial, sans-serif').body, 'Helvetica Neue');
      expect(AppFont.fromCss('ui-monospace, SFMono-Regular, Menlo, Consolas, monospace').body, 'Menlo');
      debugDefaultTargetPlatformOverride = null;
    });

    test('a theme naming no font the app knows gets the platform\'s; none keeps the design\'s', () {
      expect(AppFont.fromCss('"Comic Neue", cursive'), AppFont.platform);
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
      expect(_contrast(guided.action, Colors.white), greaterThanOrEqualTo(_aaNormalText));
      expect(_contrast(guided.stepLabel, guided.badgeBackground), greaterThanOrEqualTo(_aaNormalText));
      expect(_contrast(AppColors.ink, AppColors.surface), greaterThanOrEqualTo(_aaNormalText));
      expect(_contrast(AppColors.bodyText, Colors.white), greaterThanOrEqualTo(_aaNormalText));
      expect(_contrast(guided.muted, Colors.white), greaterThanOrEqualTo(_aaNormalText));
    });
  });

  group('home screen branding', () {
    testWidgets('without a logo shows the name as a wordmark', (tester) async {
      await tester.pumpWidget(_home(appTheme()));
      await tester.pump();
      expect(find.text('Idem'), findsOneWidget);
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
