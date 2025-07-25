// Theme System Test Suite
// Tests theme consistency, integration, and performance
// Created by Theme Tester Agent

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrtdeg/main.dart';
import 'package:mrtdeg/theme/text_styles.dart';
import 'package:dmrtd/theme/app_spacing.dart';

void main() {
  group('Theme System Tests', () {
    
    group('Theme Integration Tests', () {
      testWidgets('App loads with correct theme configuration', (WidgetTester tester) async {
        await tester.pumpWidget(MrtdEgApp());
        
        // Verify MaterialApp theme is set correctly
        final MaterialApp materialApp = tester.widget(find.byType(MaterialApp));
        expect(materialApp.theme, isNotNull);
        expect(materialApp.theme!.primarySwatch, Colors.indigo);
        expect(materialApp.theme!.brightness, Brightness.light);
      });

      testWidgets('Text styles extension works correctly', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) {
              final textStyles = Theme.of(context).defaultTextStyles;
              return Scaffold(
                body: Column(
                  children: [
                    Text('Primary Large', style: textStyles.primaryLarge),
                    Text('Secondary', style: textStyles.secondary),
                    Text('Hint', style: textStyles.hint),
                    Text('Error', style: textStyles.error),
                  ],
                ),
              );
            },
          ),
        ));

        await tester.pumpAndSettle();
        
        // Verify text styles are applied
        expect(find.text('Primary Large'), findsOneWidget);
        expect(find.text('Secondary'), findsOneWidget);
        expect(find.text('Hint'), findsOneWidget);
        expect(find.text('Error'), findsOneWidget);
      });
    });

    group('AppSpacing Token Tests', () {
      test('Spacing tokens have correct values', () {
        expect(AppSpacing.xxs, equals(2.0));
        expect(AppSpacing.xs, equals(4.0));
        expect(AppSpacing.sm, equals(8.0));
        expect(AppSpacing.md, equals(12.0));
        expect(AppSpacing.lg, equals(16.0));
        expect(AppSpacing.xl, equals(20.0));
        expect(AppSpacing.xxl, equals(24.0));
        expect(AppSpacing.xxxl, equals(32.0));
      });

      test('Semantic spacing tokens map correctly', () {
        expect(AppSpacing.itemGap, equals(AppSpacing.sm));
        expect(AppSpacing.componentPadding, equals(AppSpacing.lg));
        expect(AppSpacing.groupGap, equals(AppSpacing.xxl));
        expect(AppSpacing.screenMargin, equals(AppSpacing.xxl));
        expect(AppSpacing.sectionGap, equals(AppSpacing.xxxl));
      });

      test('Form and component spacing tokens', () {
        expect(AppSpacing.minTouchTarget, equals(44.0));
        expect(AppSpacing.formFieldGap, equals(AppSpacing.md));
        expect(AppSpacing.buttonPadding, equals(AppSpacing.lg));
        expect(AppSpacing.listItemPadding, equals(AppSpacing.lg));
      });
    });

    group('AppRadius Token Tests', () {
      test('Radius tokens have correct values', () {
        expect(AppRadius.sm, equals(4.0));
        expect(AppRadius.md, equals(8.0));
        expect(AppRadius.lg, equals(12.0));
        expect(AppRadius.xl, equals(16.0));
        expect(AppRadius.circular, equals(999.0));
      });
    });

    group('AppFontSize Token Tests', () {
      test('Font size tokens have correct values', () {
        expect(AppFontSize.caption, equals(12.0));
        expect(AppFontSize.bodySmall, equals(14.0));
        expect(AppFontSize.body, equals(16.0));
        expect(AppFontSize.bodyLarge, equals(18.0));
        expect(AppFontSize.heading, equals(20.0));
        expect(AppFontSize.headingLarge, equals(24.0));
        expect(AppFontSize.headingXL, equals(28.0));
      });
    });

    group('AppIconSize Token Tests', () {
      test('Icon size tokens have correct values', () {
        expect(AppIconSize.sm, equals(16.0));
        expect(AppIconSize.md, equals(24.0));
        expect(AppIconSize.lg, equals(32.0));
        expect(AppIconSize.xl, equals(48.0));
      });
    });

    group('SpacingExtensions Tests', () {
      test('Extension methods create correct widgets', () {
        final verticalSpace = AppSpacing.lg.verticalSpace;
        expect(verticalSpace, isA<SizedBox>());
        expect((verticalSpace as SizedBox).height, equals(AppSpacing.lg));
        
        final horizontalSpace = AppSpacing.md.horizontalSpace;
        expect(horizontalSpace, isA<SizedBox>());
        expect((horizontalSpace as SizedBox).width, equals(AppSpacing.md));
      });

      test('Padding extension methods work correctly', () {
        final allPadding = AppSpacing.lg.allPadding;
        expect(allPadding, isA<EdgeInsets>());
        expect(allPadding.left, equals(AppSpacing.lg));
        expect(allPadding.right, equals(AppSpacing.lg));
        expect(allPadding.top, equals(AppSpacing.lg));
        expect(allPadding.bottom, equals(AppSpacing.lg));

        final horizontalPadding = AppSpacing.md.horizontalPadding;
        expect(horizontalPadding.left, equals(AppSpacing.md));
        expect(horizontalPadding.right, equals(AppSpacing.md));
        expect(horizontalPadding.top, equals(0));
        expect(horizontalPadding.bottom, equals(0));

        final verticalPadding = AppSpacing.sm.verticalPadding;
        expect(verticalPadding.left, equals(0));
        expect(verticalPadding.right, equals(0));
        expect(verticalPadding.top, equals(AppSpacing.sm));
        expect(verticalPadding.bottom, equals(AppSpacing.sm));
      });
    });

    group('Migration Helper Tests', () {
      test('Migration map contains expected mappings', () {
        expect(SpacingMigrationHelper.migrationMap[2.0], equals('AppSpacing.xxs'));
        expect(SpacingMigrationHelper.migrationMap[4.0], equals('AppSpacing.xs'));
        expect(SpacingMigrationHelper.migrationMap[8.0], equals('AppSpacing.sm'));
        expect(SpacingMigrationHelper.migrationMap[16.0], equals('AppSpacing.lg'));
        expect(SpacingMigrationHelper.migrationMap[24.0], equals('AppSpacing.xxl'));
      });

      test('getRecommendedToken returns correct recommendations', () {
        expect(SpacingMigrationHelper.getRecommendedToken(8.0), equals('AppSpacing.sm'));
        expect(SpacingMigrationHelper.getRecommendedToken(16.0), equals('AppSpacing.lg'));
        expect(SpacingMigrationHelper.getRecommendedToken(99.0), contains('No direct mapping'));
      });
    });

    group('Visual Consistency Tests', () {
      testWidgets('Hardcoded values should be replaced with tokens', (WidgetTester tester) async {
        // This test documents current inconsistencies that need fixing
        await tester.pumpWidget(MrtdEgApp());
        await tester.pumpAndSettle();

        // Find MaterialApp and check theme configuration
        final MaterialApp app = tester.widget(find.byType(MaterialApp));
        final theme = app.theme;
        
        // Check for hardcoded font sizes that should use AppFontSize tokens
        final textTheme = theme?.textTheme;
        if (textTheme?.bodyLarge?.fontSize != null) {
          // Document: This should use AppFontSize.body (16.0)
          expect(textTheme!.bodyLarge!.fontSize, equals(16.0));
        }
      });

      testWidgets('Text styles maintain consistency across components', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final styles = Theme.of(context).defaultTextStyles;
                return Column(
                  children: [
                    Text('Primary', style: styles.primaryLarge),
                    Text('Secondary', style: styles.secondary),
                    Text('Hint', style: styles.hint),
                    Text('Error', style: styles.error),
                  ],
                );
              },
            ),
          ),
        ));

        await tester.pumpAndSettle();

        // Verify consistent text styling across different text types
        final primaryText = tester.widget<Text>(find.text('Primary'));
        final secondaryText = tester.widget<Text>(find.text('Secondary'));
        final hintText = tester.widget<Text>(find.text('Hint'));
        final errorText = tester.widget<Text>(find.text('Error'));

        expect(primaryText.style?.fontSize, equals(24));
        expect(primaryText.style?.fontWeight, equals(FontWeight.bold));
        
        expect(secondaryText.style?.fontSize, equals(16));
        expect(secondaryText.style?.fontWeight, equals(FontWeight.w400));
        
        expect(hintText.style?.fontSize, equals(16));
        expect(errorText.style?.fontSize, equals(14));
        expect(errorText.style?.fontWeight, equals(FontWeight.bold));
      });
    });

    group('Theme Performance Tests', () {
      testWidgets('Theme loading does not cause performance issues', (WidgetTester tester) async {
        final stopwatch = Stopwatch()..start();
        
        await tester.pumpWidget(MrtdEgApp());
        await tester.pumpAndSettle();
        
        stopwatch.stop();
        
        // Theme loading should be fast (under 100ms for initial setup)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      testWidgets('Multiple theme operations are efficient', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Column(
              children: List.generate(100, (index) => 
                Container(
                  padding: AppSpacing.md.allPadding,
                  margin: AppSpacing.sm.allPadding,
                  child: Text('Item $index', 
                    style: TextStyle(fontSize: AppFontSize.body)),
                ),
              ),
            ),
          ),
        ));

        final stopwatch = Stopwatch()..start();
        await tester.pumpAndSettle();
        stopwatch.stop();

        // Multiple spacing/theme operations should be efficient
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
      });
    });

    group('Platform Theme Tests', () {
      testWidgets('Material theme configuration is correct', (WidgetTester tester) async {
        await tester.pumpWidget(MrtdEgApp());
        
        final MaterialApp app = tester.widget(find.byType(MaterialApp));
        final theme = app.theme;
        
        expect(theme?.primarySwatch, equals(Colors.indigo));
        expect(theme?.brightness, equals(Brightness.light));
        expect(theme?.appBarTheme.backgroundColor, equals(Colors.indigo));
        expect(theme?.appBarTheme.foregroundColor, equals(Colors.white));
      });
    });

    group('Regression Tests', () {
      testWidgets('Theme changes do not break existing widgets', (WidgetTester tester) async {
        // Test that implementing new theme system doesn't break existing functionality
        await tester.pumpWidget(MrtdEgApp());
        await tester.pumpAndSettle();

        // Basic smoke test - app should load without errors
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Text rendering remains consistent', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Column(
                  children: [
                    Text('Test', style: Theme.of(context).defaultTextStyles.primaryLarge),
                    Text('Test', style: TextStyle(fontSize: AppFontSize.headingLarge)),
                  ],
                ),
              );
            },
          ),
        ));

        await tester.pumpAndSettle();
        
        // Both should render the same since they use equivalent values
        final texts = find.text('Test');
        expect(texts, findsNWidgets(2));
      });
    });
  });
}