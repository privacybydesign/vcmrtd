import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/face_detection.dart';

/// Painter for the face detection overlay.
///
/// Draws an oval guide for face positioning and highlights
/// detected faces with status indicators.
class FaceOverlayPainter extends CustomPainter {
  /// Current face detections from the camera feed.
  final List<FaceDetection> detections;

  /// Whether a face is properly positioned and ready for capture.
  final bool isReady;

  /// Color of the guide oval when no face is detected or not ready.
  final Color guideColor;

  /// Color of the guide oval when face is ready for capture.
  final Color readyColor;

  /// Width of the oval stroke.
  final double strokeWidth;

  /// Aspect ratio of the oval (height/width).
  final double ovalAspectRatio;

  /// Size of the oval relative to the widget width.
  final double ovalWidthRatio;

  FaceOverlayPainter({
    this.detections = const [],
    this.isReady = false,
    this.guideColor = Colors.white,
    this.readyColor = Colors.green,
    this.strokeWidth = 3.0,
    this.ovalAspectRatio = 1.3,
    this.ovalWidthRatio = 0.7,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ovalWidth = size.width * ovalWidthRatio;
    final ovalHeight = ovalWidth * ovalAspectRatio;

    // Draw semi-transparent overlay outside the oval
    _drawOverlayMask(canvas, size, center, ovalWidth, ovalHeight);

    // Draw the guide oval
    _drawOvalGuide(canvas, center, ovalWidth, ovalHeight);

    // Draw face detection rectangles
    for (final detection in detections) {
      _drawFaceDetection(canvas, size, detection);
    }
  }

  void _drawOverlayMask(
    Canvas canvas,
    Size size,
    Offset center,
    double ovalWidth,
    double ovalHeight,
  ) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCenter(
        center: center,
        width: ovalWidth,
        height: ovalHeight,
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  void _drawOvalGuide(
    Canvas canvas,
    Offset center,
    double width,
    double height,
  ) {
    final color = isReady ? readyColor : guideColor;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromCenter(center: center, width: width, height: height);

    if (isReady) {
      // Solid line when ready
      canvas.drawOval(rect, paint);

      // Add a glow effect when ready
      final glowPaint = Paint()
        ..color = readyColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawOval(rect, glowPaint);
    } else {
      // Dashed line when not ready
      _drawDashedOval(canvas, rect, paint);
    }
  }

  void _drawDashedOval(Canvas canvas, Rect rect, Paint paint) {
    const dashLength = 15.0;
    const gapLength = 10.0;

    final path = Path()..addOval(rect);
    final metrics = path.computeMetrics().first;
    final length = metrics.length;

    var distance = 0.0;
    while (distance < length) {
      final extractPath = metrics.extractPath(
        distance,
        math.min(distance + dashLength, length),
      );
      canvas.drawPath(extractPath, paint);
      distance += dashLength + gapLength;
    }
  }

  void _drawFaceDetection(
    Canvas canvas,
    Size size,
    FaceDetection detection,
  ) {
    // Convert normalized coordinates to canvas coordinates
    final normalizedRect = detection.normalizedRect;
    final rect = Rect.fromLTWH(
      normalizedRect.left * size.width,
      normalizedRect.top * size.height,
      normalizedRect.width * size.width,
      normalizedRect.height * size.height,
    );

    final color = detection.isOverallOk ? Colors.green : Colors.orange;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw corner brackets instead of full rectangle
    _drawCornerBrackets(canvas, rect, paint);
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect, Paint paint) {
    final cornerLength = math.min(rect.width, rect.height) * 0.2;

    final path = Path()
      // Top left
      ..moveTo(rect.left, rect.top + cornerLength)
      ..lineTo(rect.left, rect.top)
      ..lineTo(rect.left + cornerLength, rect.top)
      // Top right
      ..moveTo(rect.right - cornerLength, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.top + cornerLength)
      // Bottom right
      ..moveTo(rect.right, rect.bottom - cornerLength)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.right - cornerLength, rect.bottom)
      // Bottom left
      ..moveTo(rect.left + cornerLength, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.bottom - cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant FaceOverlayPainter oldDelegate) {
    return detections != oldDelegate.detections ||
        isReady != oldDelegate.isReady ||
        guideColor != oldDelegate.guideColor ||
        readyColor != oldDelegate.readyColor;
  }
}
