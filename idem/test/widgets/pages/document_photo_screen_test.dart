import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:idem/l10n/l10n.dart';
import 'package:idem/widgets/pages/document_photo_screen.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/vcmrtd.dart';

class _FakeCamera implements DocumentPhotoCamera {
  _FakeCamera({this.openError});

  Object? openError;
  var opens = 0;
  var closes = 0;

  /// Every picture taken, each a different image.
  final taken = <Uint8List>[];

  /// When set, [open] waits for it: a camera that takes a while to open.
  Completer<void>? openGate;

  @override
  Future<void> open() async {
    opens++;
    await openGate?.future;
    if (openError != null) throw openError!;
  }

  @override
  Widget buildPreview(BuildContext context) => const ColoredBox(key: Key('fake preview'), color: Colors.grey);

  /// The frame ratio of every picture taken.
  final frameRatios = <double>[];

  /// When set, [takePicture] waits for it: a picture that takes a moment.
  Completer<void>? pictureGate;

  @override
  Future<Uint8List> takePicture({required double frameRatio}) async {
    await pictureGate?.future;
    final picture = Uint8List.fromList(img.encodeJpg(img.Image(width: 4 + taken.length, height: 3)));
    taken.add(picture);
    frameRatios.add(frameRatio);
    return picture;
  }

  @override
  Future<Uint8List> prepare(DocumentPicture picture) async => picture.jpeg;

  @override
  Future<void> close() async => closes++;
}

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Widget _screen(
  _FakeCamera camera, {
  DocumentType? documentType,
  Uint8List? scanned,
  Future<void> Function(Uint8List front, Uint8List? back)? onPhotosTaken,
  VoidCallback? onBack,
}) => _app(
  DocumentPhotoScreen(
    camera: camera,
    documentType: documentType,
    scanned: scanned,
    stepNumber: 2,
    totalSteps: 3,
    onBack: onBack ?? () {},
    onPhotosTaken: onPhotosTaken ?? (_, _) async {},
  ),
);

/// A photo the MRZ scan took, unlike any the fake camera takes.
Uint8List _scannedPhoto() => Uint8List.fromList(img.encodeJpg(img.Image(width: 20, height: 12)));

/// [jpeg] with a frame covering the whole of a preview shaped like it: kept
/// whole.
DocumentPicture _whole(Uint8List jpeg, double aspectRatio) =>
    DocumentPicture(jpeg: jpeg, frame: const Rect.fromLTRB(0, 0, 1, 1), previewAspectRatio: aspectRatio);

Future<void> _takeAndReview(WidgetTester tester) async {
  await tester.tap(find.text('Take photo'));
  await tester.pump();
  await tester.pump();
}

Future<void> _usePhoto(WidgetTester tester) async {
  await tester.tap(find.text('Use photo'));
  await tester.pump();
  await tester.pump();
}

double _frameRatio(WidgetTester tester) => tester.widget<MRZCameraOverlay>(find.byType(MRZCameraOverlay)).frameRatio;

void main() {
  testWidgets('a card whose back the MRZ scan photographed: that back is shown first, then the front is taken, '
      'and both are sent', (tester) async {
    final camera = _FakeCamera();
    final scanned = _scannedPhoto();
    final sent = <(Uint8List, Uint8List?)>[];
    await tester.pumpWidget(
      _screen(
        camera,
        documentType: DocumentType.identityCard,
        scanned: scanned,
        onPhotosTaken: (front, back) async => sent.add((front, back)),
      ),
    );
    await tester.pump();

    // Straight to the review of the scanned back; no camera yet.
    expect(find.text('Check the photo'), findsOneWidget);
    expect(find.textContaining('photographed while the MRZ was read'), findsOneWidget);
    expect(find.text('Back · 1 of 2'), findsOneWidget);
    expect(camera.opens, 0);

    await _usePhoto(tester);

    expect(find.text('Photograph the front'), findsOneWidget);
    expect(find.text('Front · 2 of 2'), findsOneWidget);
    expect(_frameRatio(tester), MRZCameraOverlay.cardFrameRatio);

    await _takeAndReview(tester);
    expect(find.textContaining('photographed while the MRZ was read'), findsNothing);
    await _usePhoto(tester);

    expect(camera.frameRatios, [MRZCameraOverlay.cardFrameRatio]);
    expect(sent.single.$1, camera.taken.single);
    expect(sent.single.$2, scanned);
  });

  testWidgets('a passport whose photo page the MRZ scan photographed: shown, and sent as the front once used', (
    tester,
  ) async {
    final camera = _FakeCamera();
    final scanned = _scannedPhoto();
    final sent = <(Uint8List, Uint8List?)>[];
    await tester.pumpWidget(
      _screen(
        camera,
        documentType: DocumentType.passport,
        scanned: scanned,
        onPhotosTaken: (front, back) async => sent.add((front, back)),
      ),
    );
    await tester.pump();

    expect(find.textContaining('photographed while the MRZ was read'), findsOneWidget);
    expect(find.textContaining('1 of'), findsNothing);
    await _usePhoto(tester);

    expect(camera.opens, 0);
    expect(sent.single.$1, scanned);
    expect(sent.single.$2, isNull);
  });

  testWidgets('Retake on the scanned side takes that side again with the camera; back on the front returns to the '
      'scanned back', (tester) async {
    final camera = _FakeCamera();
    final scanned = _scannedPhoto();
    final sent = <(Uint8List, Uint8List?)>[];
    await tester.pumpWidget(
      _screen(
        camera,
        documentType: DocumentType.drivingLicence,
        scanned: scanned,
        onPhotosTaken: (front, back) async => sent.add((front, back)),
      ),
    );
    await tester.pump();

    await _usePhoto(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('Back · 1 of 2'), findsOneWidget);
    expect(find.textContaining('photographed while the MRZ was read'), findsOneWidget);

    await tester.tap(find.text('Retake'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Now photograph the back'), findsOneWidget);
    await _takeAndReview(tester);
    await _usePhoto(tester);
    await _takeAndReview(tester);
    await _usePhoto(tester);

    expect(sent.single.$1, camera.taken.last);
    expect(sent.single.$2, camera.taken.first);
  });

  testWidgets('a document of unknown type: front, then back in the card frame, both sent together', (tester) async {
    final camera = _FakeCamera();
    final sent = <(Uint8List, Uint8List?)>[];
    await tester.pumpWidget(_screen(camera, onPhotosTaken: (front, back) async => sent.add((front, back))));
    await tester.pump();

    expect(find.byKey(const Key('fake preview')), findsOneWidget);
    expect(find.text('2 of 3 · Document photo'), findsOneWidget);
    expect(find.text('Front · 1 of 2'), findsOneWidget);
    expect(find.text('Photograph the front'), findsOneWidget);
    expect(_frameRatio(tester), MRZCameraOverlay.cardFrameRatio);
    expect(find.text('My document has no back'), findsNothing);

    await _takeAndReview(tester);
    // The review doesn't keep the camera open.
    expect(camera.closes, 1);
    expect(find.byKey(const Key('fake preview')), findsNothing);
    expect(find.text('Check the photo'), findsOneWidget);
    expect(find.text('Front · 1 of 2'), findsOneWidget);

    await _usePhoto(tester);
    expect(sent, isEmpty);
    expect(camera.opens, 2);
    expect(find.text('Back · 2 of 2'), findsOneWidget);
    expect(find.text('Now photograph the back'), findsOneWidget);
    expect(_frameRatio(tester), MRZCameraOverlay.cardFrameRatio);
    expect(find.text('My document has no back'), findsOneWidget);

    await _takeAndReview(tester);
    expect(find.text('Back · 2 of 2'), findsOneWidget);
    await _usePhoto(tester);

    expect(sent.single.$1, camera.taken[0]);
    expect(sent.single.$2, camera.taken[1]);
  });

  testWidgets('a passport: only the front, in the passport-page frame, sent without a back', (tester) async {
    final camera = _FakeCamera();
    final sent = <(Uint8List, Uint8List?)>[];
    await tester.pumpWidget(
      _screen(camera, documentType: DocumentType.passport, onPhotosTaken: (f, b) async => sent.add((f, b))),
    );
    await tester.pump();

    expect(_frameRatio(tester), MRZCameraOverlay.passportFrameRatio);
    expect(find.textContaining('1 of 2'), findsNothing);
    expect(find.textContaining('page with your photo'), findsOneWidget);

    await _takeAndReview(tester);
    await _usePhoto(tester);

    expect(sent.single.$1, camera.taken.single);
    expect(sent.single.$2, isNull);
    expect(find.text('Now photograph the back'), findsNothing);
  });

  testWidgets('an ID card is always asked for its back: no way to skip it', (tester) async {
    final camera = _FakeCamera();
    await tester.pumpWidget(_screen(camera, documentType: DocumentType.identityCard));
    await tester.pump();
    await _takeAndReview(tester);
    await _usePhoto(tester);

    expect(find.text('Back · 2 of 2'), findsOneWidget);
    expect(find.text('My document has no back'), findsNothing);
  });

  testWidgets('a document of unknown type that has no back sends the front alone', (tester) async {
    final camera = _FakeCamera();
    final sent = <(Uint8List, Uint8List?)>[];
    await tester.pumpWidget(_screen(camera, onPhotosTaken: (f, b) async => sent.add((f, b))));
    await tester.pump();
    await _takeAndReview(tester);
    await _usePhoto(tester);

    await tester.tap(find.text('My document has no back'));
    await tester.pump();
    await tester.pump();

    expect(sent.single.$1, camera.taken.single);
    expect(sent.single.$2, isNull);
  });

  testWidgets('back on the back side returns to the front photo; on the front it leaves the step', (tester) async {
    final camera = _FakeCamera();
    var backs = 0;
    await tester.pumpWidget(_screen(camera, onBack: () => backs++));
    await tester.pump();
    await _takeAndReview(tester);
    await _usePhoto(tester);
    expect(find.text('Back · 2 of 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(backs, 0);
    expect(find.text('Check the photo'), findsOneWidget);
    expect(find.text('Front · 1 of 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    expect(backs, 1);
  });

  testWidgets('back while the next side\'s camera is still opening stays on the previous side\'s photo', (
    tester,
  ) async {
    final camera = _FakeCamera();
    await tester.pumpWidget(_screen(camera));
    await tester.pump();
    await _takeAndReview(tester);
    camera.openGate = Completer<void>();
    await _usePhoto(tester);
    expect(find.text('Back · 2 of 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    camera.openGate!.complete();
    await tester.pump();
    await tester.pump();

    // Not the camera preview the overtaken open would have switched to.
    expect(find.text('Check the photo'), findsOneWidget);
    expect(find.text('Front · 1 of 2'), findsOneWidget);
    expect(find.text('Take photo'), findsNothing);
  });

  testWidgets('back is ignored while a picture is being taken, so it lands on the side it was taken for', (
    tester,
  ) async {
    final camera = _FakeCamera();
    Uint8List? sentFront;
    Uint8List? sentBack;
    await tester.pumpWidget(
      _screen(
        camera,
        onPhotosTaken: (front, back) async {
          sentFront = front;
          sentBack = back;
        },
      ),
    );
    await tester.pump();
    await _takeAndReview(tester);
    await _usePhoto(tester);
    expect(find.text('Back · 2 of 2'), findsOneWidget);

    camera.pictureGate = Completer<void>();
    await tester.tap(find.text('Take photo'));
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    camera.pictureGate!.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('Back · 2 of 2'), findsOneWidget);
    await _usePhoto(tester);
    expect(sentFront, camera.taken[0]);
    expect(sentBack, camera.taken[1]);
  });

  testWidgets('Retake drops the photo and reopens the camera', (tester) async {
    final camera = _FakeCamera();
    await tester.pumpWidget(_screen(camera, onPhotosTaken: (_, _) async => fail('nothing is sent on a retake')));
    await tester.pump();
    await _takeAndReview(tester);

    await tester.tap(find.text('Retake'));
    await tester.pump();
    await tester.pump();

    expect(camera.opens, 2);
    expect(find.text('Check the photo'), findsNothing);
    expect(find.text('Front · 1 of 2'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
  });

  testWidgets('the photo stays on screen, buttons disabled, while it is being sent', (tester) async {
    final camera = _FakeCamera();
    final sending = Completer<void>();
    await tester.pumpWidget(
      _screen(camera, documentType: DocumentType.passport, onPhotosTaken: (_, _) => sending.future),
    );
    await tester.pump();
    await _takeAndReview(tester);
    await tester.tap(find.text('Use photo'));
    await tester.pump();

    expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Use photo')).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Retake')).onPressed, isNull);

    // A send the user gave up on leaves the photo to try again.
    sending.complete();
    await tester.pump();
    expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Use photo')).onPressed, isNotNull);
  });

  testWidgets('a camera that cannot be opened says so and offers to try again', (tester) async {
    final camera = _FakeCamera(openError: const DocumentPhotoNoCameraException());
    await tester.pumpWidget(_screen(camera));
    await tester.pump();

    expect(find.text('No camera available'), findsOneWidget);
    camera.openError = null;
    await tester.tap(find.text('Try Again'));
    await tester.pump();
    expect(find.byKey(const Key('fake preview')), findsOneWidget);
  });

  group('prepareDocumentPhoto', () {
    test('scales the long edge down to documentPhotoMaxLongEdge and re-encodes as JPEG', () {
      final picture = Uint8List.fromList(img.encodeJpg(img.Image(width: 3200, height: 2000)));
      final prepared = img.decodeJpg(prepareDocumentPhoto(_whole(picture, 3200 / 2000)))!;
      expect(prepared.width, documentPhotoMaxLongEdge);
      expect(prepared.height, 1000);
    });

    test('bakes in the EXIF orientation and drops the EXIF', () {
      final source = img.Image(width: 400, height: 200);
      source.exif.imageIfd.orientation = 6; // rotate 90° clockwise
      source.exif.imageIfd['Make'] = img.IfdValueAscii('camera maker');
      final prepared = img.decodeJpg(prepareDocumentPhoto(_whole(Uint8List.fromList(img.encodeJpg(source)), 2)))!;
      expect(prepared.width, 200);
      expect(prepared.height, 400);
      expect(prepared.exif.imageIfd.hasOrientation, isFalse);
      expect(prepared.exif.imageIfd['Make'], isNull);
    });

    test('keeps a small picture its size', () {
      final picture = Uint8List.fromList(img.encodeJpg(img.Image(width: 800, height: 600)));
      final prepared = img.decodeJpg(prepareDocumentPhoto(_whole(picture, 800 / 600)))!;
      expect(prepared.width, 800);
      expect(prepared.height, 600);
    });

    test('refuses bytes that are no JPEG', () {
      expect(() => prepareDocumentPhoto(_whole(Uint8List.fromList('not a picture'.codeUnits), 1)), throwsException);
    });

    test('cuts the picture down to the frame and its margin', () {
      // A 9:16 picture, like the preview, with the frame across the middle.
      final picture = Uint8List.fromList(img.encodeJpg(img.Image(width: 900, height: 1600)));
      final prepared = img.decodeJpg(
        prepareDocumentPhoto(
          DocumentPicture(jpeg: picture, frame: const Rect.fromLTRB(0.1, 0.4, 0.9, 0.6), previewAspectRatio: 9 / 16),
        ),
      )!;
      const m = DocumentPicture.frameMargin;
      expect(prepared.width, closeTo(900 * (0.8 + 2 * 0.8 * m), 2));
      expect(prepared.height, closeTo(1600 * (0.2 + 2 * 0.2 * m), 2));
    });
  });
}
