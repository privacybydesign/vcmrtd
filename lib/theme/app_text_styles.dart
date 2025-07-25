// Created by Theme Architect Agent - Comprehensive Text Style System
// Replaces and extends existing text style implementations

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Comprehensive text style system for the DMRTD application.
/// Provides semantic text styles that replace hardcoded typography
/// throughout the codebase for better design consistency.
class AppTextStyles {
  AppTextStyles._(); // Private constructor to prevent instantiation

  // DISPLAY STYLES (Largest text - heroes, titles)
  /// Extra large display text for hero sections
  /// Use for: App titles, hero text, splash screens
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32.0,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );

  /// Large display text for major headings
  /// Use for: Page titles, major section headers
  static const TextStyle displayMedium = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.25,
  );

  /// Small display text for section titles
  /// Replaces: fontSize: 24, existing primaryLarge style
  /// Use for: Section titles, card headers
  static const TextStyle displaySmall = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // HEADLINE STYLES (Medium importance text)
  /// Large headline for important information
  /// Use for: Dialog titles, important announcements
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  /// Medium headline for subsection headers
  /// Use for: Form section headers, content group titles
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  /// Small headline for minor headers
  /// Replaces: fontSize: 18 instances
  /// Use for: List headers, minor section titles
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // TITLE STYLES (Component-level titles)
  /// Large title for prominent components
  /// Use for: Card titles, major component headers
  static const TextStyle titleLarge = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  /// Medium title for standard components
  /// Use for: Button text, tab labels, list item titles
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// Small title for compact components
  /// Use for: Chip labels, small button text
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // BODY STYLES (Main content text)
  /// Large body text for important content
  /// Use for: Important paragraphs, emphasized content
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// Medium body text for standard content
  /// Replaces: fontSize: 16 instances, existing secondary style
  /// Use for: Main content, form inputs, general text
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// Small body text for supporting content
  /// Replaces: fontSize: 14 instances
  /// Use for: Supporting text, descriptions, metadata
  static const TextStyle bodySmall = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // LABEL STYLES (UI element labels)
  /// Large label for prominent form elements
  /// Use for: Form field labels, important UI labels
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.4,
    letterSpacing: 0.1,
  );

  /// Medium label for standard UI elements
  /// Use for: Button labels, tab text, standard labels
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: 0.5,
  );

  /// Small label for compact UI elements
  /// Use for: Badges, chips, compact labels
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11.0,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.3,
    letterSpacing: 0.5,
  );

  // SEMANTIC STYLES (Purpose-specific variants)
  /// Error text style for error messages
  /// Replaces: existing error style, Colors.redAccent
  /// Use for: Form validation errors, error messages
  static const TextStyle error = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    color: AppColors.error,
    height: 1.4,
  );

  /// Success text style for positive feedback
  /// Use for: Success messages, confirmation text
  static const TextStyle success = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    color: AppColors.success,
    height: 1.4,
  );

  /// Warning text style for caution messages
  /// Use for: Warning messages, important notices
  static const TextStyle warning = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    color: AppColors.warning,
    height: 1.4,
  );

  /// Hint text style for placeholders and guides
  /// Replaces: existing hint style, Color(0xFF666666)
  /// Use for: Input placeholders, helper text, guides
  static const TextStyle hint = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
    height: 1.5,
  );

  /// Link text style for interactive text
  /// Use for: Hyperlinks, clickable text
  static const TextStyle link = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    color: AppColors.secondary,
    height: 1.5,
    decoration: TextDecoration.underline,
  );

  /// Caption text style for very small supporting text
  /// Replaces: fontSize: 12 instances
  /// Use for: Image captions, fine print, timestamps
  static const TextStyle caption = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  // PLATFORM-SPECIFIC STYLES
  /// iOS-style navigation title
  static const TextStyle iosNavigationTitle = TextStyle(
    fontSize: 17.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Material design app bar title
  static const TextStyle materialAppBarTitle = TextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  // BUTTON STYLES (Component-specific text styles)
  /// Primary button text style
  /// Use for: Primary action buttons
  static const TextStyle buttonPrimary = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    height: 1.25,
    letterSpacing: 0.25,
  );

  /// Secondary button text style
  /// Use for: Secondary action buttons
  static const TextStyle buttonSecondary = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
    height: 1.25,
    letterSpacing: 0.25,
  );

  /// Text button style
  /// Use for: Text-only buttons, links as buttons
  static const TextStyle buttonText = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    color: AppColors.secondary,
    height: 1.25,
    letterSpacing: 0.25,
  );
}

/// Comprehensive text theme for Material Design integration
class AppTextTheme {
  static const TextTheme lightTextTheme = TextTheme(
    displayLarge: AppTextStyles.displayLarge,
    displayMedium: AppTextStyles.displayMedium,
    displaySmall: AppTextStyles.displaySmall,
    headlineLarge: AppTextStyles.headlineLarge,
    headlineMedium: AppTextStyles.headlineMedium,
    headlineSmall: AppTextStyles.headlineSmall,
    titleLarge: AppTextStyles.titleLarge,
    titleMedium: AppTextStyles.titleMedium,
    titleSmall: AppTextStyles.titleSmall,
    bodyLarge: AppTextStyles.bodyLarge,
    bodyMedium: AppTextStyles.bodyMedium,
    bodySmall: AppTextStyles.bodySmall,
    labelLarge: AppTextStyles.labelLarge,
    labelMedium: AppTextStyles.labelMedium,
    labelSmall: AppTextStyles.labelSmall,
  );

  /// Dark theme text theme (future expansion)
  static TextTheme get darkTextTheme => lightTextTheme.apply(
    bodyColor: Colors.white,
    displayColor: Colors.white,
  );
}

/// Legacy compatibility - maintains existing MyTextStyles interface
/// This allows gradual migration from the old system
@immutable
class MyTextStyles {
  final TextStyle primaryLarge;
  final TextStyle secondary;
  final TextStyle hint;
  final TextStyle error;

  const MyTextStyles({
    required this.primaryLarge,
    required this.secondary,
    required this.hint,
    required this.error,
  });
}

/// Extension to maintain backward compatibility while encouraging new system
extension MyThemeTextStyles on ThemeData {
  MyTextStyles get defaultTextStyles => const MyTextStyles(
    primaryLarge: AppTextStyles.displaySmall,  // Maps to new system
    secondary: AppTextStyles.bodyMedium,       // Maps to new system
    hint: AppTextStyles.hint,                  // Direct mapping
    error: AppTextStyles.error,                // Direct mapping
  );
}

/// Migration helper for text style values
class TextStyleMigrationHelper {
  static const Map<String, String> migrationMap = {
    'fontSize: 24': 'AppTextStyles.displaySmall',
    'fontSize: 16': 'AppTextStyles.bodyMedium',
    'fontSize: 14': 'AppTextStyles.bodySmall',
    'fontSize: 18': 'AppTextStyles.headlineSmall',
    'fontSize: 20': 'AppTextStyles.headlineMedium',
    'fontSize: 12': 'AppTextStyles.caption',
    'FontWeight.bold': 'AppTextStyles.displaySmall (or appropriate bold style)',
    'FontWeight.w600': 'AppTextStyles.titleMedium (or appropriate w600 style)',
    'Colors.grey': 'AppTextStyles.bodySmall (uses textSecondary color)',
    'Color(0xFF666666)': 'AppTextStyles.hint',
  };

  /// Get recommended text style for common patterns
  static String getRecommendedStyle(String pattern) {
    return migrationMap[pattern] ?? 'Consider appropriate semantic text style from AppTextStyles';
  }
}