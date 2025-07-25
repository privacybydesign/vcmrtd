// Created by Theme Architect Agent - Public Theme API
// Main theme barrel file for the DMRTD application

/// Theme System Export
/// 
/// This file provides a single import point for all theme-related
/// functionality in the DMRTD application. Import this file to access
/// all theme tokens, styles, and configurations.
/// 
/// Usage:
/// ```dart
/// import 'package:dmrtd/theme/theme.dart';
/// 
/// // Use theme tokens
/// Container(
///   padding: EdgeInsets.all(AppSpacing.lg),
///   decoration: BoxDecoration(
///     color: AppColors.surface,
///     borderRadius: BorderRadius.circular(AppRadius.md),
///   ),
///   child: Text(
///     'Hello World',
///     style: AppTextStyles.bodyMedium,
///   ),
/// )
/// 
/// // Use in MaterialApp
/// MaterialApp(
///   theme: AppTheme.lightTheme,
///   darkTheme: AppTheme.darkTheme,
///   themeMode: AppThemeMode.themeMode,
///   // ...
/// )
/// ```

// Core theme components
export 'app_colors.dart';
export 'app_text_styles.dart';
export 'app_spacing.dart';
export 'app_theme.dart';

// Re-export commonly used Flutter classes for convenience
export 'package:flutter/material.dart' show 
  ThemeData,
  ColorScheme,
  TextTheme,
  TextStyle,
  Color,
  Colors,
  EdgeInsets,
  BorderRadius,
  BoxDecoration,
  Container,
  SizedBox,
  Padding;