import 'dart:ui';

import 'face_status.dart';

/// A rectangle representing a face bounding box.
class FaceRectangle {
  final int x;
  final int y;
  final int width;
  final int height;

  const FaceRectangle({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory FaceRectangle.fromMap(Map<dynamic, dynamic> map) {
    return FaceRectangle(
      x: map['x'] as int? ?? 0,
      y: map['y'] as int? ?? 0,
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
    );
  }

  Rect toRect() => Rect.fromLTWH(
        x.toDouble(),
        y.toDouble(),
        width.toDouble(),
        height.toDouble(),
      );

  /// Returns the center point of the rectangle.
  Offset get center => Offset(
        x + width / 2.0,
        y + height / 2.0,
      );

  Map<String, int> toMap() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  @override
  String toString() => 'FaceRectangle($x, $y, $width x $height)';
}

/// Face pose estimation (rotation angles).
class FacePose {
  /// Horizontal rotation (yaw) in degrees.
  final double yaw;

  /// Vertical rotation (pitch) in degrees.
  final double pitch;

  /// Tilt rotation (roll) in degrees.
  final double roll;

  const FacePose({
    this.yaw = 0.0,
    this.pitch = 0.0,
    this.roll = 0.0,
  });

  factory FacePose.fromMap(Map<dynamic, dynamic> map) {
    return FacePose(
      yaw: (map['yaw'] as num?)?.toDouble() ?? 0.0,
      pitch: (map['pitch'] as num?)?.toDouble() ?? 0.0,
      roll: (map['roll'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, double> toMap() {
    return {
      'yaw': yaw,
      'pitch': pitch,
      'roll': roll,
    };
  }

  @override
  String toString() =>
      'FacePose(yaw: ${yaw.toStringAsFixed(1)}°, pitch: ${pitch.toStringAsFixed(1)}°, roll: ${roll.toStringAsFixed(1)}°)';
}

/// Result of face detection in an image.
class FaceDetection {
  /// Detection ID.
  final int id;

  /// Face bounding box.
  final FaceRectangle rectangle;

  /// Detection confidence score.
  final double score;

  /// Face status (quality checks).
  final FaceStatus status;

  /// Face pose estimation.
  final FacePose pose;

  /// Width of the source frame.
  final int frameWidth;

  /// Height of the source frame.
  final int frameHeight;

  const FaceDetection({
    required this.id,
    required this.rectangle,
    required this.score,
    required this.status,
    required this.pose,
    required this.frameWidth,
    required this.frameHeight,
  });

  factory FaceDetection.fromMap(Map<dynamic, dynamic> map) {
    return FaceDetection(
      id: map['id'] as int? ?? 0,
      rectangle: map['rectangle'] != null
          ? FaceRectangle.fromMap(map['rectangle'] as Map<dynamic, dynamic>)
          : const FaceRectangle(x: 0, y: 0, width: 0, height: 0),
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] != null
          ? FaceStatus.fromMap(map['status'] as Map<dynamic, dynamic>)
          : const FaceStatus(isOverallOk: false),
      pose: map['pose'] != null
          ? FacePose.fromMap(map['pose'] as Map<dynamic, dynamic>)
          : const FacePose(),
      frameWidth: map['frame_width'] as int? ?? 0,
      frameHeight: map['frame_height'] as int? ?? 0,
    );
  }

  /// Whether the face detection passed all quality checks.
  bool get isOverallOk => status.isOverallOk;

  /// Returns the face rectangle normalized to 0-1 range based on frame size.
  Rect get normalizedRect {
    if (frameWidth == 0 || frameHeight == 0) return Rect.zero;
    return Rect.fromLTWH(
      rectangle.x / frameWidth,
      rectangle.y / frameHeight,
      rectangle.width / frameWidth,
      rectangle.height / frameHeight,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rectangle': rectangle.toMap(),
      'score': score,
      'status': status.toMap(),
      'pose': pose.toMap(),
      'frame_width': frameWidth,
      'frame_height': frameHeight,
    };
  }

  @override
  String toString() =>
      'FaceDetection(id: $id, rect: $rectangle, score: ${score.toStringAsFixed(2)}, ok: $isOverallOk)';
}
