import 'package:image/image.dart' as img;

/// Lines of dark text on a white page, 600 by 400.
img.Image textPage() {
  final page = img.Image(width: 600, height: 400)..clear(img.ColorRgb8(255, 255, 255));
  for (var line = 0; line < 6; line++) {
    img.drawString(
      page,
      'IDENTITY CARD 1234567',
      font: img.arial24,
      x: 40,
      y: 40 + line * 55,
      color: img.ColorRgb8(0, 0, 0),
    );
  }
  return page;
}
