import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:idem/l10n/l10n.dart';
import 'package:idem/services/document_photo_quality.dart';
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
  Future<List<String>> Function(Uint8List photo)? readPhotoText,
}) => _app(
  DocumentPhotoScreen(
    camera: camera,
    documentType: documentType,
    scanned: scanned,
    readPhotoText: readPhotoText ?? (_) async => const <String>[],
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

bool _takePhotoEnabled(WidgetTester tester) => tester
    .widget<ElevatedButton>(
      find.ancestor(of: find.text('Take photo'), matching: find.byWidgetPredicate((w) => w is ElevatedButton)),
    )
    .enabled;

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

  testWidgets('no text lies over the frame, on small phones too, in either language, with or without a hint', (
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
                  readPhotoText: (_) async => const <String>[],
                  stepNumber: 2,
                  totalSteps: 3,
                  onBack: () {},
                  onPhotosTaken: (_, _) async {},
                ),
              ),
            );
            await tester.pump();

            final painter = tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate((w) => w is CustomPaint && w.painter is GuidedScanFramePainter),
                )
                .painter!;
            final frame = (painter as GuidedScanFramePainter).frame;
            final sheet = find.ancestor(
              of: find.byType(ElevatedButton),
              matching: find.byWidgetPredicate((w) => w is Material && w.color == Colors.white),
            );
            final what = '$size $locale ${type.name} ${frames.single}';
            expect(tester.getRect(find.byType(GuidedStepBar)).bottom, lessThanOrEqualTo(frame.top), reason: what);
            expect(tester.getRect(sheet).top, greaterThanOrEqualTo(frame.bottom), reason: what);
            if (frames.single.isNotEmpty) {
              expect(find.textContaining(RegExp('text|tekst')), findsOneWidget, reason: 'the hint shows: $what');
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

  testWidgets('the photo cannot be taken while the preview shows the document unreadable; a hint says why', (
    tester,
  ) async {
    final camera = _FakeCamera()
      ..frames = const [
        {DocumentPhotoIssue.glare},
      ];
    await tester.pumpWidget(_screen(camera));
    await tester.pump();

    expect(_takePhotoEnabled(tester), isFalse);
    expect(find.text('Reflection on the document. Tilt it slightly.'), findsOneWidget);

    camera.report(const {});
    await tester.pump();
    expect(_takePhotoEnabled(tester), isTrue);
    expect(find.text('Reflection on the document. Tilt it slightly.'), findsNothing);
  });

  testWidgets('the front is the side with the photo: no portrait there holds the photo back, with a hint', (
    tester,
  ) async {
    final camera = _FakeCamera()
      ..frames = const [
        {DocumentPhotoIssue.noPortrait},
      ];
    await tester.pumpWidget(_screen(camera, documentType: DocumentType.identityCard));
    await tester.pump();

    expect(_takePhotoEnabled(tester), isFalse);
    expect(find.text('Place the side with your photo inside the frame.'), findsOneWidget);

    camera.report(const {});
    await tester.pump();
    expect(_takePhotoEnabled(tester), isTrue);
  });

  testWidgets('no MRZ on the side that has one holds the photo back, with a hint', (tester) async {
    final camera = _FakeCamera()
      ..frames = const [
        {DocumentPhotoIssue.noMrz},
      ];
    await tester.pumpWidget(_screen(camera, documentType: DocumentType.passport));
    await tester.pump();

    expect(_takePhotoEnabled(tester), isFalse);
    expect(find.text('Place the side with the machine-readable lines (<<<) inside the frame.'), findsOneWidget);
  });

  group('each side is looked for by what it shows', () {
    Future<List<SideContent>> contentsFor(
      WidgetTester tester,
      DocumentType? type, {
      List<String> frontText = const [],
      bool frontPreviewShowsMrz = false,
    }) async {
      final camera = _FakeCamera()..mrzShown = frontPreviewShowsMrz;
      await tester.pumpWidget(_screen(camera, documentType: type, readPhotoText: (_) async => frontText));
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
      final contents = await contentsFor(tester, DocumentType.identityCard, frontPreviewShowsMrz: true);

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
          return const <String>[];
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

  testWidgets('the hint follows the issue the preview frames agree on', (tester) async {
    final camera = _FakeCamera()
      ..frames = const [
        {DocumentPhotoIssue.tooDark},
      ];
    await tester.pumpWidget(_screen(camera));
    await tester.pump();
    expect(find.text('Too dark. Move to a place with more light.'), findsOneWidget);

    camera.report({DocumentPhotoIssue.blurry});
    await tester.pump();
    expect(find.text('Not sharp yet. Hold your phone still.'), findsOneWidget);
    expect(_takePhotoEnabled(tester), isFalse);
  });

  testWidgets('the photo can be taken anyway once the preview showed for a while, so the session never gets stuck', (
    tester,
  ) async {
    final camera = _FakeCamera()
      ..frames = const [
        {DocumentPhotoIssue.blurry},
      ];
    await tester.pumpWidget(_screen(camera));
    await tester.pump();
    expect(_takePhotoEnabled(tester), isFalse);

    await tester.pump(documentPhotoQualityWaiveDelay);
    expect(_takePhotoEnabled(tester), isTrue);
    // Still says what the frames show.
    expect(find.text('Not sharp yet. Hold your phone still.'), findsOneWidget);

    await _takeAndReview(tester);
    expect(find.text('Check the photo'), findsOneWidget);
  });

  testWidgets('the photo cannot be taken while any issue stays, until the preview showed for a while', (tester) async {
    final camera = _FakeCamera();
    await tester.pumpWidget(_screen(camera));
    await tester.pump();
    for (final issue in DocumentPhotoIssue.values) {
      camera.report({issue});
      await tester.pump();
      expect(_takePhotoEnabled(tester), isFalse, reason: '$issue');
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
    expect(_takePhotoEnabled(tester), isFalse);
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
