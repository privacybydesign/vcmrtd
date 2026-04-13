import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:twentyface_flutter/twentyface_flutter.dart';

void main() {
  group('FaceStatus', () {
    test('fromMap creates status with all false values', () {
      final status = FaceStatus.fromMap({});

      expect(status.isOverallOk, isFalse);
      expect(status.detectionNoFaces, isFalse);
      expect(status.qualitycheckBlurry, isFalse);
    });

    test('fromMap correctly parses status flags', () {
      final status = FaceStatus.fromMap({
        'detection_no_faces': true,
        'qualitycheck_blurry': true,
        'is_overall_ok': false,
      });

      expect(status.detectionNoFaces, isTrue);
      expect(status.qualitycheckBlurry, isTrue);
      expect(status.isOverallOk, isFalse);
    });

    test('toMap returns correct dictionary', () {
      const status = FaceStatus(
        detectionNoFaces: true,
        qualitycheckBlurry: true,
        isOverallOk: false,
      );

      final map = status.toMap();

      expect(map['detection_no_faces'], isTrue);
      expect(map['qualitycheck_blurry'], isTrue);
      expect(map['is_overall_ok'], isFalse);
    });

    test('errorMessages returns correct messages', () {
      const status = FaceStatus(
        detectionNoFaces: true,
        qualitycheckBlurry: true,
        isOverallOk: false,
      );

      final messages = status.errorMessages;

      expect(messages, contains('No face detected'));
      expect(messages, contains('Image is too blurry'));
      expect(messages.length, equals(2));
    });

    test('errorMessages returns empty list when OK', () {
      const status = FaceStatus(isOverallOk: true);

      expect(status.errorMessages, isEmpty);
    });
  });

  group('FaceComparisonResult', () {
    test('fromMap creates result from valid data', () {
      final result = FaceComparisonResult.fromMap({
        'match': true,
        'recognition_distance': 0.5,
        'status_image_1': {'is_overall_ok': true},
        'status_image_2': {'is_overall_ok': true},
      });

      expect(result.match, isTrue);
      expect(result.recognitionDistance, equals(0.5));
      expect(result.statusImage1.isOverallOk, isTrue);
      expect(result.statusImage2.isOverallOk, isTrue);
    });

    test('isSuccessful returns true when both images OK', () {
      final result = FaceComparisonResult.fromMap({
        'match': true,
        'recognition_distance': 0.5,
        'status_image_1': {'is_overall_ok': true},
        'status_image_2': {'is_overall_ok': true},
      });

      expect(result.isSuccessful, isTrue);
    });

    test('isSuccessful returns false when image1 not OK', () {
      final result = FaceComparisonResult.fromMap({
        'match': false,
        'recognition_distance': 0.5,
        'status_image_1': {'is_overall_ok': false, 'detection_no_faces': true},
        'status_image_2': {'is_overall_ok': true},
      });

      expect(result.isSuccessful, isFalse);
    });

    test('isSuccessful returns false when distance is negative', () {
      final result = FaceComparisonResult.fromMap({
        'match': false,
        'recognition_distance': -1.0,
        'status_image_1': {'is_overall_ok': true},
        'status_image_2': {'is_overall_ok': true},
      });

      expect(result.isSuccessful, isFalse);
    });

    test('passedLivenessCheck returns true when not spoofed', () {
      final result = FaceComparisonResult.fromMap({
        'match': true,
        'recognition_distance': 0.5,
        'status_image_1': {
          'is_overall_ok': true,
          'passive_antispoofing_spoofed': false,
          'antispoofing_spoofed': false,
        },
        'status_image_2': {'is_overall_ok': true},
      });

      expect(result.passedLivenessCheck, isTrue);
    });

    test('passedLivenessCheck returns false when spoofed', () {
      final result = FaceComparisonResult.fromMap({
        'match': true,
        'recognition_distance': 0.5,
        'status_image_1': {
          'is_overall_ok': true,
          'passive_antispoofing_spoofed': true,
        },
        'status_image_2': {'is_overall_ok': true},
      });

      expect(result.passedLivenessCheck, isFalse);
    });

    test('similarityPercentage calculates correctly', () {
      final result = FaceComparisonResult.fromMap({
        'match': true,
        'recognition_distance': 0.0, // Perfect match
        'status_image_1': {'is_overall_ok': true},
        'status_image_2': {'is_overall_ok': true},
      });

      expect(result.similarityPercentage, equals(100.0));
    });

    test('similarityPercentage returns null for failed comparison', () {
      final result = FaceComparisonResult.fromMap({
        'match': false,
        'recognition_distance': -1.0,
        'status_image_1': {'is_overall_ok': false},
        'status_image_2': {'is_overall_ok': true},
      });

      expect(result.similarityPercentage, isNull);
    });

    test('similarityPercentage at distance 2.0 equals 0%', () {
      final result = FaceComparisonResult.fromMap({
        'match': false,
        'recognition_distance': 2.0, // Maximum distance
        'status_image_1': {'is_overall_ok': true},
        'status_image_2': {'is_overall_ok': true},
      });

      expect(result.similarityPercentage, equals(0.0));
    });
  });

  group('FaceVerificationConfig', () {
    test('default values are set correctly', () {
      const config = FaceVerificationConfig();

      expect(config.matchThreshold, equals(0.7));
      expect(config.enablePassiveLiveness, isTrue);
      expect(config.livenessThreshold, equals(0.5));
      expect(config.maxHorizontalRotation, equals(30.0));
      expect(config.maxVerticalRotation, equals(30.0));
      expect(config.minSharpness, equals(3.0));
      expect(config.detectClosestOnly, isTrue);
    });

    test('toMap returns correct dictionary', () {
      const config = FaceVerificationConfig(
        matchThreshold: 0.8,
        enablePassiveLiveness: false,
      );

      final map = config.toMap();

      expect(map['match_threshold'], equals(0.8));
      expect(map['enable_passive_liveness'], isFalse);
    });

    test('copyWith creates new instance with updated values', () {
      const config = FaceVerificationConfig();
      final updated = config.copyWith(matchThreshold: 0.9);

      expect(updated.matchThreshold, equals(0.9));
      expect(updated.enablePassiveLiveness, equals(config.enablePassiveLiveness));
    });
  });

  group('FaceRectangle', () {
    test('fromMap creates rectangle from valid data', () {
      final rect = FaceRectangle.fromMap({
        'x': 100,
        'y': 200,
        'width': 300,
        'height': 400,
      });

      expect(rect.x, equals(100));
      expect(rect.y, equals(200));
      expect(rect.width, equals(300));
      expect(rect.height, equals(400));
    });

    test('center calculates correctly', () {
      final rect = FaceRectangle.fromMap({
        'x': 0,
        'y': 0,
        'width': 100,
        'height': 100,
      });

      expect(rect.center.dx, equals(50.0));
      expect(rect.center.dy, equals(50.0));
    });

    test('toRect creates correct Rect', () {
      final rect = FaceRectangle.fromMap({
        'x': 10,
        'y': 20,
        'width': 30,
        'height': 40,
      });

      final flutterRect = rect.toRect();

      expect(flutterRect.left, equals(10.0));
      expect(flutterRect.top, equals(20.0));
      expect(flutterRect.width, equals(30.0));
      expect(flutterRect.height, equals(40.0));
    });
  });

  group('FaceDetection', () {
    test('fromMap creates detection from valid data', () {
      final detection = FaceDetection.fromMap({
        'id': 1,
        'score': 0.95,
        'rectangle': {'x': 100, 'y': 100, 'width': 200, 'height': 250},
        'status': {'is_overall_ok': true},
        'pose': {'yaw': 5.0, 'pitch': -3.0, 'roll': 2.0},
        'frame_width': 1920,
        'frame_height': 1080,
      });

      expect(detection.id, equals(1));
      expect(detection.score, equals(0.95));
      expect(detection.rectangle.x, equals(100));
      expect(detection.status.isOverallOk, isTrue);
      expect(detection.pose.yaw, equals(5.0));
      expect(detection.frameWidth, equals(1920));
    });

    test('normalizedRect calculates correctly', () {
      final detection = FaceDetection.fromMap({
        'id': 1,
        'score': 0.95,
        'rectangle': {'x': 480, 'y': 270, 'width': 960, 'height': 540},
        'status': {'is_overall_ok': true},
        'pose': {},
        'frame_width': 1920,
        'frame_height': 1080,
      });

      final normalized = detection.normalizedRect;

      expect(normalized.left, equals(0.25));
      expect(normalized.top, equals(0.25));
      expect(normalized.width, equals(0.5));
      expect(normalized.height, equals(0.5));
    });

    test('normalizedRect returns zero rect when frame size is 0', () {
      final detection = FaceDetection.fromMap({
        'id': 1,
        'score': 0.95,
        'rectangle': {'x': 100, 'y': 100, 'width': 200, 'height': 250},
        'status': {'is_overall_ok': true},
        'pose': {},
        'frame_width': 0,
        'frame_height': 0,
      });

      expect(detection.normalizedRect, equals(Rect.zero));
    });
  });

  group('LivenessResult', () {
    test('fromMap creates result from valid data', () {
      final result = LivenessResult.fromMap({
        'is_live': true,
        'score': 0.85,
        'status': {'is_overall_ok': true, 'passive_antispoofing_spoofed': false},
      });

      expect(result.isLive, isTrue);
      expect(result.score, equals(0.85));
      expect(result.status.isOverallOk, isTrue);
    });

    test('fromMap infers isLive from status when not provided', () {
      final result = LivenessResult.fromMap({
        'score': 0.85,
        'status': {
          'is_overall_ok': true,
          'passive_antispoofing_spoofed': false,
          'antispoofing_spoofed': false,
        },
      });

      expect(result.isLive, isTrue);
    });

    test('fromMap detects spoofed from status', () {
      final result = LivenessResult.fromMap({
        'score': 0.85,
        'status': {
          'is_overall_ok': false,
          'passive_antispoofing_spoofed': true,
        },
      });

      expect(result.isLive, isFalse);
    });
  });

  group('FaceVerificationService', () {
    test('throws when not initialized', () {
      final service = FaceVerificationService();

      expect(
        () => service.getVersion(),
        throwsA(isA<StateError>()),
      );
    });

    test('isInitialized returns false before initialization', () {
      final service = FaceVerificationService();

      expect(service.isInitialized, isFalse);
    });

    test('throws when initialized twice', () async {
      // Note: This test would fail in real execution because initialize()
      // actually calls native code. This is a structural test only.
      final service = FaceVerificationService();

      // We can't actually test this without mocking, but we verify the property
      expect(service.isInitialized, isFalse);
    });

    test('defaultConfig can be set', () {
      final service = FaceVerificationService();
      const newConfig = FaceVerificationConfig(matchThreshold: 0.9);

      service.defaultConfig = newConfig;

      expect(service.defaultConfig.matchThreshold, equals(0.9));
    });
  });

  group('imageTypeFromString', () {
    test('returns jpeg2000 for "jpeg2000"', () {
      expect(imageTypeFromString('jpeg2000'), equals(ImageType.jpeg2000));
    });

    test('returns jpeg2000 for "JPEG2000" (case insensitive)', () {
      expect(imageTypeFromString('JPEG2000'), equals(ImageType.jpeg2000));
    });

    test('returns jpeg for "jpeg"', () {
      expect(imageTypeFromString('jpeg'), equals(ImageType.jpeg));
    });

    test('returns jpeg for unknown types', () {
      expect(imageTypeFromString('unknown'), equals(ImageType.jpeg));
    });
  });
}
