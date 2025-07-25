// Created by Consistency Validator Agent - Standardized Spacing System
// Replaces all hardcoded spacing values with semantic tokens

import 'package:flutter/material.dart';

/// Centralized spacing system for the DMRTD application.
/// Provides consistent spacing tokens that replace hardcoded values
/// throughout the codebase for better design consistency.
class AppSpacing {
  AppSpacing._(); // Private constructor to prevent instantiation

  // MICRO SPACING (Fine adjustments, rare usage)
  /// Tiny spacing for fine adjustments (2px)
  /// Replaces: hardcoded 2.0 values
  static const double xxs = 2.0;

  /// Extra small spacing for minimal gaps (4px)  
  /// Replaces: hardcoded 4.0 values
  static const double xs = 4.0;

  // PRIMARY SPACING SCALE (8px base system)
  /// Small spacing for tight layouts (8px)
  /// Replaces: hardcoded 6.0, 8.0 values
  /// Use for: List item gaps, icon spacing
  static const double sm = 8.0;

  /// Medium spacing for component spacing (12px)
  /// Replaces: hardcoded 12.0 values
  /// Use for: Form field spacing, small container padding
  static const double md = 12.0;

  /// Large spacing for standard component padding (16px)
  /// Replaces: hardcoded 16.0, 18.0 values
  /// Use for: Card padding, button internal spacing
  static const double lg = 16.0;

  /// Extra large spacing for generous padding (20px)
  /// Replaces: hardcoded 20.0 values
  /// Use for: Screen content padding
  static const double xl = 20.0;

  /// Double extra large spacing for section gaps (24px)
  /// Replaces: hardcoded 24.0, 28.0 values
  /// Use for: Screen margins, major component gaps
  static const double xxl = 24.0;

  /// Triple extra large spacing for major sections (32px)
  /// Replaces: hardcoded 32.0+ values
  /// Use for: Page section separation, major layout gaps
  static const double xxxl = 32.0;

  // SEMANTIC SPACING (Purpose-specific tokens)
  /// Spacing between related items in lists or grids
  /// Primary use: SizedBox between list items
  static const double itemGap = sm; // 8.0

  /// Standard internal padding for components
  /// Primary use: EdgeInsets.all() for cards, containers
  static const double componentPadding = lg; // 16.0

  /// Spacing between component groups
  /// Primary use: SizedBox between form sections
  static const double groupGap = xxl; // 24.0

  /// Standard margin for screen edges
  /// Primary use: Screen-level EdgeInsets.all()
  static const double screenMargin = xxl; // 24.0

  /// Large gap between major page sections
  /// Primary use: SizedBox between major content blocks
  static const double sectionGap = xxxl; // 32.0

  // SPECIALIZED SPACING
  /// Minimum touch target spacing for accessibility
  /// Ensures 44pt minimum touch targets on iOS, 48dp on Android
  static const double minTouchTarget = 44.0;
  
  /// Standard spacing for form elements
  /// Use for: Spacing between form fields
  static const double formFieldGap = md; // 12.0

  /// Spacing for button internal padding
  /// Use for: Button EdgeInsets padding
  static const double buttonPadding = lg; // 16.0

  /// Spacing for list item internal padding
  /// Use for: ListTile contentPadding
  static const double listItemPadding = lg; // 16.0
}

/// Border radius tokens for consistent rounded corners
class AppRadius {
  AppRadius._(); // Private constructor

  /// Small radius for subtle rounding (4px)
  /// Use for: Small buttons, chips
  static const double sm = 4.0;

  /// Medium radius for standard components (8px)
  /// Replaces: hardcoded 8.0 values
  /// Use for: Cards, buttons, input fields
  static const double md = 8.0;

  /// Large radius for prominent components (12px)
  /// Replaces: hardcoded 12.0 values  
  /// Use for: Containers, modal dialogs
  static const double lg = 12.0;

  /// Extra large radius for special cases (16px)
  /// Use for: Image containers, special cards
  static const double xl = 16.0;

  /// Fully circular radius
  /// Use for: Avatar images, circular buttons
  static const double circular = 999.0;
}

/// Typography spacing tokens for consistent text sizing
class AppFontSize {
  AppFontSize._(); // Private constructor

  /// Caption text size (12px)
  /// Use for: Helper text, metadata
  static const double caption = 12.0;

  /// Small body text size (14px)
  /// Replaces: hardcoded 14.0 values
  /// Use for: Secondary text, labels
  static const double bodySmall = 14.0;

  /// Standard body text size (16px)
  /// Replaces: hardcoded 16.0 values
  /// Use for: Primary content, form inputs
  static const double body = 16.0;

  /// Large body text size (18px)
  /// Use for: Emphasized content
  static const double bodyLarge = 18.0;

  /// Standard heading size (20px)
  /// Use for: Section headers
  static const double heading = 20.0;

  /// Large heading size (24px)
  /// Replaces: hardcoded 24.0 values
  /// Use for: Page titles, major headings
  static const double headingLarge = 24.0;

  /// Extra large heading size (28px)
  /// Use for: Hero titles
  static const double headingXL = 28.0;
}

/// Icon sizing tokens for consistent iconography
class AppIconSize {
  AppIconSize._(); // Private constructor

  /// Small icon size (16px)
  /// Use for: Inline icons, form field icons
  static const double sm = 16.0;

  /// Medium icon size (24px)
  /// Use for: Standard UI icons
  static const double md = 24.0;

  /// Large icon size (32px)
  /// Replaces: hardcoded 28.0, 32.0 values
  /// Use for: Prominent actions, app bar icons
  static const double lg = 32.0;

  /// Extra large icon size (48px)
  /// Use for: Hero icons, empty states
  static const double xl = 48.0;
}

/// Extension methods for easier spacing usage
extension SpacingExtensions on double {
  /// Convert spacing value to SizedBox height
  Widget get verticalSpace => SizedBox(height: this);
  
  /// Convert spacing value to SizedBox width
  Widget get horizontalSpace => SizedBox(width: this);
  
  /// Convert spacing value to EdgeInsets.all
  EdgeInsets get allPadding => EdgeInsets.all(this);
  
  /// Convert spacing value to EdgeInsets.symmetric horizontal
  EdgeInsets get horizontalPadding => EdgeInsets.symmetric(horizontal: this);
  
  /// Convert spacing value to EdgeInsets.symmetric vertical
  EdgeInsets get verticalPadding => EdgeInsets.symmetric(vertical: this);
}

/// Migration helper - Maps old hardcoded values to new tokens
/// Use this during migration to identify which token to use
class SpacingMigrationHelper {
  static const Map<double, String> migrationMap = {
    2.0: 'AppSpacing.xxs',
    4.0: 'AppSpacing.xs',
    6.0: 'AppSpacing.sm', // Round to 8.0
    8.0: 'AppSpacing.sm',
    12.0: 'AppSpacing.md',
    14.0: 'AppFontSize.bodySmall',
    16.0: 'AppSpacing.lg',
    18.0: 'AppSpacing.lg', // Round to 16.0
    20.0: 'AppSpacing.xl',
    24.0: 'AppSpacing.xxl',
    28.0: 'AppSpacing.xxl', // Round to 24.0
    32.0: 'AppSpacing.xxxl',
  };

  /// Get recommended token for a hardcoded value
  static String getRecommendedToken(double value) {
    return migrationMap[value] ?? 'No direct mapping - consider closest token';
  }
}