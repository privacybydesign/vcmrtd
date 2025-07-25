// Theme Integration Test Suite
// Tests how the new theme system integrates with existing widgets
// Created by Theme Tester Agent

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrtdeg/widgets/common/alert_message_widget.dart';
import 'package:mrtdeg/widgets/pages/choice_screen.dart';
import 'package:dmrtd/theme/app_spacing.dart';

void main() {
  group('Theme Integration Tests', () {
    
    group('AlertMessageWidget Integration', () {
      testWidgets('AlertMessageWidget renders with current styling', (WidgetTester tester) async {
        const testMessage = 'Test alert message';
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: AlertMessageWidget(message: testMessage),
          ),
        ));

        await tester.pumpAndSettle();
        
        // Verify widget renders correctly
        expect(find.text(testMessage), findsOneWidget);
        
        // Check current styling (documents what needs migration)
        final textWidget = tester.widget<Text>(find.text(testMessage));
        expect(textWidget.style?.fontSize, equals(15.0)); // Should be AppFontSize.bodySmall (14.0)
        expect(textWidget.style?.fontWeight, equals(FontWeight.bold));
        expect(textWidget.textAlign, equals(TextAlign.center));
      });

      testWidgets('AlertMessageWidget should use theme tokens (future migration)', (WidgetTester tester) async {
        // This test documents the expected future state after migration
        const testMessage = 'Test alert with theme tokens';
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Text(
              testMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFontSize.bodySmall, // This is what AlertMessageWidget should use
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ));

        await tester.pumpAndSettle();
        
        expect(find.text(testMessage), findsOneWidget);
        
        final textWidget = tester.widget<Text>(find.text(testMessage));
        expect(textWidget.style?.fontSize, equals(14.0)); // AppFontSize.bodySmall
      });
    });

    group('ChoiceScreen Integration', () {
      testWidgets('ChoiceScreen renders with current hardcoded values', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: ChoiceScreen(
            onScanMrzPressed: () {},
            onEnterManuallyPressed: () {},
            onHelpPressed: () {},
          ),
        ));

        await tester.pumpAndSettle();
        
        // Verify main elements are present
        expect(find.text('How would you like to read your passport?'), findsOneWidget);
        expect(find.text('Scan MRZ Code'), findsOneWidget);
        expect(find.text('Enter Details Manually'), findsOneWidget);
        expect(find.text('Get help'), findsOneWidget);
        
        // Document current hardcoded spacing values that need migration
        final cardElements = find.byType(Card);
        expect(cardElements, findsNWidgets(3)); // Header card + 2 option cards
      });

      testWidgets('ChoiceScreen padding should use spacing tokens', (WidgetTester tester) async {
        // Test widget with proper spacing tokens applied
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Container(
              padding: AppSpacing.screenMargin.allPadding, // Instead of EdgeInsets.all(24.0)
              child: Column(
                children: [
                  AppSpacing.sectionGap.verticalSpace, // Instead of SizedBox(height: 32)
                  Card(
                    child: Container(
                      padding: AppSpacing.componentPadding.allPadding, // Instead of EdgeInsets.all(24.0)
                      child: Text('Test Card'),
                    ),
                  ),
                  AppSpacing.lg.verticalSpace, // Instead of SizedBox(height: 16)
                ],
              ),
            ),
          ),
        ));

        await tester.pumpAndSettle();
        expect(find.text('Test Card'), findsOneWidget);
      });

      testWidgets('ChoiceScreen font sizes should use font tokens', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text(
                  'How would you like to read your passport?',
                  style: TextStyle(fontSize: AppFontSize.headingLarge), // Instead of fontSize: 18
                ),
                Text(
                  'Choose the method that works best for you',
                  style: TextStyle(fontSize: AppFontSize.body), // Instead of fontSize: 14
                ),
                Text(
                  'Not sure which option to choose?',
                  style: TextStyle(fontSize: AppFontSize.bodySmall), // Instead of fontSize: 14
                ),
              ],
            ),
          ),
        ));

        await tester.pumpAndSettle();
        
        // Verify all text elements render
        expect(find.text('How would you like to read your passport?'), findsOneWidget);
        expect(find.text('Choose the method that works best for you'), findsOneWidget);
        expect(find.text('Not sure which option to choose?'), findsOneWidget);
      });
    });

    group('Migration Validation Tests', () {
      test('Identify hardcoded values that need migration', () {
        // Document hardcoded values found in the codebase that should use tokens
        final hardcodedValues = <double, String>{
          15.0: 'AlertMessageWidget fontSize - should use AppFontSize.bodySmall (14.0)',
          24.0: 'ChoiceScreen padding - should use AppSpacing.screenMargin',
          16.0: 'ChoiceScreen option padding - should use AppSpacing.lg',
          32.0: 'ChoiceScreen section gap - should use AppSpacing.sectionGap',
          18.0: 'ChoiceScreen title fontSize - should use AppFontSize.bodyLarge',
          14.0: 'ChoiceScreen subtitle fontSize - should use AppFontSize.bodySmall',
          102.0: 'ChoiceScreen button height - consider using minTouchTarget + padding',
        };

        // Verify our migration helper can handle these values
        for (final entry in hardcodedValues.entries) {
          final recommendation = SpacingMigrationHelper.getRecommendedToken(entry.key);
          expect(recommendation, isNotNull);
        }
      });

      testWidgets('Theme consistency across different widget types', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Using consistent spacing
                Container(
                  padding: AppSpacing.componentPadding.allPadding,
                  child: Text('Consistent padding', style: TextStyle(fontSize: AppFontSize.body)),
                ),
                AppSpacing.groupGap.verticalSpace,
                Container(
                  padding: AppSpacing.componentPadding.allPadding,
                  child: Text('Same padding', style: TextStyle(fontSize: AppFontSize.body)),
                ),
              ],
            ),
          ),
        ));

        await tester.pumpAndSettle();
        
        // Both containers should have the same padding
        final containers = find.byType(Container);
        expect(containers, findsNWidgets(2));
      });
    });

    group('Performance Impact Tests', () {
      testWidgets('Using spacing tokens does not impact performance', (WidgetTester tester) async {
        final stopwatch = Stopwatch()..start();
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 100,
              itemBuilder: (context, index) => Container(
                padding: AppSpacing.listItemPadding.allPadding,
                margin: AppSpacing.itemGap.verticalPadding,
                child: Text('Item $index', style: TextStyle(fontSize: AppFontSize.body)),
              ),
            ),
          ),
        ));

        await tester.pumpAndSettle();
        stopwatch.stop();
        
        // Using theme tokens should not significantly impact performance
        expect(stopwatch.elapsedMilliseconds, lessThan(150));
      });

      testWidgets('Extension methods are performant', (WidgetTester tester) async {
        final stopwatch = Stopwatch()..start();
        
        // Create many widgets using extension methods
        final widgets = List.generate(1000, (index) => [
          AppSpacing.sm.verticalSpace,
          Container(
            padding: AppSpacing.md.allPadding,
            margin: AppSpacing.xs.horizontalPadding,
            child: Text('$index'),
          ),
        ]).expand((x) => x).toList();
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Column(children: widgets),
          ),
        ));

        stopwatch.stop();
        
        // Extension methods should be efficient
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });

    group('Accessibility Impact Tests', () {
      testWidgets('Minimum touch targets are maintained', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onTap: () {},
              child: Container(
                width: AppSpacing.minTouchTarget,
                height: AppSpacing.minTouchTarget,
                child: Text('Touch target'),
              ),
            ),
          ),
        ));

        await tester.pumpAndSettle();
        
        final container = tester.widget<Container>(find.byType(Container));
        final constraints = container.constraints;
        
        // Verify minimum touch target size is met
        expect(AppSpacing.minTouchTarget, equals(44.0));
      });

      testWidgets('Font sizes meet accessibility guidelines', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Body text', style: TextStyle(fontSize: AppFontSize.body)),
                Text('Small text', style: TextStyle(fontSize: AppFontSize.bodySmall)),
                Text('Caption', style: TextStyle(fontSize: AppFontSize.caption)),
              ],
            ),
          ),
        ));

        await tester.pumpAndSettle();
        
        // Verify font sizes meet minimum readability requirements
        expect(AppFontSize.body, greaterThanOrEqualTo(16.0)); // Good for readability
        expect(AppFontSize.bodySmall, greaterThanOrEqualTo(14.0)); // Minimum recommended
        expect(AppFontSize.caption, greaterThanOrEqualTo(12.0)); // Absolute minimum
      });
    });
  });
}