#!/usr/bin/env dart

// Spacing Analysis Script for DMRTD Flutter App
// Extracts and categorizes all spacing values for consistency validation

import 'dart:io';
import 'dart:convert';

void main() async {
  print('🔍 DMRTD Spacing Analysis - Consistency Validation');
  print('=' * 60);
  
  final spacingData = <String, Map<String, dynamic>>{};
  
  // Define spacing categories
  final categories = {
    'SizedBox.height': <double>[],
    'SizedBox.width': <double>[],
    'EdgeInsets.all': <double>[],
    'EdgeInsets.symmetric.horizontal': <double>[],
    'EdgeInsets.symmetric.vertical': <double>[],
    'EdgeInsets.only': <Map<String, double>>[],
    'Container.width': <double>[],
    'Container.height': <double>[],
    'Container.margin': <String>[],
    'Container.padding': <String>[],
    'BorderRadius': <double>[],
    'fontSize': <double>[],
    'iconSize': <double>[],
  };
  
  // Scan all Dart files in example/lib
  final directory = Directory('example/lib');
  if (!directory.existsSync()) {
    print('❌ Directory example/lib not found');
    return;
  }
  
  await for (final file in directory.list(recursive: true)) {
    if (file.path.endsWith('.dart')) {
      await analyzeFile(file as File, categories);
    }
  }
  
  // Generate comprehensive report
  generateSpacingReport(categories);
  generateSpacingTokens(categories);
}

Future<void> analyzeFile(File file, Map<String, dynamic> categories) async {
  final content = await file.readAsString();
  final lines = content.split('\n');
  
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    
    // SizedBox patterns
    final sizedBoxHeight = RegExp(r'SizedBox\(height:\s*([\d.]+)');
    final sizedBoxWidth = RegExp(r'SizedBox\(width:\s*([\d.]+)');
    
    // EdgeInsets patterns
    final edgeInsetsAll = RegExp(r'EdgeInsets\.all\(([\d.]+)');
    final edgeInsetsSymH = RegExp(r'EdgeInsets\.symmetric\(horizontal:\s*([\d.]+)');
    final edgeInsetsSymV = RegExp(r'EdgeInsets\.symmetric\(vertical:\s*([\d.]+)');
    
    // Container patterns
    final containerWidth = RegExp(r'width:\s*([\d.]+)');
    final containerHeight = RegExp(r'height:\s*([\d.]+)');
    
    // BorderRadius patterns
    final borderRadius = RegExp(r'BorderRadius\.circular\(([\d.]+)');
    
    // Font size patterns
    final fontSize = RegExp(r'fontSize:\s*([\d.]+)');
    
    // Icon size patterns
    final iconSize = RegExp(r'size:\s*([\d.]+)');
    
    // Extract values
    extractValue(sizedBoxHeight, line, categories['SizedBox.height']);
    extractValue(sizedBoxWidth, line, categories['SizedBox.width']);
    extractValue(edgeInsetsAll, line, categories['EdgeInsets.all']);
    extractValue(edgeInsetsSymH, line, categories['EdgeInsets.symmetric.horizontal']);
    extractValue(edgeInsetsSymV, line, categories['EdgeInsets.symmetric.vertical']);
    extractValue(containerWidth, line, categories['Container.width']);
    extractValue(containerHeight, line, categories['Container.height']);
    extractValue(borderRadius, line, categories['BorderRadius']);
    extractValue(fontSize, line, categories['fontSize']);
    extractValue(iconSize, line, categories['iconSize']);
  }
}

void extractValue(RegExp pattern, String line, List<double> list) {
  final match = pattern.firstMatch(line);
  if (match != null) {
    final value = double.tryParse(match.group(1)!);
    if (value != null && !list.contains(value)) {
      list.add(value);
    }
  }
}

void generateSpacingReport(Map<String, dynamic> categories) {
  print('\n📊 SPACING PATTERN ANALYSIS');
  print('=' * 60);
  
  categories.forEach((category, values) {
    if (values is List<double> && values.isNotEmpty) {
      values.sort();
      print('\n🏷️  $category:');
      
      // Show frequency analysis
      final frequency = <double, int>{};
      values.forEach((v) => frequency[v] = (frequency[v] ?? 0) + 1);
      
      final sortedByFreq = frequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      print('   Most frequent values:');
      sortedByFreq.take(5).forEach((entry) {
        print('   • ${entry.key} (used ${entry.value} times)');
      });
      
      print('   All values: ${values.join(', ')}');
    }
  });
}

void generateSpacingTokens(Map<String, dynamic> categories) {
  print('\n🎨 RECOMMENDED SPACING TOKENS');
  print('=' * 60);
  
  // Analyze all numeric values
  final allValues = <double>[];
  categories.forEach((category, values) {
    if (values is List<double>) {
      allValues.addAll(values);
    }
  });
  
  final uniqueValues = allValues.toSet().toList()..sort();
  
  print('\n📏 Current spacing values in use:');
  print(uniqueValues.join(', '));
  
  // Generate recommended spacing scale
  print('\n✨ RECOMMENDED SPACING SYSTEM:');
  print('''
// Base spacing unit: 4px
class AppSpacing {
  // Micro spacing (for fine adjustments)
  static const double xs = 2.0;   // replaces: 2
  static const double xxs = 4.0;  // replaces: 4
  
  // Primary spacing scale (8px base)
  static const double sm = 8.0;   // replaces: 8
  static const double md = 12.0;  // replaces: 12
  static const double lg = 16.0;  // replaces: 16
  static const double xl = 20.0;  // replaces: 20
  static const double xxl = 24.0; // replaces: 24
  
  // Component spacing
  static const double componentPadding = 16.0;  // replaces: 16, 18
  static const double screenPadding = 24.0;     // replaces: 24
  static const double sectionSpacing = 32.0;    // replaces: 32
  
  // Semantic spacing
  static const double itemSpacing = 8.0;        // between list items
  static const double groupSpacing = 16.0;      // between groups
  static const double pageSpacing = 24.0;       // page margins
  static const double sectionGap = 32.0;        // major section gaps
}

// Border radius tokens
class AppRadius {
  static const double sm = 4.0;    // small elements
  static const double md = 8.0;    // cards, buttons
  static const double lg = 12.0;   // containers
  static const double xl = 16.0;   // special cases
  static const double circular = 999.0; // fully rounded
}

// Typography spacing
class AppFontSize {
  static const double xs = 12.0;   // captions
  static const double sm = 14.0;   // body small
  static const double md = 16.0;   // body
  static const double lg = 18.0;   // subheadings
  static const double xl = 20.0;   // headings
  static const double xxl = 24.0;  // large headings
}
''');

  print('\n🔄 MIGRATION MAPPING:');
  print('Current values → Recommended tokens:');
  
  final migrationMap = {
    2.0: 'AppSpacing.xs',
    4.0: 'AppSpacing.xxs', 
    6.0: 'AppSpacing.sm (8.0)', // round up
    8.0: 'AppSpacing.sm',
    12.0: 'AppSpacing.md',
    14.0: 'AppFontSize.sm',
    16.0: 'AppSpacing.lg',
    18.0: 'AppSpacing.lg (16.0)', // round down
    20.0: 'AppSpacing.xl',
    24.0: 'AppSpacing.xxl',
    28.0: 'AppSpacing.xxl (24.0)', // round down
    32.0: 'AppSpacing.sectionSpacing',
  };
  
  uniqueValues.forEach((value) {
    final recommendation = migrationMap[value] ?? 'Custom: $value';
    print('• $value → $recommendation');
  });
  
  print('\n📈 CONSISTENCY BENEFITS:');
  print('• Reduces from ${uniqueValues.length} unique values to 12 standardized tokens');
  print('• Improves visual consistency across the app');
  print('• Makes responsive design easier to implement');
  print('• Simplifies maintenance and updates');
  print('• Aligns with Material Design spacing principles');
}