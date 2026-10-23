import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:idem/l10n/l10n.dart';
import 'package:idem/services/document_photo_quality.dart';
import 'package:idem/services/document_text_reader.dart';
import 'package:idem/services/document_viz.dart';
import 'package:idem/theme/app_theme.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';
import 'package:idem/widgets/pages/document_photo_screen.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/vcmrtd.dart';

class _FakeCamera implements DocumentPhotoCamera {
  _FakeCamera({this.openError});

  Object? openError;
  var opens = 0;
  var closes = 0;
  var disposes = 0;

  /// Every picture taken, each a different image.
  final taken = <Uint8List>[];

  /// When set, [open] waits for it: a camera that takes a while to open.
  Completer<void>? openGate;

  /// What the preview frames report on opening, each for as many frames as
  /// it takes to settle: readable by default, so the photo can be taken
  /// straight away.
  List<Set<DocumentPhotoIssue>> frames = const [{}];

  /// Reports a checked preview frame, like the device camera does a few
  /// times a second while it's open.
  ValueChanged<Set<DocumentPhotoIssue>>? onFrameChecked;

  /// Reports [issues] for as many frames as it takes to settle.
  void report(Set<DocumentPhotoIssue> issues) {
    for (var i = 0; i < DocumentPhotoQuality.framesToAgree; i++) {
      onFrameChecked!(issues);
    }
  }

  @override
  Future<void> open({
    required double frameRatio,
    required SideContent content,
    required ValueChanged<Set<DocumentPhotoIssue>> onFrameChecked,
  }) async {
    opens++;
    contents.add(content);
    this.onFrameChecked = onFrameChecked;
    await openGate?.future;
    if (openError != null) throw openError!;
    frames.forEach(report);
  }

  @override
  Widget buildPreview(BuildContext context) => const ColoredBox(key: Key('fake preview'), color: Colors.grey);

  /// What each open looked for, and what it was told to look for instead.
  final contents = <SideContent>[];

  /// The frame ratio of every picture taken.
  final frameRatios = <double>[];

  /// When set, [takePicture] waits for it: a picture that takes a moment.
  Completer<void>? pictureGate;

  /// When set, the photo prepared from a picture waits for it.
  Completer<void>? photoGate;

  @override
  Future<TakenPicture> takePicture({required double frameRatio}) async {
    await pictureGate?.future;
    final picture = Uint8List.fromList(img.encodeJpg(img.Image(width: 4 + taken.length, height: 3)));
    taken.add(picture);
    frameRatios.add(frameRatio);
    final gate = photoGate;
    return (
      shot: DocumentPicture(jpeg: picture, frame: const Rect.fromLTRB(0, 0, 1, 1), previewAspectRatio: 1),
      photo: gate == null ? Future.value(picture) : gate.future.then((_) => picture),
    );
  }

  @override
  Future<Uint8List> prepare(DocumentPicture picture) async => picture.jpeg;

  @override
  void lookFor(SideContent content) => contents.add(content);

  @override
  bool mrzShown = false;

  @override
  Future<void> close() async => closes++;

  @override
  Future<void> dispose() async => disposes++;
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
  Future<void> Function(Uint8List front, Uint8List back)? onPhotosTaken,
  VoidCallback? onBack,
  KnownDocument? known,
  Future<PhotoText> Function(Uint8List photo)? readPhotoText,
}) => _app(
  DocumentPhotoScreen(
    camera: camera,
    documentType: documentType,
    scanned: scanned,
    known: known,
    readPhotoText: readPhotoText ?? (_) async => (lines: const <String>[], barcodes: const <String>[]),
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

/// Lets the preview show long enough for the photo, its checks clear, to be taken by itself.
Future<void> _takeAndReview(WidgetTester tester) async {
  await tester.pump(documentPhotoMinPreview);
  await tester.pump();
  await tester.pump();
}

Future<void> _usePhoto(WidgetTester tester) async {
  await tester.tap(find.text('Use photo'));
  await tester.pump();
  await tester.pump();
}

double _frameRatio(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is GuidedScanFramePainter),
  );
  final frame = (paint.painter! as GuidedScanFramePainter).frame;
  return frame.width / frame.height;
}

void main() {
  testWidgets('a card whose back the MRZ scan photographed: that back is shown first, then the front is taken, '
      'and both are sent', (tester) async {
    final camera = _FakeCamera();
    final scanned = _scannedPhoto();
    final sent = <(Uint8List, Uint8List)>[];
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

  testWidgets('a passport whose photo page the MRZ scan photographed: shown first as the front, then its back', (
    tester,
  ) async {
    final camera = _FakeCamera();
    final scanned = _scannedPhoto();
    final sent = <(Uint8List, Uint8List)>[];
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
    expect(find.text('Front · 1 of 2'), findsOneWidget);
    await _usePhoto(tester);
    expect(camera.opens, 1);
    expect(find.text('Back · 2 of 2'), findsOneWidget);
    await _takeAndReview(tester);
    await _usePhoto(tester);

    expect(sent.single.$1, scanned);
    expect(sent.single.$2, camera.taken.single);
  });

  testWidgets('Retake on the scanned side takes that side again with the camera; back on the front returns to the '
      'scanned back', (tester) async {
    final camera = _FakeCamera();
    final scanned = _scannedPhoto();
    final sent = <(Uint8List, Uint8List)>[];
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

  testWidgets('leaving the step releases the camera for good', (tester) async {
    final camera = _FakeCamera();
    await tester.pumpWidget(_screen(camera));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());

    expect(camera.disposes, 1);
  });

  testWidgets('no text lies over the frame, on small phones too, in either language, with a hint and the way out', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    // Idem draws with the platform's font: Android's Roboto, from the Flutter
    // SDK, so the text is as wide as on a phone, not the test font's squares.
    await tester.runAsync(() async {
      final fonts = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
      final roboto = FontLoader('Roboto');
      for (final weight in ['Regular', 'Medium', 'Bold']) {
        roboto.addFont(File('$fonts/Roboto-$weight.ttf').readAsBytes().then(ByteData.sublistView));
      }
      await roboto.load();
    });
    // Galaxy S9, iPhone SE, iPhone 15: logical size, status bar, navigation bar.
    const phones = [(Size(360, 740), 24.0, 48.0), (Size(375, 667), 20.0, 0.0), (Size(390, 844), 47.0, 34.0)];
    for (final (size, top, bottom) in phones) {
      for (final locale in AppLocalizations.supportedLocales) {
        for (final type in [DocumentType.passport, DocumentType.identityCard]) {
          for (final frames in [
            const [<DocumentPhotoIssue>{}],
            const [
              {DocumentPhotoIssue.unreadable},
            ],
          ]) {
            tester.view
              ..devicePixelRatio = 3
              ..physicalSize = size * 3
              ..padding = FakeViewPadding(top: top * 3, bottom: bottom * 3)
              ..viewPadding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
            final camera = _FakeCamera()..frames = frames;
            await tester.pumpWidget(
              MaterialApp(
                theme: appTheme(),
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: DocumentPhotoScreen(
                  camera: camera,
                  documentType: type,
                  readPhotoText: (_) async => (lines: const <String>[], barcodes: const <String>[]),
                  stepNumber: 2,
                  totalSteps: 3,
                  onBack: () {},
                  onPhotosTaken: (_, _) async {},
                ),
              ),
            );
            await tester.pump();
            // An issue that stays: its hint and the way out, the tallest sheet.
            if (frames.single.isNotEmpty) await tester.pump(documentPhotoQualityWaiveDelay);

            final painter = tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate((w) => w is CustomPaint && w.painter is GuidedScanFramePainter),
                )
                .painter!;
            final frame = (painter as GuidedScanFramePainter).frame;
            final what = '$size $locale ${type.name} ${frames.single}';
            expect(tester.getRect(find.byType(GuidedStepBar)).bottom, lessThanOrEqualTo(frame.top), reason: what);
            expect(tester.getRect(find.byType(GuidedSheet)).top, greaterThanOrEqualTo(frame.bottom), reason: what);
            if (frames.single.isNotEmpty) {
              expect(find.textContaining(RegExp('text|tekst')), findsOneWidget, reason: 'the hint shows: $what');
              expect(find.byType(ElevatedButton), findsOneWidget, reason: 'the way out shows: $what');
            }
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    }
  });

  testWidgets('a document of unknown type: front, then back in the card frame, both sent together', (tester) async {
    final camera = _FakeCamera();
    final sent = <(Uint8List, Uint8List)>[];
    await tester.pumpWidget(_screen(camera, onPhotosTaken: (front, back) async => sent.add((front, back))));
    await tester.pump();

    expect(find.byKey(const Key('fake preview')), findsOneWidget);
    expect(find.text('Document photo'), findsOneWidget);
    final stepBar = tester.widget<GuidedStepBar>(find.byType(GuidedStepBar));
    expect((stepBar.step, stepBar.total), (2, 3));
    expect(find.byType(StepBadge), findsNothing);
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
    expect(find.text('My document has no back'), findsNothing);

    await _takeAndReview(tester);
    expect(find.text('Back · 2 of 2'), findsOneWidget);
    await _usePhoto(tester);

    expect(sent.single.$1, camera.taken[0]);
    expect(sent.single.$2, camera.taken[1]);
  });

  testWidgets('a passport: both sides of the photo page, each in the passport-page frame', (tester) async {
    final camera = _FakeCamera();
    final sent = <(Uint8List, Uint8List)>[];
    await tester.pumpWidget(
      _screen(camera, documentType: DocumentType.passport, onPhotosTaken: (f, b) async => sent.add((f, b))),
    );
    await tester.pump();

    expect(find.text('Front · 1 of 2'), findsOneWidget);
    expect(find.textContaining('page with your photo'), findsNothing, reason: 'the instructions are behind a tap');
    await tester.tap(find.text('Photograph the front'));
    await tester.pumpAndSettle();
    expect(find.textContaining('page with your photo'), findsOneWidget);
    await _takeAndReview(tester);
    await _usePhoto(tester);

    expect(find.text('Back · 2 of 2'), findsOneWidget);
    await tester.tap(find.text('Now photograph the back'));
    await tester.pumpAndSettle();
    expect(find.text('Now place the back of the page with your photo inside the frame.'), findsOneWidget);
    expect(find.text('My document has no back'), findsNothing);
    await _takeAndReview(tester);
    await _usePhoto(tester);

    expect(camera.frameRatios, [MRZCameraOverlay.passportFrameRatio, MRZCameraOverlay.passportFrameRatio]);
    expect(sent.single.$1, camera.taken[0]);
    expect(sent.single.$2, camera.taken[1]);
  });

  testWidgets('a back is always asked for: no way to skip it', (tester) async {
    final camera = _FakeCamera();
    await tester.pumpWidget(_screen(camera, documentType: DocumentType.identityCard));
    await tester.pump();
    await _takeAndReview(tester);
    await _usePhoto(tester);

    expect(find.text('Back · 2 of 2'), findsOneWidget);
    expect(find.text('My document has no back'), findsNothing);
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
    expect(find.byKey(const Key('fake preview')), findsNothing);
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
    await tester.pump(documentPhotoMinPreview);
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
    expect(find.byKey(const Key('fake preview')), findsOneWidget);
  });

  testWidgets('the photo stays on screen, buttons disabled, while it is being sent', (tester) async {
    final camera = _FakeCamera();
    final sending = Completer<void>();
    await tester.pumpWidget(
      _screen(camera, documentType: DocumentType.passport, onPhotosTaken: (_, _) => sending.future),
    );
    await tester.pump();
    await _takeAndReview(tester);
    await _usePhoto(tester);
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

  testWidgets('no photo is taken while the preview shows glare, a hint says why; once it is gone the photo is taken', (
    tester,
  ) async {
    final camera = _FakeCamera()
      ..frames = const [
        {DocumentPhotoIssue.glare},
      ];
    await tester.pumpWidget(_screen(camera));
    await tester.pump(documentPhotoMinPreview);

    expect(camera.taken, isEmpty);
    expect(find.text('Reflection on the document. Tilt it slightly.'), findsOneWidget);

    camera.report(const {});
    await tester.pump();
    await tester.pump();
    expect(find.text('Reflection on the document. Tilt it slightly.'), findsNothing);
    expect(camera.taken, hasLength(1));
  });

  testWidgets('the front is the side with the photo: no portrait there holds the photo back, with a hint', (
    tester,
  ) async {
    final camera = _FakeCamera()
      ..frames = const [
        {DocumentPhotoIssue.noPortrait},
      ];
    await tester.pumpWidget(_screen(camera, documentType: DocumentType.identityCard));
    await tester.pump(documentPhotoMinPreview);

    expect(camera.taken, isEmpty);
    expect(find.text('Place the side with your photo inside the frame.'), findsOneWidget);

    camera.report(const {});
    await tester.pump();
    expect(camera.taken, hasLength(1));
  });

  testWidgets('no MRZ on the side that has one holds the photo back, with a hint', (tester) async {
    final camera = _FakeCamera()
      ..frames = const [
        {DocumentPhotoIssue.noMrz},
      ];
    await tester.pumpWidget(_screen(camera, documentType: DocumentType.passport));
    await tester.pump(documentPhotoMinPreview);

    expect(camera.taken, isEmpty);
    expect(find.text('Place the side with the machine-readable lines (<<<) inside the frame.'), findsOneWidget);
  });

  group('each side is looked for by what it shows', () {
    Future<List<SideContent>> contentsFor(
      WidgetTester tester,
      DocumentType? type, {
      List<String> frontText = const [],
      _FakeCamera? camera,
    }) async {
      camera ??= _FakeCamera();
      await tester.pumpWidget(
        _screen(camera, documentType: type, readPhotoText: (_) async => (lines: frontText, barcodes: const <String>[])),
      );
      await tester.pump();
      await _takeAndReview(tester);
      await _usePhoto(tester);
      return camera.contents;
    }

    testWidgets('a passport: portrait and MRZ on the photo page, neither on its back', (tester) async {
      expect(await contentsFor(tester, DocumentType.passport), [
        (portrait: true, mrz: true),
        (portrait: false, mrz: false),
      ]);
    });

    testWidgets('an identity card: portrait on the front, MRZ on the back', (tester) async {
      expect(await contentsFor(tester, DocumentType.identityCard), [
        (portrait: true, mrz: false),
        (portrait: false, mrz: true),
      ]);
    });

    testWidgets('a residence permit, a card like an identity card: portrait on the front, MRZ on the back', (
      tester,
    ) async {
      expect(await contentsFor(tester, DocumentType.residencePermit), [
        (portrait: true, mrz: false),
        (portrait: false, mrz: true),
      ]);
    });

    testWidgets("an identity card whose front's photo showed the MRZ: none looked for on its back", (tester) async {
      final contents = await contentsFor(
        tester,
        DocumentType.identityCard,
        frontText: const ['I<UTOD231458907<<<<<<<<<<<<<<<', '7408122F1204159UTO<<<<<<<<<<<6'],
      );

      expect(contents.last, (portrait: false, mrz: false));
    });

    testWidgets("an identity card whose front's preview showed the MRZ, unreadable on its photo: none looked for on "
        'its back', (tester) async {
      final contents = await contentsFor(tester, DocumentType.identityCard, camera: _FakeCamera()..mrzShown = true);

      expect(contents.last, (portrait: false, mrz: false));
    });

    testWidgets('a driving licence, most without an MRZ: only the portrait', (tester) async {
      expect(await contentsFor(tester, DocumentType.drivingLicence), [
        (portrait: true, mrz: false),
        (portrait: false, mrz: false),
      ]);
    });

    testWidgets('a document of unknown type: only the portrait', (tester) async {
      expect(await contentsFor(tester, null), [(portrait: true, mrz: false), (portrait: false, mrz: false)]);
    });
  });

  testWidgets('the picture shows at once; retake, use and its text only once its photo is ready', (tester) async {
    final camera = _FakeCamera()..photoGate = Completer();
    final read = <Uint8List>[];
    await tester.pumpWidget(
      _screen(
        camera,
        readPhotoText: (photo) async {
          read.add(photo);
          return (lines: const <String>[], barcodes: const <String>[]);
        },
      ),
    );
    await tester.pump();

    await _takeAndReview(tester);
    expect(find.text('Check the photo'), findsOneWidget);
    expect(find.text('Preparing the photo…'), findsOneWidget);
    expect(find.text('Retake'), findsNothing);
    expect(find.text('Use photo'), findsNothing);
    expect(find.byType(Image), findsNothing, reason: 'the picture is drawn cut to the frame, not the photo sent');
    expect(read, isEmpty, reason: 'the text is read off the photo that is sent');

    camera.photoGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Preparing the photo…'), findsNothing);
    expect(find.text('Retake'), findsOneWidget);
    expect(find.text('Use photo'), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
    expect(read, [camera.taken.single]);
  });

  testWidgets("the last side's review compares the text on both sides with the document the MRZ scan read", (
    tester,
  ) async {
    final camera = _FakeCamera();
    final scanned = _scannedPhoto();
    final read = <Uint8List>[];
    await tester.pumpWidget(
      _screen(
        camera,
        documentType: DocumentType.identityCard,
        scanned: scanned,
        known: (documentNumber: 'D23145890', dateOfBirth: DateTime(1974, 8, 12), dateOfExpiry: DateTime(2012, 4, 15)),
        readPhotoText: (photo) async {
          read.add(photo);
          final lines = identical(photo, scanned)
              ? const [
                  'I<UTOD231458907<<<<<<<<<<<<<<<',
                  '7408122F1204159UTO<<<<<<<<<<<6',
                  'ERIKSSON<<ANNA<MARIA<<<<<<<<<<',
                ]
              : const ['Documentnummer', 'D23145890', '12 AUG/AUG 1974', '15.04.2012'];
          return (lines: lines, barcodes: const <String>[]);
        },
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('viz check')), findsNothing);

    await _usePhoto(tester);
    await _takeAndReview(tester);
    await tester.pump();

    expect(read, [scanned, camera.taken.single]);
    expect(debugVizCheck.value?.match, SidesMatch.same);
    expect(debugVizCheck.value?.frontLooksLikeDocument, isTrue);
    expect(find.textContaining('Sides: same'), findsOneWidget);
  });

  testWidgets('a photo whose text cannot be read leaves the sides unknown', (tester) async {
    final camera = _FakeCamera();
    await tester.pumpWidget(_screen(camera, readPhotoText: (_) async => throw Exception('no recognizer')));
    await tester.pump();

    await _takeAndReview(tester);
    await _usePhoto(tester);
    await _takeAndReview(tester);
    await tester.pump();

    expect(debugVizCheck.value?.match, SidesMatch.unknown);
  });

  testWidgets('the hint follows the issue the preview frames agree on', (tester) async {
    final camera = _FakeCamera()
      ..frames = const [
        {DocumentPhotoIssue.tooDark},
      ];
    await tester.pumpWidget(_screen(camera));
    await tester.pump();
    expect(find.text('Too dark. Move to a place with more light.'), findsOneWidget);

    camera.report({DocumentPhotoIssue.blurry});
    await tester.pump(documentPhotoMinPreview);
    expect(find.text('Not sharp yet. Hold your phone still.'), findsOneWidget);
    expect(camera.taken, isEmpty);
  });

  testWidgets('the photo is taken by itself once every check is clear, after the preview showed a moment; '
      'its review leads with use', (tester) async {
    final camera = _FakeCamera();
    await tester.pumpWidget(_screen(camera));
    await tester.pump();
    expect(find.text('Hold still…'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing, reason: 'no button to tap, and shake the phone with');

    await tester.pump(documentPhotoMinPreview - const Duration(milliseconds: 1));
    expect(camera.taken, isEmpty, reason: 'the document can still be set right');
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump();

    expect(camera.taken, hasLength(1));
    expect(find.text('Are all details sharp and readable, without glare or anything covering them?'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Use photo'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retake'), findsOneWidget);
  });

  testWidgets('the photo can be taken anyway once the preview showed for a while, so the session never gets stuck; '
      'its review says what the checks saw and leads with retake', (tester) async {
    final camera = _FakeCamera()
      ..frames = const [
        {DocumentPhotoIssue.blurry},
      ];
    await tester.pumpWidget(_screen(camera));
    await tester.pump();
    expect(find.text('Take photo anyway'), findsNothing);

    await tester.pump(documentPhotoQualityWaiveDelay);
    expect(camera.taken, isEmpty, reason: 'not by itself');
    // Still says what the frames show.
    expect(find.text('Not sharp yet. Hold your phone still.'), findsOneWidget);

    await tester.tap(find.text('Take photo anyway'));
    await tester.pump();
    await tester.pump();
    expect(camera.taken, hasLength(1));
    expect(find.text('Check the photo'), findsOneWidget);
    expect(find.textContaining("didn't pass the checks"), findsOneWidget);
    expect(find.text('Not sharp yet. Hold your phone still.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Retake'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Use photo'), findsOneWidget);

    // The retake the checks pass is an ordinary one.
    camera.frames = const [{}];
    await tester.tap(find.text('Retake'));
    await tester.pump();
    await tester.pump();
    await _takeAndReview(tester);
    expect(find.textContaining("didn't pass the checks"), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Use photo'), findsOneWidget);
  });

  testWidgets('no photo is taken by itself while any issue stays', (tester) async {
    final camera = _FakeCamera()
      ..frames = const [
        {DocumentPhotoIssue.blurry},
      ];
    await tester.pumpWidget(_screen(camera));
    await tester.pump();
    for (final issue in DocumentPhotoIssue.values) {
      camera.report({issue});
      await tester.pump(documentPhotoMinPreview);
      expect(camera.taken, isEmpty, reason: '$issue');
    }
  });

  testWidgets('a reopened camera checks its frames afresh', (tester) async {
    final camera = _FakeCamera();
    await tester.pumpWidget(_screen(camera));
    await tester.pump();
    await _takeAndReview(tester);

    camera.frames = const [
      {DocumentPhotoIssue.glare},
    ];
    await tester.tap(find.text('Retake'));
    await tester.pump();
    await tester.pump();
    await tester.pump(documentPhotoMinPreview);
    expect(camera.taken, hasLength(1));
    expect(find.text('Reflection on the document. Tilt it slightly.'), findsOneWidget);
  });

  testWidgets('a moment without focus leaves the preview and its waiting be; back from the background reopens it', (
    tester,
  ) async {
    final camera = _FakeCamera()
      ..frames = const [
        {DocumentPhotoIssue.blurry},
      ];
    await tester.pumpWidget(_screen(camera));
    await tester.pump();

    // The control center or the notification shade: inactive, then back.
    await tester.pump(documentPhotoQualityWaiveDelay - const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(camera.opens, 1);
    expect(find.text('Take photo anyway'), findsOneWidget);

    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(camera.closes, 1);
    for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(camera.opens, 2);
    expect(find.text('Take photo anyway'), findsNothing, reason: 'a reopened camera checks its frames afresh');
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

  group('streamFrameRotation', () {
    const back = CameraDescription(name: 'back', lensDirection: CameraLensDirection.back, sensorOrientation: 90);
    const front = CameraDescription(name: 'front', lensDirection: CameraLensDirection.front, sensorOrientation: 270);

    test('turns a back camera\'s frame by its sensor orientation less the device\'s', () {
      expect(streamFrameRotation(back, DeviceOrientation.portraitUp, TargetPlatform.android), 90);
      expect(streamFrameRotation(back, DeviceOrientation.landscapeLeft, TargetPlatform.android), 0);
      expect(streamFrameRotation(back, DeviceOrientation.portraitDown, TargetPlatform.android), 270);
      expect(streamFrameRotation(back, DeviceOrientation.landscapeRight, TargetPlatform.android), 180);
    });

    test('turns a front camera\'s frame by its sensor orientation plus the device\'s', () {
      expect(streamFrameRotation(front, DeviceOrientation.portraitUp, TargetPlatform.android), 270);
      expect(streamFrameRotation(front, DeviceOrientation.landscapeLeft, TargetPlatform.android), 0);
    });

    test('leaves iOS frames as they are', () {
      expect(streamFrameRotation(back, DeviceOrientation.landscapeLeft, TargetPlatform.iOS), 0);
    });
  });
}
