# DMRTD Theme System

A comprehensive, centralized theme system for the DMRTD Flutter application that provides consistent design tokens and UI patterns across all platforms.

## 🎨 Architecture Overview

The theme system is organized into specialized modules:

```
lib/theme/
├── theme.dart              # Public API (import this)
├── app_colors.dart         # Color system & semantic tokens
├── app_text_styles.dart    # Typography system & text styles  
├── app_spacing.dart        # Spacing system & layout tokens
├── app_theme.dart          # Complete Material/Cupertino themes
├── component_themes.dart   # Pre-configured component themes
└── README.md              # This documentation
```

## 🚀 Quick Start

### Basic Usage

```dart
import 'package:dmrtd/theme/theme.dart';

// Use semantic color tokens
Container(
  color: AppColors.primary,
  child: Text(
    'Hello World',
    style: AppTextStyles.bodyMedium,
  ),
)

// Use spacing tokens
Padding(
  padding: EdgeInsets.all(AppSpacing.lg),
  child: Column(
    children: [
      Text('Title', style: AppTextStyles.headlineMedium),
      AppSpacing.md.verticalSpace,
      Text('Content', style: AppTextStyles.bodyMedium),
    ],
  ),
)
```

### Theme Integration

```dart
// In your MaterialApp
MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: AppThemeMode.themeMode,
  home: MyApp(),
)

// For platform apps
PlatformApp(
  material: (_, __) => MaterialAppData(theme: AppTheme.lightTheme),
  cupertino: (_, __) => CupertinoAppData(theme: AppTheme.cupertinoTheme),
  home: MyApp(),
)
```

## 🎯 Design System

### Color System (`AppColors`)

Semantic color tokens that replace hardcoded values:

```dart
// Brand Colors
AppColors.primary          // #6b6868 - Main brand color
AppColors.secondary        // #2196F3 - Accent color

// Text Colors  
AppColors.textPrimary      // #212121 - Main text
AppColors.textSecondary    // #666666 - Supporting text
AppColors.textHint         // #999999 - Placeholder text

// Surface Colors
AppColors.background       // #FFFFFF - Screen backgrounds
AppColors.surface          // #F5F5F5 - Card/container backgrounds

// State Colors
AppColors.error           // #D32F2F - Error states
AppColors.success         // #4CAF50 - Success states
AppColors.warning         // #FF9800 - Warning states
```

### Typography System (`AppTextStyles`)

Comprehensive text styles following Material Design principles:

```dart
// Display Styles (Largest)
AppTextStyles.displayLarge    // 32px, bold - Hero text
AppTextStyles.displayMedium   // 28px, bold - Page titles  
AppTextStyles.displaySmall    // 24px, bold - Section titles

// Headline Styles
AppTextStyles.headlineLarge   // 22px, w600 - Important info
AppTextStyles.headlineMedium  // 20px, w600 - Subsections
AppTextStyles.headlineSmall   // 18px, w600 - Minor headers

// Body Styles (Main content)
AppTextStyles.bodyLarge       // 16px, w400 - Important content
AppTextStyles.bodyMedium      // 16px, w400 - Standard content
AppTextStyles.bodySmall       // 14px, w400 - Supporting content

// Semantic Styles
AppTextStyles.error          // Error messages
AppTextStyles.hint           // Placeholder text
AppTextStyles.link           // Interactive text
```

### Spacing System (`AppSpacing`)

8px-based spacing scale with semantic tokens:

```dart
// Primary Scale
AppSpacing.xs     // 4px  - Minimal gaps
AppSpacing.sm     // 8px  - List item gaps
AppSpacing.md     // 12px - Form field spacing
AppSpacing.lg     // 16px - Component padding
AppSpacing.xl     // 20px - Screen content padding
AppSpacing.xxl    // 24px - Screen margins
AppSpacing.xxxl   // 32px - Major section gaps

// Semantic Tokens
AppSpacing.itemGap           // 8px  - Between list items
AppSpacing.componentPadding  // 16px - Internal component padding
AppSpacing.groupGap          // 24px - Between component groups  
AppSpacing.screenMargin      // 24px - Screen edge margins
AppSpacing.sectionGap        // 32px - Between major sections

// Extension methods
AppSpacing.lg.verticalSpace     // SizedBox(height: 16)
AppSpacing.md.allPadding        // EdgeInsets.all(12)
```

## 🧩 Component Themes

Pre-configured themes for common UI patterns:

```dart
// Card themes
ComponentThemes.contentCard     // Standard content cards
ComponentThemes.elevatedCard    // Prominent hero cards
ComponentThemes.compactCard     // Dense list item cards

// Button themes  
ComponentThemes.primaryButton   // Main action buttons
ComponentThemes.secondaryButton // Alternative action buttons
ComponentThemes.dangerButton    // Destructive action buttons

// Form themes
ComponentThemes.formInput       // Standard form inputs
ComponentThemes.compactFormInput // Dense search/inline inputs

// Apply themes using helpers
ThemedComponents.card(
  child: MyContent(),
  theme: ComponentThemes.elevatedCard,
)
```

## 📱 Platform Support

The theme system provides complete support for both Material Design and Cupertino (iOS) patterns:

```dart
// Material Theme
AppTheme.lightTheme    // Complete Material Design theme
AppTheme.darkTheme     // Dark mode support

// Cupertino Theme  
AppTheme.cupertinoTheme // iOS-style theme

// Platform-specific styles
AppTextStyles.materialAppBarTitle  // Material app bar text
AppTextStyles.iosNavigationTitle   // iOS navigation text
```

## 🔄 Migration Guide

### From Hardcoded Values

The theme system includes migration helpers to identify token replacements:

```dart
// Old hardcoded approach ❌
Container(
  padding: EdgeInsets.all(24.0),
  decoration: BoxDecoration(
    color: Color(0xFF6b6868),
    borderRadius: BorderRadius.circular(16),
  ),
  child: Text(
    'Hello',
    style: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Color(0xFF212121),
    ),
  ),
)

// New token-based approach ✅
Container(
  padding: EdgeInsets.all(AppSpacing.screenMargin),
  decoration: BoxDecoration(
    color: AppColors.primary,
    borderRadius: BorderRadius.circular(AppRadius.lg),
  ),
  child: Text(
    'Hello',
    style: AppTextStyles.displaySmall,
  ),
)
```

### From Existing Theme Files

If you have existing theme files, gradually migrate by:

1. Import the new theme system: `import 'package:dmrtd/theme/theme.dart';`
2. Replace hardcoded values with semantic tokens
3. Use migration helpers to identify appropriate tokens
4. Update component usage to use new themes

### Backward Compatibility

The theme system maintains backward compatibility with existing `MyTextStyles`:

```dart
// Legacy approach (still works)
Theme.of(context).defaultTextStyles.primaryLarge

// New approach (recommended)
AppTextStyles.displaySmall
```

## 🎛️ Customization

### Extending Colors

Add custom colors by extending the system:

```dart
class MyAppColors extends AppColors {
  static const Color customBrand = Color(0xFF123456);
  static const Color customAccent = Color(0xFF654321);
}
```

### Custom Component Themes

Create custom themes using the base system:

```dart
static CardTheme get myCustomCard => CardTheme(
  elevation: 6,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.xl),
  ),
  color: AppColors.surface,
  margin: EdgeInsets.all(AppSpacing.lg),
);
```

## 🔧 Development Tools

### Migration Helpers

Use built-in helpers to identify appropriate tokens:

```dart
// Check what token to use for hardcoded values
ColorMigrationHelper.getRecommendedToken('0xFF6b6868');
// Returns: 'AppColors.primary'

SpacingMigrationHelper.getRecommendedToken(24.0);
// Returns: 'AppSpacing.screenMargin'

TextStyleMigrationHelper.getRecommendedStyle('fontSize: 16');  
// Returns: 'AppTextStyles.bodyMedium'
```

### Theme Extensions

Access theme tokens through extensions:

```dart
// In any widget with BuildContext
Theme.of(context).spacing  // Access AppSpacing
Theme.of(context).colors   // Access AppColors  
Theme.of(context).textStyles // Access AppTextStyles
```

## 📖 Best Practices

### 1. Use Semantic Tokens

Always prefer semantic tokens over raw values:

```dart
// ❌ Don't use raw values
padding: EdgeInsets.all(16.0)

// ✅ Use semantic tokens
padding: EdgeInsets.all(AppSpacing.componentPadding)
```

### 2. Consistent Component Usage

Use pre-configured component themes when possible:

```dart
// ❌ Custom card styling
Card(
  elevation: 4,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  child: content,
)

// ✅ Use component theme
content.asContentCard()
```

### 3. Maintain Design Hierarchy

Follow the text style hierarchy:

```dart
Column(
  children: [
    Text('Page Title', style: AppTextStyles.displayMedium),
    Text('Section Header', style: AppTextStyles.headlineMedium),  
    Text('Body content', style: AppTextStyles.bodyMedium),
    Text('Supporting info', style: AppTextStyles.bodySmall),
  ],
)
```

### 4. Responsive Spacing

Use consistent spacing relationships:

```dart
// Related items - small gaps
AppSpacing.itemGap.verticalSpace

// Component groups - medium gaps  
AppSpacing.groupGap.verticalSpace

// Major sections - large gaps
AppSpacing.sectionGap.verticalSpace
```

## 🧪 Testing Theme Integration

Test your theme integration:

```dart
testWidgets('uses consistent theme tokens', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: MyWidget(),
    ),
  );
  
  // Verify theme tokens are applied
  final card = tester.widget<Card>(find.byType(Card));
  expect(card.color, AppColors.surface);
});
```

## 🔮 Future Enhancements

- **Dark Mode**: Complete dark theme implementation
- **Dynamic Themes**: Runtime theme switching
- **Custom Fonts**: Typography customization
- **Animation Tokens**: Motion design system
- **Accessibility**: Enhanced a11y support

## 📚 References

- [Material Design 3](https://m3.material.io/)
- [Flutter Theme Documentation](https://docs.flutter.dev/cookbook/design/themes)
- [Design Token Best Practices](https://spectrum.adobe.com/page/design-tokens/)

---

**Created by Theme Architect Agent** - Centralized theme system for consistent, maintainable UI design.