// Created by Theme Architect Agent - Component-Specific Theme Configurations
// Provides pre-configured themes for common UI components

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_spacing.dart';

/// Component-specific theme configurations for consistent UI patterns.
/// These themes can be applied directly to widgets or used as base
/// configurations for custom components.
class ComponentThemes {
  ComponentThemes._(); // Private constructor

  // CARD THEMES
  /// Standard card theme for content containers
  /// Use for: General content cards, information displays
  static CardTheme get contentCard => CardTheme(
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    color: AppColors.surface,
    margin: EdgeInsets.all(AppSpacing.itemGap),
    clipBehavior: Clip.antiAlias,
  );

  /// Elevated card theme for prominent content
  /// Use for: Hero cards, important announcements
  static CardTheme get elevatedCard => CardTheme(
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
    ),
    color: AppColors.surface,
    margin: EdgeInsets.all(AppSpacing.groupGap),
    clipBehavior: Clip.antiAlias,
  );

  /// Compact card theme for list items
  /// Use for: List item cards, compact displays
  static CardTheme get compactCard => CardTheme(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    color: AppColors.surface,
    margin: EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    clipBehavior: Clip.antiAlias,
  );

  // BUTTON THEMES
  /// Primary action button theme
  /// Use for: Main CTAs, primary actions
  static ElevatedButtonThemeData get primaryButton => ElevatedButtonThemeData(
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
      minimumSize: Size(double.infinity, AppSpacing.minTouchTarget),
    ),
  );

  /// Secondary action button theme
  /// Use for: Secondary actions, alternative choices
  static OutlinedButtonThemeData get secondaryButton => OutlinedButtonThemeData(
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
      side: const BorderSide(color: AppColors.primary, width: 2),
      minimumSize: Size(double.infinity, AppSpacing.minTouchTarget),
    ),
  );

  /// Danger/destructive action button theme
  /// Use for: Delete actions, destructive operations
  static ElevatedButtonThemeData get dangerButton => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.error,
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
      minimumSize: Size(double.infinity, AppSpacing.minTouchTarget),
    ),
  );

  // FORM THEMES
  /// Standard form input theme
  /// Use for: Text inputs, dropdowns, form fields
  static InputDecorationTheme get formInput => InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.borderFocused, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
    contentPadding: EdgeInsets.all(AppSpacing.componentPadding),
    labelStyle: AppTextStyles.labelLarge,
    hintStyle: AppTextStyles.hint,
    errorStyle: AppTextStyles.error,
    filled: true,
    fillColor: AppColors.surfaceVariant,
  );

  /// Compact form input theme for dense layouts
  /// Use for: Search fields, inline inputs
  static InputDecorationTheme get compactFormInput => InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    contentPadding: EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    labelStyle: AppTextStyles.labelMedium,
    hintStyle: AppTextStyles.bodySmall,
    errorStyle: AppTextStyles.caption,
    isDense: true,
  );

  // LIST THEMES
  /// Standard list tile theme
  /// Use for: Menu items, settings lists, data lists
  static ListTileThemeData get standardListTile => ListTileThemeData(
    contentPadding: EdgeInsets.all(AppSpacing.listItemPadding),
    titleTextStyle: AppTextStyles.titleMedium,
    subtitleTextStyle: AppTextStyles.bodySmall,
    leadingAndTrailingTextStyle: AppTextStyles.labelMedium,
    dense: false,
    visualDensity: VisualDensity.standard,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
  );

  /// Compact list tile theme for dense information
  /// Use for: Data tables, compact lists
  static ListTileThemeData get compactListTile => ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    titleTextStyle: AppTextStyles.bodyMedium,
    subtitleTextStyle: AppTextStyles.caption,
    leadingAndTrailingTextStyle: AppTextStyles.labelSmall,
    dense: true,
    visualDensity: VisualDensity.compact,
  );

  // DIALOG THEMES
  /// Standard dialog theme
  /// Use for: Confirmation dialogs, information modals
  static DialogTheme get standardDialog => DialogTheme(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    titleTextStyle: AppTextStyles.headlineMedium,
    contentTextStyle: AppTextStyles.bodyMedium,
    backgroundColor: AppColors.surface,
    elevation: 8,
    insetPadding: EdgeInsets.all(AppSpacing.screenMargin),
  );

  /// Alert dialog theme for important messages
  /// Use for: Error alerts, critical confirmations
  static DialogTheme get alertDialog => DialogTheme(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    titleTextStyle: AppTextStyles.headlineMedium.copyWith(
      color: AppColors.error,
    ),
    contentTextStyle: AppTextStyles.bodyMedium,
    backgroundColor: AppColors.surface,
    elevation: 12,
  );

  // APP BAR THEMES
  /// Standard app bar theme
  /// Use for: Main navigation, screen headers
  static AppBarTheme get standardAppBar => const AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    elevation: 2,
    centerTitle: true,
    titleTextStyle: AppTextStyles.materialAppBarTitle,
    iconTheme: IconThemeData(
      color: Colors.white,
      size: AppIconSize.md,
    ),
    actionsIconTheme: IconThemeData(
      color: Colors.white,
      size: AppIconSize.md,
    ),
  );

  /// Transparent app bar theme for overlay screens
  /// Use for: Scanner screens, image viewers
  static AppBarTheme get transparentAppBar => AppBarTheme(
    backgroundColor: Colors.black.withOpacity(0.3),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: AppTextStyles.materialAppBarTitle,
    iconTheme: const IconThemeData(
      color: Colors.white,
      size: AppIconSize.md,
    ),
  );

  // TAB THEMES
  /// Standard tab bar theme
  /// Use for: Content tabs, section navigation
  static TabBarTheme get standardTabBar => const TabBarTheme(
    labelColor: AppColors.secondary,
    unselectedLabelColor: AppColors.textSecondary,
    labelStyle: AppTextStyles.labelLarge,
    unselectedLabelStyle: AppTextStyles.labelMedium,
    indicator: UnderlineTabIndicator(
      borderSide: BorderSide(color: AppColors.secondary, width: 2),
    ),
    indicatorSize: TabBarIndicatorSize.tab,
  );

  // CHIP THEMES
  /// Standard chip theme
  /// Use for: Tags, filters, selections
  static ChipThemeData get standardChip => ChipThemeData(
    backgroundColor: AppColors.surfaceVariant,
    selectedColor: AppColors.primary,
    disabledColor: AppColors.surface,
    labelStyle: AppTextStyles.labelMedium,
    secondaryLabelStyle: AppTextStyles.labelSmall,
    padding: EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.circular),
    ),
  );
}

/// Widget builder helpers that apply component themes
class ThemedComponents {
  /// Create a themed card widget
  static Widget card({
    required Widget child,
    CardTheme? theme,
    VoidCallback? onTap,
  }) {
    theme ??= ComponentThemes.contentCard;
    
    final card = Card(
      elevation: theme.elevation,
      shape: theme.shape,
      color: theme.color,
      margin: theme.margin,
      clipBehavior: theme.clipBehavior,
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: (theme.shape as RoundedRectangleBorder?)?.borderRadius as BorderRadius?,
        child: card,
      );
    }

    return card;
  }

  /// Create a themed form field
  static Widget formField({
    required String labelText,
    String? hintText,
    TextEditingController? controller,
    String? Function(String?)? validator,
    InputDecorationTheme? theme,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    theme ??= ComponentThemes.formInput;
    
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: theme.border,
        enabledBorder: theme.enabledBorder,
        focusedBorder: theme.focusedBorder,
        errorBorder: theme.errorBorder,
        contentPadding: theme.contentPadding,
        labelStyle: theme.labelStyle,
        hintStyle: theme.hintStyle,
        errorStyle: theme.errorStyle,
        filled: theme.filled,
        fillColor: theme.fillColor,
      ),
    );
  }

  /// Create a themed section with title and content
  static Widget section({
    required String title,
    required Widget content,
    EdgeInsets? padding,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: padding ?? EdgeInsets.all(AppSpacing.screenMargin),
          child: Text(
            title,
            style: AppTextStyles.headlineMedium,
          ),
        ),
        AppSpacing.groupGap.verticalSpace,
        content,
      ],
    );
  }

  /// Create a themed action button row
  static Widget actionButtonRow({
    required List<Widget> buttons,
    MainAxisAlignment alignment = MainAxisAlignment.spaceEvenly,
  }) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.screenMargin),
      child: Row(
        mainAxisAlignment: alignment,
        children: buttons
            .map((button) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: button,
                  ),
                ))
            .toList(),
      ),
    );
  }
}

/// Helper for applying themes to specific widget types
extension ComponentThemeExtensions on Widget {
  /// Apply content card theme to any widget
  Widget asContentCard({VoidCallback? onTap}) {
    return ThemedComponents.card(
      child: this,
      theme: ComponentThemes.contentCard,
      onTap: onTap,
    );
  }

  /// Apply elevated card theme to any widget
  Widget asElevatedCard({VoidCallback? onTap}) {
    return ThemedComponents.card(
      child: this,
      theme: ComponentThemes.elevatedCard,
      onTap: onTap,
    );
  }

  /// Apply section padding to any widget
  Widget asSectionContent() {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.screenMargin),
      child: this,
    );
  }
}