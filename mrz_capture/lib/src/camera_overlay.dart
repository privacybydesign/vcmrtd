import 'package:flutter/material.dart';

class MRZCameraOverlay extends StatelessWidget {
  const MRZCameraOverlay({required this.child, this.frameRatio = passportFrameRatio, super.key});

  /// A passport data page (ISO/IEC 7810 ID-3) is 125mm × 88mm.
  static const passportFrameRatio = 1.42;

  /// An ID card or driving licence (ISO/IEC 7810 ID-1) is 85.6mm × 54mm.
  static const cardFrameRatio = 85.6 / 54;

  final Widget child;

  /// The frame's width / height; the passport page's by default.
  final double frameRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final overlayRect = RRect.fromRectAndRadius(frameRect(Size(c.maxWidth, c.maxHeight), frameRatio), _frameRadius);
        return Stack(
          children: [
            child,
            ClipPath(
              clipper: _DocumentClipper(rect: overlayRect),
              child: Container(foregroundDecoration: const BoxDecoration(color: Color.fromRGBO(0, 0, 0, 0.45))),
            ),
            _WhiteOverlay(rect: overlayRect),
          ],
        );
      },
    );
  }

  static const _frameRadius = Radius.circular(8);

  /// Where the frame lies in a view of [size]: centred, 90% of the width in
  /// portrait and 75% of the height in landscape. The camera view reads text
  /// and cuts pictures to this same rectangle.
  static Rect frameRect(Size size, double frameRatio) {
    double width, height;
    if (size.height > size.width) {
      width = size.width * 0.9;
      height = width / frameRatio;
    } else {
      height = size.height * 0.75;
      width = height * frameRatio;
    }
    return Rect.fromLTWH((size.width - width) / 2, (size.height - height) / 2, width, height);
  }
}

class _DocumentClipper extends CustomClipper<Path> {
  _DocumentClipper({required this.rect});

  final RRect rect;

  @override
  Path getClip(Size size) => Path()
    ..addRRect(rect)
    ..addRect(Rect.fromLTWH(0.0, 0.0, size.width, size.height))
    ..fillType = PathFillType.evenOdd;

  @override
  bool shouldReclip(_DocumentClipper oldClipper) => false;
}

class _WhiteOverlay extends StatelessWidget {
  const _WhiteOverlay({required this.rect});
  final RRect rect;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: rect.left,
      top: rect.top,
      child: Container(
        width: rect.width,
        height: rect.height,
        decoration: BoxDecoration(
          border: Border.all(width: 2.0, color: const Color(0xFFFFFFFF)),
          borderRadius: BorderRadius.all(rect.tlRadius),
        ),
      ),
    );
  }
}
