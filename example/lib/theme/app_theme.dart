// Created by Theme Architect Agent - Comprehensive Theme System
// Centralized theme configuration for the DMRTD application

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_spacing.dart';

/// Comprehensive theme system for the DMRTD application.
/// Provides complete Material and Cupertino theme configurations
/// with consistent design tokens across all platforms.
class AppTheme {
  AppTheme._(); // Private constructor to prevent instantiation

  // MATERIAL DESIGN THEME
  /// Light theme configuration for Material Design
  static ThemeData get lightTheme => ThemeData(
    // Color scheme
    colorScheme: LightColorScheme.scheme,
    useMaterial3: true,
    
    // Typography
    textTheme: AppTextTheme.lightTextTheme,
    
    // App bar theme
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      centerTitle: true,
      titleTextStyle: AppTextStyles.materialAppBarTitle,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    
    // Card theme
    cardTheme: CardTheme(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      color: AppColors.surface,
      margin: EdgeInsets.all(AppSpacing.sm),
    ),
    
    // Elevated button theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        textStyle: AppTextStyles.buttonPrimary,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        elevation: 2,
      ),
    ),
    
    // Outlined button theme
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppTextStyles.buttonSecondary,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        side: const BorderSide(color: AppColors.primary),
      ),
    ),
    
    // Text button theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.secondary,
        textStyle: AppTextStyles.buttonText,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
      ),
    ),
    
    // Input decoration theme
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.borderFocused, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: EdgeInsets.all(AppSpacing.lg),
      labelStyle: AppTextStyles.labelLarge,
      hintStyle: AppTextStyles.hint,
      errorStyle: AppTextStyles.error,
    ),
    
    // Tab bar theme
    tabBarTheme: const TabBarTheme(
      labelColor: AppColors.secondary,
      unselectedLabelColor: AppColors.textSecondary,
      labelStyle: AppTextStyles.labelLarge,
      unselectedLabelStyle: AppTextStyles.labelMedium,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.secondary, width: 2),
      ),
    ),
    
    // List tile theme
    listTileTheme: ListTileThemeData(
      contentPadding: EdgeInsets.all(AppSpacing.listItemPadding),
      titleTextStyle: AppTextStyles.titleMedium,
      subtitleTextStyle: AppTextStyles.bodySmall,
    ),
    
    // Divider theme
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    
    // Icon theme
    iconTheme: const IconThemeData(
      color: AppColors.textPrimary,
      size: AppIconSize.md,
    ),
    
    // Dialog theme
    dialogTheme: DialogTheme(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      titleTextStyle: AppTextStyles.headlineMedium,
      contentTextStyle: AppTextStyles.bodyMedium,
    ),
    
    // Snack bar theme
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.primary,
      contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );

  /// Dark theme configuration (future expansion)
  static ThemeData get darkTheme => lightTheme.copyWith(
    colorScheme: DarkColorScheme.scheme,
    textTheme: AppTextTheme.darkTextTheme,
    appBarTheme: lightTheme.appBarTheme?.copyWith(
      backgroundColor: const Color(0xFF424242),
    ),
  );

  // CUPERTINO THEME
  /// Cupertino theme configuration for iOS-style design
  static CupertinoThemeData get cupertinoTheme => const CupertinoThemeData(
    primaryColor: AppColors.iosBlue,
    primaryContrastingColor: Colors.white,
    barBackgroundColor: AppColors.iosGray,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: CupertinoTextThemeData(
      textStyle: AppTextStyles.bodyMedium,
      navTitleTextStyle: AppTextStyles.iosNavigationTitle,
      navLargeTitleTextStyle: AppTextStyles.displayMedium,
    ),
  );

  // COMPONENT-SPECIFIC THEMES
  /// Theme configuration for form components
  static InputDecorationTheme get formTheme => InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.borderFocused, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    contentPadding: EdgeInsets.all(AppSpacing.componentPadding),
    labelStyle: AppTextStyles.labelLarge,
    hintStyle: AppTextStyles.hint,
    errorStyle: AppTextStyles.error,
    filled: true,
    fillColor: AppColors.surfaceVariant,
  );

  /// Theme configuration for card components
  static CardTheme get cardTheme => CardTheme(
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    color: AppColors.surface,
    margin: EdgeInsets.all(AppSpacing.itemGap),
    clipBehavior: Clip.antiAlias,
  );

  /// Theme configuration for buttons
  static ElevatedButtonThemeData get primaryButtonTheme => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      textStyle: AppTextStyles.buttonPrimary,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.buttonPadding,
        vertical: AppSpacing.formFieldGap,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: 2,
      minimumSize: Size(double.infinity, AppSpacing.minTouchTarget),
    ),
  );
}

/// Theme extensions for custom properties
extension ThemeExtensions on ThemeData {
  /// Get spacing values
  AppSpacing get spacing => AppSpacing();
  
  /// Get color values
  AppColors get colors => AppColors();
  
  /// Get text styles
  AppTextStyles get textStyles => AppTextStyles();
}

/// Theme mode configuration
class AppThemeMode {
  /// Get the appropriate theme mode based on system settings
  static ThemeMode get themeMode => ThemeMode.system;
  
  /// Check if dark mode is enabled
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
  
  /// Get theme-appropriate color for given context
  static Color getAdaptiveColor(BuildContext context, {
    required Color lightColor,
    required Color darkColor,
  }) {
    return isDarkMode(context) ? darkColor : lightColor;
  }
}

/// Theme configuration for specific app sections
class SectionThemes {
  /// Authentication screens theme
  static ThemeData get authTheme => AppTheme.lightTheme.copyWith(
    inputDecorationTheme: AppTheme.formTheme,
    elevatedButtonTheme: AppTheme.primaryButtonTheme,
  );
  
  /// Data display screens theme
  static ThemeData get dataTheme => AppTheme.lightTheme.copyWith(
    cardTheme: AppTheme.cardTheme,
    listTileTheme: ListTileThemeData(
      contentPadding: EdgeInsets.all(AppSpacing.listItemPadding),
      titleTextStyle: AppTextStyles.titleMedium,
      subtitleTextStyle: AppTextStyles.bodySmall,
      dense: true,
    ),
  );
  
  /// Scanner screens theme
  static ThemeData get scannerTheme => AppTheme.lightTheme.copyWith(
    appBarTheme: AppTheme.lightTheme.appBarTheme?.copyWith(
      backgroundColor: Colors.black.withOpacity(0.7),
      elevation: 0,
    ),
  );
}

/// Migration helper for theme values
class ThemeMigrationHelper {
  static const Map<String, String> migrationMap = {
    'Colors.indigo': 'AppColors.materialPrimary',
    'primarySwatch: Colors.indigo': 'colorScheme: LightColorScheme.scheme',
    'fontSize: 16.0': 'AppTextStyles.bodyMedium',
    'Colors.black87': 'AppTextStyles.bodyMedium.color',
    'EdgeInsets.all(24.0)': 'EdgeInsets.all(AppSpacing.screenMargin)',
    'BorderRadius.circular(16)': 'BorderRadius.circular(AppRadius.lg)',
    'elevation: 8': 'Use AppTheme.cardTheme or adjust elevation in component theme',
  };

  /// Get recommended theme token for legacy values
  static String getRecommendedToken(String legacyValue) {
    return migrationMap[legacyValue] ?? 'Consider appropriate theme token from AppTheme';
  }
}