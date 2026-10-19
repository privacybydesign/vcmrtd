import 'package:flutter/material.dart';
import 'package:idem/theme/brand_theme.dart';

/// The brand's logo in a [size] square, or its name as a wordmark when it
/// has none.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.size, this.onDark = false, this.excludeFromSemantics = false});

  final double size;

  /// Whether it sits on a dark background, which the wordmark is then light on.
  final bool onDark;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final logo = brand.logo;
    if (logo != null) {
      return Image(
        image: logo,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: brand.name,
        excludeFromSemantics: excludeFromSemantics,
        // A logo the phone can't draw (an SVG one, say) shows the name instead.
        errorBuilder: (context, error, stackTrace) => _wordmark(brand),
      );
    }
    return _wordmark(brand);
  }

  Widget _wordmark(BrandTheme brand) {
    final wordmark = Text(
      brand.name,
      maxLines: 1,
      style: TextStyle(
        fontFamily: brand.headingFontFamily,
        fontSize: size * 0.5,
        fontWeight: FontWeight.w700,
        color: onDark ? Colors.white : (brand.ink ?? Colors.black87),
      ),
    );
    return SizedBox(
      height: size,
      child: Center(widthFactor: 1, child: excludeFromSemantics ? ExcludeSemantics(child: wordmark) : wordmark),
    );
  }
}
