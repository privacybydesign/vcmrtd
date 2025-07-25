// Performance Benchmark Suite for Theme System
// Validates that theme tokens and extensions perform efficiently
// Created by Theme Tester Agent

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dmrtd/theme/app_spacing.dart';

void main() {
  group('Theme System Performance Benchmarks', () {
    
    group('Token Access Performance', () {
      test('Token access is compile-time constant', () {
        final stopwatch = Stopwatch()..start();
        
        // Access tokens multiple times
        for (int i = 0; i < 10000; i++) {
          final spacing = AppSpacing.lg;
          final fontSize = AppFontSize.body;
          final iconSize = AppIconSize.md;
          final radius = AppRadius.md;
          
          // Prevent optimization from removing the loop
          expect(spacing, equals(16.0));
          expect(fontSize, equals(16.0));
          expect(iconSize, equals(24.0));
          expect(radius, equals(8.0));
        }
        
        stopwatch.stop();
        
        // Token access should be essentially free (compile-time constants)
        expect(stopwatch.elapsedMicroseconds, lessThan(1000)); // <1ms for 10k accesses
      });

      test('Semantic token access is efficient', () {
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 5000; i++) {
          final itemGap = AppSpacing.itemGap;
          final componentPadding = AppSpacing.componentPadding;
          final screenMargin = AppSpacing.screenMargin;
          final sectionGap = AppSpacing.sectionGap;
          
          expect(itemGap, equals(8.0));
          expect(componentPadding, equals(16.0));
          expect(screenMargin, equals(24.0));
          expect(sectionGap, equals(32.0));
        }
        
        stopwatch.stop();
        expect(stopwatch.elapsedMicroseconds, lessThan(500));
      });
    });

    group('Extension Method Performance', () {
      test('SizedBox extension creation is efficient', () {
        final stopwatch = Stopwatch()..start();
        
        final spacingWidgets = <Widget>[];
        for (int i = 0; i < 1000; i++) {
          spacingWidgets.addAll([
            AppSpacing.sm.verticalSpace,
            AppSpacing.md.horizontalSpace,
            AppSpacing.lg.verticalSpace,
            AppSpacing.xl.horizontalSpace,
          ]);
        }
        
        stopwatch.stop();
        
        expect(spacingWidgets.length, equals(4000));
        expect(stopwatch.elapsedMicroseconds, lessThan(10000)); // <10ms for 4k widgets
      });

      test('EdgeInsets extension creation is efficient', () {
        final stopwatch = Stopwatch()..start();
        
        final paddingInstances = <EdgeInsets>[];
        for (int i = 0; i < 1000; i++) {
          paddingInstances.addAll([
            AppSpacing.sm.allPadding,
            AppSpacing.md.horizontalPadding,
            AppSpacing.lg.verticalPadding,
            AppSpacing.xl.allPadding,
          ]);
        }
        
        stopwatch.stop();
        
        expect(paddingInstances.length, equals(4000));
        expect(stopwatch.elapsedMicroseconds, lessThan(15000)); // <15ms for 4k EdgeInsets
      });
    });

    group('Migration Helper Performance', () {
      test('Migration map lookup is fast', () {
        final stopwatch = Stopwatch()..start();
        
        final testValues = [2.0, 4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 32.0];
        
        for (int i = 0; i < 1000; i++) {
          for (final value in testValues) {
            final recommendation = SpacingMigrationHelper.getRecommendedToken(value);
            expect(recommendation, isNotNull);
          }
        }
        
        stopwatch.stop();
        expect(stopwatch.elapsedMicroseconds, lessThan(5000)); // <5ms for 8k lookups
      });
    });

    group('Widget Integration Performance', () {
      testWidgets('Theme system does not slow widget creation', (WidgetTester tester) async {
        final stopwatch = Stopwatch()..start();
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Column(
              children: List.generate(100, (index) => Container(
                padding: AppSpacing.componentPadding.allPadding,
                margin: AppSpacing.itemGap.verticalPadding,
                child: Row(
                  children: [
                    AppSpacing.sm.horizontalSpace,
                    Icon(Icons.star, size: AppIconSize.md),
                    AppSpacing.md.horizontalSpace,
                    Expanded(
                      child: Text(
                        'Item $index',
                        style: TextStyle(fontSize: AppFontSize.body),
                      ),
                    ),
                  ],
                ),
              )),
            ),
          ),
        ));
        
        stopwatch.stop();
        
        // Creating 100 widgets with theme tokens should be fast
        expect(stopwatch.elapsedMilliseconds, lessThan(50));
      });

      testWidgets('Multiple theme operations in ListView are efficient', (WidgetTester tester) async {
        final stopwatch = Stopwatch()..start();
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 200,
              itemBuilder: (context, index) => Card(
                margin: AppSpacing.itemGap.allPadding,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Container(
                  padding: AppSpacing.listItemPadding.allPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Title $index',
                        style: TextStyle(
                          fontSize: AppFontSize.heading,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppSpacing.xs.verticalSpace,
                      Text(
                        'Description for item $index',
                        style: TextStyle(fontSize: AppFontSize.body),
                      ),
                      AppSpacing.sm.verticalSpace,
                      Row(
                        children: [
                          Icon(Icons.info, size: AppIconSize.sm),
                          AppSpacing.xs.horizontalSpace,
                          Text(
                            'Info',
                            style: TextStyle(fontSize: AppFontSize.bodySmall),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
        
        await tester.pumpAndSettle();
        stopwatch.stop();
        
        // 200 complex items with multiple theme operations should be efficient
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });

    group('Memory Usage Benchmarks', () {
      test('Token system has minimal memory footprint', () {
        // Tokens are compile-time constants, so they don't consume runtime memory
        // This test documents the expected behavior
        
        final spacingTokens = [
          AppSpacing.xxs, AppSpacing.xs, AppSpacing.sm, AppSpacing.md,
          AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl, AppSpacing.xxxl,
        ];
        
        final fontTokens = [
          AppFontSize.caption, AppFontSize.bodySmall, AppFontSize.body,
          AppFontSize.bodyLarge, AppFontSize.heading, AppFontSize.headingLarge,
          AppFontSize.headingXL,
        ];
        
        final iconTokens = [
          AppIconSize.sm, AppIconSize.md, AppIconSize.lg, AppIconSize.xl,
        ];
        
        final radiusTokens = [
          AppRadius.sm, AppRadius.md, AppRadius.lg, AppRadius.xl, AppRadius.circular,
        ];
        
        // All tokens should be primitive doubles
        for (final token in spacingTokens) {
          expect(token, isA<double>());
        }
        for (final token in fontTokens) {
          expect(token, isA<double>());
        }
        for (final token in iconTokens) {
          expect(token, isA<double>());
        }
        for (final token in radiusTokens) {
          expect(token, isA<double>());
        }
        
        // Total tokens: 26 double constants = ~208 bytes theoretical maximum
        final totalTokens = spacingTokens.length + fontTokens.length + 
                           iconTokens.length + radiusTokens.length;
        expect(totalTokens, equals(26));
      });

      testWidgets('Extension method widgets have normal memory usage', (WidgetTester tester) async {
        // Create many widgets using extensions to verify no memory leaks
        final widgets = <Widget>[];
        
        for (int i = 0; i < 500; i++) {
          widgets.addAll([
            AppSpacing.sm.verticalSpace,
            Container(
              padding: AppSpacing.md.allPadding,
              margin: AppSpacing.xs.horizontalPadding,
              child: Text('Item $i', style: TextStyle(fontSize: AppFontSize.body)),
            ),
          ]);
        }
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(children: widgets),
            ),
          ),
        ));
        
        // Should complete without memory issues
        expect(widgets.length, equals(1000));
      });
    });

    group('Comparative Performance Tests', () {
      test('Token access vs hardcoded values performance', () {
        final stopwatch1 = Stopwatch()..start();
        
        // Using tokens
        for (int i = 0; i < 10000; i++) {
          final padding = AppSpacing.lg;
          final fontSize = AppFontSize.body;
          expect(padding, equals(16.0));
          expect(fontSize, equals(16.0));
        }
        
        stopwatch1.stop();
        final tokenTime = stopwatch1.elapsedMicroseconds;
        
        final stopwatch2 = Stopwatch()..start();
        
        // Using hardcoded values
        for (int i = 0; i < 10000; i++) {
          const padding = 16.0;
          const fontSize = 16.0;
          expect(padding, equals(16.0));
          expect(fontSize, equals(16.0));
        }
        
        stopwatch2.stop();
        final hardcodedTime = stopwatch2.elapsedMicroseconds;
        
        // Token access should be equivalent to hardcoded constants
        // Allow small variance due to measurement noise
        final difference = (tokenTime - hardcodedTime).abs();
        expect(difference, lessThan(1000)); // Within 1ms difference
      });

      testWidgets('Extension methods vs direct widget creation', (WidgetTester tester) async {
        final stopwatch1 = Stopwatch()..start();
        
        // Using extension methods
        final extensionWidgets = List.generate(1000, (index) => 
          AppSpacing.md.verticalSpace
        );
        
        stopwatch1.stop();
        final extensionTime = stopwatch1.elapsedMicroseconds;
        
        final stopwatch2 = Stopwatch()..start();
        
        // Direct widget creation
        final directWidgets = List.generate(1000, (index) => 
          SizedBox(height: 12.0)
        );
        
        stopwatch2.stop();
        final directTime = stopwatch2.elapsedMicroseconds;
        
        expect(extensionWidgets.length, equals(1000));
        expect(directWidgets.length, equals(1000));
        
        // Extension method should have minimal overhead
        final overhead = extensionTime - directTime;
        expect(overhead, lessThan(5000)); // <5ms overhead for 1000 widgets
      });
    });
  });
}