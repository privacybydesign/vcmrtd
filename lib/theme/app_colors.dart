// Created by Theme Architect Agent - Centralized Color System
// Provides consistent color tokens for the DMRTD application

import 'package:flutter/material.dart';

/// Centralized color system for the DMRTD application.
/// Provides semantic color tokens that replace hardcoded color values
/// throughout the codebase for better design consistency and theming support.
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // SEMANTIC COLORS (Primary design system)
  /// Primary brand color - main identity color
  /// Replaces: Color(0xFF6b6868), indigo variations
  /// Use for: Primary buttons, app bars, key UI elements
  static const Color primary = Color(0xFF6b6868);
  
  /// Primary color variant for hover/pressed states
  static const Color primaryVariant = Color(0xFF5A5A5A);
  
  /// Primary color with light opacity for backgrounds
  static const Color primaryLight = Color(0xFFE8E8E8);
  
  /// Secondary accent color for highlights and CTAs
  /// Replaces: Color(0xFF2196F3), blue accents
  /// Use for: Secondary buttons, links, highlights
  static const Color secondary = Color(0xFF2196F3);
  
  /// Secondary color variant
  static const Color secondaryVariant = Color(0xFF1976D2);

  // TEXT COLORS (Hierarchical text system)
  /// Primary text color for main content
  /// Replaces: Color(0xFF212121), Colors.black87
  /// Use for: Headers, primary body text
  static const Color textPrimary = Color(0xFF212121);
  
  /// Secondary text color for supporting content
  /// Replaces: Color(0xFF666666), Colors.grey
  /// Use for: Descriptions, metadata, secondary information
  static const Color textSecondary = Color(0xFF666666);
  
  /// Hint text color for placeholders and guides
  /// Use for: Input placeholders, helper text
  static const Color textHint = Color(0xFF999999);
  
  /// Disabled text color
  /// Use for: Disabled form fields, inactive elements
  static const Color textDisabled = Color(0xFFBDBDBD);

  // SURFACE COLORS (Backgrounds and containers)
  /// Primary background color
  /// Use for: Screen backgrounds, main content areas
  static const Color background = Color(0xFFFFFFFF);
  
  /// Secondary background color for cards and containers
  /// Replaces: Color(0xFFF5F5F5)
  /// Use for: Card backgrounds, secondary containers
  static const Color surface = Color(0xFFF5F5F5);
  
  /// Surface variant for subtle differentiation
  static const Color surfaceVariant = Color(0xFFFAFAFA);

  // STATE COLORS (Feedback and status)
  /// Error color for failures and warnings
  /// Replaces: Colors.redAccent
  /// Use for: Error messages, validation failures
  static const Color error = Color(0xFFD32F2F);
  
  /// Success color for positive feedback
  /// Replaces: Color(0xFF4CAF50)
  /// Use for: Success messages, completion states
  static const Color success = Color(0xFF4CAF50);
  
  /// Warning color for caution states
  /// Use for: Warning messages, attention items
  static const Color warning = Color(0xFFFF9800);
  
  /// Info color for informational content
  /// Use for: Info messages, neutral notifications
  static const Color info = Color(0xFF2196F3);

  // GRADIENT COLORS (For complex backgrounds)
  /// Top color for main gradient
  /// Replaces: Color(0xFF6b6868) in gradient starts
  static const Color gradientStart = Color(0xFF6b6868);
  
  /// Bottom color for main gradient
  /// Replaces: Colors.white in gradient ends
  static const Color gradientEnd = Color(0xFFFFFFFF);

  // BORDER COLORS (Outlines and dividers)
  /// Primary border color for inputs and cards
  /// Use for: Input borders, card outlines
  static const Color border = Color(0xFFE0E0E0);
  
  /// Focused border color for active elements
  /// Use for: Focused inputs, active selections
  static const Color borderFocused = Color(0xFF6b6868);
  
  /// Divider color for separating content
  /// Use for: List dividers, section separators
  static const Color divider = Color(0xFFE0E0E0);

  // OVERLAY COLORS (Transparency and layering)
  /// Semi-transparent overlay for modals
  /// Use for: Modal backgrounds, overlay screens
  static const Color overlay = Color(0x80000000);
  
  /// Light overlay for hover states
  /// Use for: Button hover effects, interaction feedback
  static const Color overlayLight = Color(0x0F000000);

  // PLATFORM-SPECIFIC COLORS
  /// iOS-style system colors
  static const Color iosBlue = CupertinoColors.activeBlue;
  static const Color iosGray = CupertinoColors.systemGrey6;
  
  /// Material design colors
  static const Color materialPrimary = Colors.indigo;
  static const Color materialAccent = Colors.indigoAccent;
}

/// Light theme color scheme
class LightColorScheme {
  static const ColorScheme scheme = ColorScheme.light(
    primary: AppColors.primary,
    primaryContainer: AppColors.primaryLight,
    secondary: AppColors.secondary,
    secondaryContainer: AppColors.secondaryVariant,
    surface: AppColors.surface,
    background: AppColors.background,
    error: AppColors.error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: AppColors.textPrimary,
    onBackground: AppColors.textPrimary,
    onError: Colors.white,
  );
}

/// Dark theme color scheme (future expansion)
class DarkColorScheme {
  static const ColorScheme scheme = ColorScheme.dark(
    primary: Color(0xFF8A8A8A),
    primaryContainer: Color(0xFF424242),
    secondary: Color(0xFF64B5F6),
    secondaryContainer: Color(0xFF1565C0),
    surface: Color(0xFF121212),
    background: Color(0xFF000000),
    error: Color(0xFFCF6679),
    onPrimary: Colors.black,
    onSecondary: Colors.black,
    onSurface: Colors.white,
    onBackground: Colors.white,
    onError: Colors.black,
  );
}

/// Extension methods for easier color usage
extension ColorExtensions on Color {
  /// Get a color with specified opacity
  Color withAlpha(int alpha) => Color.fromARGB(alpha, red, green, blue);
  
  /// Get a lighter version of the color
  Color lighten([double amount = 0.1]) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
  
  /// Get a darker version of the color
  Color darken([double amount = 0.1]) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}

/// Migration helper for color values
class ColorMigrationHelper {
  static const Map<String, String> migrationMap = {
    '0xFF6b6868': 'AppColors.primary',
    '0xFF212121': 'AppColors.textPrimary',
    '0xFF666666': 'AppColors.textSecondary',
    '0xFF2196F3': 'AppColors.secondary',
    '0xFFF5F5F5': 'AppColors.surface',
    '0xFF4CAF50': 'AppColors.success',
    'Colors.redAccent': 'AppColors.error',
    'Colors.grey': 'AppColors.textSecondary',
    'Colors.black87': 'AppColors.textPrimary',
    'Colors.indigo': 'AppColors.materialPrimary',
  };

  /// Get recommended color token for a hardcoded value
  static String getRecommendedToken(String colorValue) {
    return migrationMap[colorValue] ?? 'No direct mapping - consider closest semantic color';
  }
}