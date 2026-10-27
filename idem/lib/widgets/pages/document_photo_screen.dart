import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/services/document_photo_quality.dart';
import 'package:idem/services/document_portrait.dart';
import 'package:idem/services/document_text_reader.dart';
import 'package:idem/services/document_viz.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';
import 'package:vcmrtd/vcmrtd.dart';

/// The longest side of the photo the document_photo step sends: sharp
/// enough to read the printed data page, small enough to stay far below the
/// server's request body limit once base64-encoded.
const documentPhotoMaxLongEdge = 1600;
const documentPhotoJpegQuality = 85;

/// Turns the camera's picture into what the document_photo step sends: an
/// upright JPEG of the document frame and a margin around it (never the rest
/// of the camera's view), no longer than [documentPhotoMaxLongEdge] on its
/// longest side, without the camera's EXIF (location, device) - the relying
/// party gets this image as it is.
Uint8List prepareDocumentPhoto(DocumentPicture picture) => _encode(_sized(_uprightDocument(picture)));

/// [prepareDocumentPhoto], and the brightness of the same pixels for reading
/// the text on them.
({Uint8List jpeg, GreyPhoto grey}) _prepareWithGrey(DocumentPicture picture) {
  final sized = _sized(_uprightDocument(picture));
  return (jpeg: _encode(sized), grey: greyPhoto(sized));
}

img.Image _uprightDocument(DocumentPicture picture) {
  // The camera plugin takes its pictures as JPEG on both platforms.
  final decoded = img.decodeJpg(picture.jpeg);
  if (decoded == null) throw const FormatException('the camera returned no readable JPEG');
  final oriented = img.bakeOrientation(decoded);
  final crop = picture.cropIn(oriented.width, oriented.height);
  final upright = img.copyCrop(
    oriented,
    x: crop.left.toInt(),
    y: crop.top.toInt(),
    width: crop.width.toInt(),
    height: crop.height.toInt(),
  );
  return upright;
}

img.Image _sized(img.Image upright) => _fitLongEdge(upright, documentPhotoMaxLongEdge);

Uint8List _encode(img.Image sized) {
  sized.exif = img.ExifData();
  return img.encodeJpg(sized, quality: documentPhotoJpegQuality);
}

/// Scales [image] down so its longer side is at most [maxLongEdge]; returns
/// it unchanged when it already fits.
img.Image _fitLongEdge(img.Image image, int maxLongEdge) {
  if (math.max(image.width, image.height) <= maxLongEdge) return image;
  if (image.width >= image.height) {
    return img.copyResize(image, width: maxLongEdge, interpolation: img.Interpolation.average);
  }
  return img.copyResize(image, height: maxLongEdge, interpolation: img.Interpolation.average);
}

/// [prepareDocumentPhoto] off the UI isolate: decoding a full-resolution
/// picture takes a while. Its grey copy goes to the text reading, which then
/// doesn't decode the photo again.
Future<Uint8List> preparePhotoInBackground(DocumentPicture picture) async {
  final prepared = await compute(_prepareWithGrey, picture);
  rememberGrey(prepared.jpeg, prepared.grey);
  return prepared.jpeg;
}

final _vizLog = Logger('DocumentViz');

/// What the text on both sides said, shown on the last side's review in
/// debug builds while the comparison is tuned.
final debugVizCheck = ValueNotifier<VizCheck?>(null);

const _deviceRotations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// The clockwise degrees that turn a preview frame from [camera] upright.
/// iOS turns stream frames to the device's orientation itself, and ML Kit
/// there ignores the rotation it's given.
@visibleForTesting
int streamFrameRotation(CameraDescription camera, DeviceOrientation deviceOrientation, TargetPlatform platform) {
  if (platform == TargetPlatform.iOS) return 0;
  final deviceRotation = _deviceRotations[deviceOrientation] ?? 0;
  return camera.lensDirection == CameraLensDirection.front
      ? (camera.sensorOrientation + deviceRotation) % 360
      : (camera.sensorOrientation - deviceRotation + 360) % 360;
}

/// The camera the document photo is taken with: the device's back camera,
/// or a fake in tests.
abstract class DocumentPhotoCamera {
  /// Opens the camera; throws when there is none or it can't be opened.
  /// [content]: what the side shows, looked for in the preview.
  Future<void> open({
    required double frameRatio,
    required SideContent content,
    required ValueChanged<Set<DocumentPhotoIssue>> onFrameChecked,
  });

  /// The live preview, once [open] completed.
  Widget buildPreview(BuildContext context);

  /// Looks for [content] from now on instead of what [open] was given.
  void lookFor(SideContent content);

  /// Whether most of the latest preview frames showed an MRZ's lines, on
  /// any side: a card can have its MRZ on the front (ICAO TD2) or the back (TD1).
  bool get mrzShown;

  /// Takes a picture: the camera's own, to show at once, and the photo
  /// prepared for sending from it ([prepareDocumentPhoto]), cut to the frame
  /// of [frameRatio] drawn over the preview - ready once the camera is
  /// released, which it is once the picture is taken.
  Future<TakenPicture> takePicture({required double frameRatio});

  /// Prepares a picture another camera took (the MRZ scanner's) for sending,
  /// like [takePicture] prepares its own.
  Future<Uint8List> prepare(DocumentPicture picture);

  /// Releases the camera; [open] may be called again afterwards.
  Future<void> close();

  /// [close], and releases what the camera kept for the next [open].
  Future<void> dispose();
}

/// What [DocumentPhotoCamera.takePicture] took.
typedef TakenPicture = ({DocumentPicture shot, Future<Uint8List> photo});

final _cameraLog = Logger('DocumentPhotoCamera');

/// [DocumentPhotoCamera] on the device's back camera.
class DeviceDocumentPhotoCamera implements DocumentPhotoCamera {
  CameraController? _controller;

  /// The camera the preview shows: cleared as soon as [close] starts, so the
  /// preview is off the screen before its camera is released - a preview
  /// redrawn on a released camera throws.
  final _shown = ValueNotifier<CameraController?>(null);

  /// Bumped by every [open] and [close], so an open that a later call
  /// overtook while the camera initialized releases what it opened.
  var _generation = 0;

  /// The size the preview was last laid out at: where the frame is drawn.
  Size? _viewSize;

  double _frameRatio = MRZCameraOverlay.cardFrameRatio;
  SideContent _content = (portrait: false, mrz: false);
  ValueChanged<Set<DocumentPhotoIssue>>? _onFrameChecked;

  /// Started by the first [open] and kept until [dispose]: its isolates and
  /// face models take a while to start.
  Future<DocumentFrameChecker>? _checkerStart;
  DocumentFrameChecker? _checker;

  /// The last [close]: the next [open] waits for it to release the camera.
  Future<void>? _closing;

  /// Null until the portrait checker has looked at a frame of this side.
  bool? _portraitInPlace;

  final _mrzSightings = MrzSightings();

  DocumentTextReader? _textReader;

  /// Text recognition is slower than a frame: one read at a time, frames use the latest lines.
  var _reading = false;
  List<Rect>? _lines;

  @override
  Future<void> open({
    required double frameRatio,
    required SideContent content,
    required ValueChanged<Set<DocumentPhotoIssue>> onFrameChecked,
  }) async {
    _frameRatio = frameRatio;
    _content = content;
    _portraitInPlace = null;
    _mrzSightings.reset();
    _onFrameChecked = onFrameChecked;

    final open = _controller;
    if (open != null) {
      // Still open after a picture that failed: its preview frames stopped.
      if (!open.value.isStreamingImages) await open.startImageStream(_checkFrame);
      return;
    }

    final generation = ++_generation;
    await _closing;
    if (generation != _generation) return;
    final cameras = await availableCameras();
    if (generation != _generation) return;
    if (cameras.isEmpty) throw const DocumentPhotoNoCameraException();
    final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
    final controller = CameraController(
      back,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );
    try {
      final checker = _startChecker().then<DocumentFrameChecker?>(
        (started) => started,
        onError: (Object e) {
          _cameraLog.warning('no frame checks, the checker did not start: $e');
          return null;
        },
      );
      await Future.wait([controller.initialize(), checker]);
      if (generation == _generation) {
        _checker = await checker;
        await controller.startImageStream(_checkFrame);
      }
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
    if (generation != _generation) {
      await controller.dispose();
      return;
    }
    _controller = controller;
    _shown.value = controller;
  }

  /// The checker [open] started before, unless it stopped; a start that
  /// failed is tried again. Without the face models it still checks the
  /// rest.
  Future<DocumentFrameChecker> _startChecker() {
    final started = _checkerStart;
    if (started != null && _checker?.stopped != true) return started;
    _checker = null;
    return _checkerStart =
        () async {
          final models = await loadFaceModels().then<FaceModels?>(
            (models) => models,
            onError: (Object e) {
              _cameraLog.warning('no portrait check, the face models did not load: $e');
              return null;
            },
          );
          return DocumentFrameChecker.start(faceModels: models);
        }().catchError((Object e) {
          _checkerStart = null;
          throw e;
        });
  }

  void _checkFrame(CameraImage image) {
    final controller = _controller;
    final viewSize = _viewSize;
    final checker = _checker;
    final onFrameChecked = _onFrameChecked;
    if (controller == null || checker == null || viewSize == null || onFrameChecked == null || image.planes.isEmpty) {
      return;
    }

    final rotation = streamFrameRotation(
      controller.description,
      controller.value.deviceOrientation,
      defaultTargetPlatform,
    );
    final frame = _lumaFrame(image);
    final region = DocumentPicture.frameInPreview(
      MRZCameraOverlay.frameRect(viewSize, _frameRatio),
      _previewRect(viewSize, controller.value.aspectRatio),
    );
    final generation = _generation;
    final content = _content;
    final lookForPortrait = content.portrait && checker.portraitFree;
    // Until the text is read the issues can't be reported, but the portrait can be looked for.
    final checkFrame = !checker.busy && (_lines != null || lookForPortrait);
    if (_reading && !checkFrame) return;
    if (!_reading) _readText(frame, rotation: rotation);
    if (!checkFrame) return;

    final check = checker.check(
      frame,
      rotation: rotation,
      region: region,
      text: _lines ?? const [],
      portraitLookup: lookForPortrait ? PortraitLookup.find : PortraitLookup.skip,
    );
    unawaited(
      check.portrait?.then((portrait) {
        if (generation == _generation) _portraitInPlace = portraitInPlace(portrait);
      }, onError: (_) {}),
    );

    unawaited(
      check.issues.then((frameIssues) {
        final lines = _lines;
        if (generation != _generation || _onFrameChecked != onFrameChecked || lines == null) return;
        _mrzSightings.add(shown: mrzLayout(lines, region));
        onFrameChecked(_withContentIssues(frameIssues, lines, region, content));
      }, onError: (_) {}),
    );
  }

  /// The camera's first plane: brightness on Android, BGRA on iOS.
  static LumaFrame _lumaFrame(CameraImage image) {
    final plane = image.planes.first;
    return Platform.isAndroid
        ? LumaFrame.luma(bytes: plane.bytes, width: image.width, height: image.height, bytesPerRow: plane.bytesPerRow)
        : LumaFrame.bgra(bytes: plane.bytes, width: image.width, height: image.height, bytesPerRow: plane.bytesPerRow);
  }

  /// [issues] plus what the text [lines] and the portrait say about [content].
  Set<DocumentPhotoIssue> _withContentIssues(
    Set<DocumentPhotoIssue> issues,
    List<Rect> lines,
    Rect region,
    SideContent content,
  ) {
    var result = issues;
    if (!textReadable(lines, region)) result = withUnreadable(result);
    if (content.mrz && !mrzLayout(lines, region)) result = withoutMrz(result);
    if (content.portrait && _portraitInPlace == false) result = withoutPortrait(result);
    return result;
  }

  void _readText(LumaFrame frame, {required int rotation}) {
    final generation = _generation;
    _reading = true;
    unawaited(
      (_textReader ??= DocumentTextReader())
          .lines(frame, rotation: rotation)
          // A failed read counts as no text, so the other checks still run.
          .catchError((_) => const <Rect>[])
          .then((lines) {
            if (generation == _generation) _lines = lines;
          })
          .whenComplete(() {
            if (generation == _generation) _reading = false;
          }),
    );
  }

  @override
  Widget buildPreview(BuildContext context) => ValueListenableBuilder(
    valueListenable: _shown,
    builder: (context, controller, _) {
      if (controller == null || !controller.value.isInitialized) return const ColoredBox(color: Colors.black);
      // Fills the screen, cropping the preview's overflow like the MRZ scanner.
      return LayoutBuilder(
        builder: (context, constraints) {
          _viewSize = constraints.biggest;
          var scale = (constraints.maxWidth / constraints.maxHeight) * controller.value.aspectRatio;
          if (scale < 1) scale = 1 / scale;
          return ClipRect(
            child: Transform.scale(
              scale: scale,
              child: Center(child: CameraPreview(controller)),
            ),
          );
        },
      );
    },
  );

  @override
  Future<TakenPicture> takePicture({required double frameRatio}) async {
    final controller = _controller;
    final viewSize = _viewSize;
    if (controller == null || viewSize == null) throw StateError('camera not open');
    // Not every platform takes a picture while it streams preview frames.
    if (controller.value.isStreamingImages) await controller.stopImageStream();
    final file = await controller.takePicture();
    final frame = DocumentPicture.frameInPreview(
      MRZCameraOverlay.frameRect(viewSize, frameRatio),
      _previewRect(viewSize, controller.value.aspectRatio),
    );
    final previewAspectRatio = _uprightAspectRatio(viewSize, controller.value.aspectRatio);
    // Preparing a full-resolution picture takes a while and much memory: the camera isn't kept open for it.
    final closing = close();
    final DocumentPicture shot;
    try {
      shot = DocumentPicture(
        jpeg: await readAndDeletePicture(file),
        frame: frame,
        previewAspectRatio: previewAspectRatio,
      );
    } catch (_) {
      await closing;
      rethrow;
    }

    final photo = preparePhotoInBackground(shot);
    return (shot: shot, photo: photo.whenComplete(() => closing));
  }

  @override
  void lookFor(SideContent content) => _content = content;

  @override
  bool get mrzShown => _mrzSightings.shown;

  @override
  Future<Uint8List> prepare(DocumentPicture picture) => preparePhotoInBackground(picture);

  /// The preview's width / height as drawn: the camera's (landscape)
  /// [aspectRatio] turned upright in a portrait view.
  static double _uprightAspectRatio(Size view, double aspectRatio) =>
      view.height > view.width ? 1 / aspectRatio : aspectRatio;

  /// Where [buildPreview] draws the preview in a view of [view]: fitted
  /// into it, then scaled about the centre until it covers it.
  static Rect _previewRect(Size view, double aspectRatio) {
    final ratio = _uprightAspectRatio(view, aspectRatio);
    final fitted = view.width / view.height > ratio
        ? Size(view.height * ratio, view.height)
        : Size(view.width, view.width / ratio);
    final scale = math.max(view.width / fitted.width, view.height / fitted.height);
    return Rect.fromCenter(
      center: view.center(Offset.zero),
      width: fitted.width * scale,
      height: fitted.height * scale,
    );
  }

  @override
  Future<void> close() {
    _generation++;
    _onFrameChecked = null;
    final controller = _controller;
    _controller = null;
    _shown.value = null;
    final textReader = _textReader;
    _textReader = null;
    _reading = false;
    _lines = null;

    final previous = _closing;
    return _closing = () async {
      await previous;
      // Disposing the camera doesn't stop its preview frames: their subscription would outlive it.
      try {
        if (controller != null && controller.value.isStreamingImages) await controller.stopImageStream();
      } catch (e) {
        _cameraLog.warning('the preview frames did not stop: $e');
      }
      try {
        await controller?.dispose();
        await textReader?.close();
      } catch (e) {
        _cameraLog.warning('the camera was not released: $e');
      }
    }();
  }

  @override
  Future<void> dispose() async {
    final checker = _checkerStart;
    _checkerStart = null;
    _checker = null;
    await close();
    try {
      (await checker)?.close();
    } catch (_) {
      // It never started: nothing to release.
    }
  }
}

/// The device has no camera at all.
class DocumentPhotoNoCameraException implements Exception {
  const DocumentPhotoNoCameraException();
}

enum _PhotoState { opening, preview, capturing, review, error }

/// The preview shows at least this long before the photo is taken by itself,
/// so the document can still be set right after the camera opens.
const documentPhotoMinPreview = Duration(seconds: 1);

/// After this the photo can be taken whatever the checks say, so the session
/// never gets stuck; its review then asks for a retake first.
const documentPhotoQualityWaiveDelay = Duration(seconds: 20);

/// Which side of the document is being photographed.
enum DocumentPhotoSide { front, back }

/// The document_photo step: the user photographs the front of their
/// document and its back (a passport's photo page and the back of that
/// page), each inside a document-shaped guide, taken by itself once the checks
/// on the preview are clear, then retaken or used. A side the MRZ scan already
/// photographed ([scanned]) comes first, straight to its review: the user
/// always sees what is sent. [onPhotosTaken] gets both prepared JPEGs and
/// sends them; while it runs the last photo stays on screen, so a send the
/// user gave up on can simply be tried again.
class DocumentPhotoScreen extends StatefulWidget {
  const DocumentPhotoScreen({
    super.key,
    required this.onBack,
    required this.onPhotosTaken,
    required this.stepNumber,
    required this.totalSteps,
    this.documentType,
    this.scanned,
    this.known,
    this.camera,
    this.readPhotoText,
  });

  final VoidCallback onBack;
  final Future<void> Function(Uint8List front, Uint8List back) onPhotosTaken;
  final int stepNumber;
  final int totalSteps;

  /// The document this device already knows the user holds (from the MRZ
  /// scan or the chip read), null when it doesn't: then it gets the card frame.
  final DocumentType? documentType;

  /// The side the MRZ is on, photographed as the MRZ was read: a passport's
  /// photo page (its front), a card's back. Needs [documentType] to say which.
  final Uint8List? scanned;

  /// What the MRZ scan or chip read says the document is: both sides' text
  /// is checked against it.
  final KnownDocument? known;

  /// The device's back camera when null.
  final DocumentPhotoCamera? camera;

  /// The text and barcodes on a photo; ML Kit's when null.
  final Future<PhotoText> Function(Uint8List photo)? readPhotoText;

  @override
  State<DocumentPhotoScreen> createState() => _DocumentPhotoScreenState();
}

class _DocumentPhotoScreenState extends State<DocumentPhotoScreen> with WidgetsBindingObserver {
  late final DocumentPhotoCamera _camera = widget.camera ?? DeviceDocumentPhotoCamera();
  var _state = _PhotoState.opening;

  /// The sides asked for, in order: the scanned side first (a passport's
  /// front, a card's back), otherwise front, then back.
  late final List<DocumentPhotoSide> _sides = _sidesToCapture();
  var _index = 0;
  final _taken = <DocumentPhotoSide, Uint8List>{};
  Uint8List? _photo;

  /// The picture just taken, shown on the review until its [_photo] is prepared.
  DocumentPicture? _shot;
  String? _error;
  var _sending = false;

  final _quality = DocumentPhotoQuality();

  DocumentTextReader? _photoTextReader;
  final _sideTexts = Map<Uint8List, Future<SideText?>>.identity();

  /// The photos whose preview showed the MRZ ([DocumentPhotoCamera.mrzShown]).
  final _mrzPreviewed = Set<Uint8List>.identity();

  /// The photos taken anyway, the checks not clear: what they still saw, when
  /// they agreed on it. Their review asks for a retake first.
  final _takenAnyway = Map<Uint8List, DocumentPhotoIssue?>.identity();

  var _qualityWaived = false;
  Timer? _waiveTimer;

  /// Whether the preview has shown for [documentPhotoMinPreview].
  var _previewSettled = false;
  Timer? _settleTimer;

  bool get _isPassport => widget.documentType == DocumentType.passport;

  List<DocumentPhotoSide> _sidesToCapture() {
    if (widget.scanned != null && !_isPassport) return const [DocumentPhotoSide.back, DocumentPhotoSide.front];
    return const [DocumentPhotoSide.front, DocumentPhotoSide.back];
  }

  DocumentPhotoSide get _side => _sides[_index];

  int get _sideCount => _sides.length;

  /// The review shows the picture just taken, not yet the photo that is sent.
  bool get _preparing => _state == _PhotoState.review && _photo == null;

  /// Whether the photo on review is the one the MRZ scan took.
  bool get _reviewingScanned => _photo != null && identical(_photo, widget.scanned);

  /// What tells this side of the document: the photo side shows a portrait;
  /// the MRZ is on a passport's photo page (ICAO TD3) and on an identity
  /// card's or residence permit's back (TD1). Most driving licences have
  /// none, and a document of unknown type might not.
  SideContent get _content => (
    portrait: _side == DocumentPhotoSide.front,
    mrz: switch (widget.documentType) {
      DocumentType.passport => _side == DocumentPhotoSide.front,
      DocumentType.identityCard || DocumentType.residencePermit => _side == DocumentPhotoSide.back,
      DocumentType.drivingLicence || null => false,
    },
  );

  /// [_content], without the MRZ when the other side already showed it, in
  /// its preview or on its photo: a TD2 card has its MRZ on the front.
  Future<SideContent> _contentToLookFor() async {
    final content = _content;
    final other = _taken[_side == DocumentPhotoSide.front ? DocumentPhotoSide.back : DocumentPhotoSide.front];
    if (!content.mrz || other == null) return content;
    final shown = _mrzPreviewed.contains(other) || (await _readSide(other))?.mrz != null;
    return shown ? (portrait: content.portrait, mrz: false) : content;
  }

  /// Both sides of a passport's photo page get the passport-page frame;
  /// every card side, and a document of unknown type, the ID-1 card frame.
  double get _frameRatio => _isPassport ? MRZCameraOverlay.passportFrameRatio : MRZCameraOverlay.cardFrameRatio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final scanned = widget.scanned;
    if (scanned != null) {
      _photo = scanned;
      _state = _PhotoState.review;
      _onReview(scanned);
    } else {
      unawaited(_openCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _waiveTimer?.cancel();
    _settleTimer?.cancel();
    unawaited(_camera.dispose());
    unawaited(_photoTextReader?.close());
    super.dispose();
  }

  /// Whether the camera was released in the background: only then is it reopened on return.
  var _releasedInBackground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera is released in the background and reopened on return, but
    // only while it's actually in use - not on the review. Not on inactive:
    // the camera permission prompt, the control center or the notification
    // shade alone make the app inactive, and the preview keeps running.
    if (_state != _PhotoState.preview && _state != _PhotoState.opening) return;
    if (state == AppLifecycleState.paused) {
      _releasedInBackground = true;
      unawaited(_camera.close());
      setState(() => _state = _PhotoState.opening);
    } else if (state == AppLifecycleState.resumed && _releasedInBackground) {
      _releasedInBackground = false;
      unawaited(_openCamera());
    }
  }

  /// Bumped by every [_openCamera], so only the latest one shows its result.
  var _openAttempt = 0;

  Future<void> _openCamera() async {
    final attempt = ++_openAttempt;
    _waiveTimer?.cancel();
    _settleTimer?.cancel();
    _quality.reset();
    setState(() {
      _state = _PhotoState.opening;
      _error = null;
      _qualityWaived = false;
      _previewSettled = false;
    });
    // Back, or a later open, overtook this one while the camera opened.
    bool overtaken() => attempt != _openAttempt || _state != _PhotoState.opening;
    try {
      final content = _content;
      // Read while the camera opens, not before it.
      final toLookFor = _contentToLookFor();
      await _camera.open(frameRatio: _frameRatio, content: content, onFrameChecked: _onFrameChecked);
      if (!mounted || overtaken()) return;
      setState(() => _state = _PhotoState.preview);
      _startPreviewTimers();

      unawaited(
        toLookFor.then((found) {
          if (mounted && attempt == _openAttempt && _state == _PhotoState.preview && found != content) {
            _camera.lookFor(found);
          }
        }),
      );
    } catch (e) {
      if (!mounted || overtaken()) return;
      _showError(
        e is DocumentPhotoNoCameraException
            ? context.l10n.docPhotoErrorNoCamera
            : context.l10n.docPhotoErrorCamera('$e'),
      );
    }
  }

  void _startPreviewTimers() {
    _waiveTimer = Timer(documentPhotoQualityWaiveDelay, () {
      if (mounted) setState(() => _qualityWaived = true);
    });
    _settleTimer = Timer(documentPhotoMinPreview, () {
      if (!mounted) return;
      setState(() => _previewSettled = true);
      _captureWhenClear();
    });
  }

  void _onFrameChecked(Set<DocumentPhotoIssue> issues) {
    if (!mounted || (_state != _PhotoState.opening && _state != _PhotoState.preview)) return;
    if (_quality.update(issues)) setState(() {});
    _captureWhenClear();
  }

  /// Takes the photo once every check is clear: no tap that shakes the phone.
  void _captureWhenClear() {
    if (_state == _PhotoState.preview && _previewSettled && _quality.clear) unawaited(_capture());
  }

  Future<void> _capture() async {
    final index = _index;
    final takenAnyway = !_quality.clear;
    final openIssue = _quality.issue;
    _waiveTimer?.cancel();
    _settleTimer?.cancel();
    setState(() => _state = _PhotoState.capturing);
    // Only the side it was taken for gets the picture.
    bool overtaken() => _index != index || _state != _PhotoState.capturing;
    DocumentPicture? shot;
    try {
      final mrzShown = _camera.mrzShown;
      final taken = await _camera.takePicture(frameRatio: _frameRatio);
      if (!mounted || overtaken()) {
        taken.photo.ignore();
        return;
      }

      shot = taken.shot;
      setState(() {
        _shot = shot;
        _state = _PhotoState.review;
      });
      // The review doesn't need the camera.
      final prepared = await Future.wait<Object?>([taken.photo, _camera.close()]);
      if (!mounted || !identical(_shot, shot)) return;
      final photo = prepared.first! as Uint8List;
      if (mrzShown) _mrzPreviewed.add(photo);
      if (takenAnyway) _takenAnyway[photo] = openIssue;
      setState(() {
        _photo = photo;
        _shot = null;
      });
      _onReview(photo);
    } catch (e) {
      if (!mounted || (shot == null ? overtaken() : !identical(_shot, shot))) return;
      _shot = null;
      _showError(context.l10n.docPhotoErrorCamera('$e'));
    }
  }

  void _showError(String message) {
    setState(() {
      _state = _PhotoState.error;
      _error = message;
    });
  }

  /// Reads the text on [photo] and, once both sides have one, compares them.
  void _onReview(Uint8List photo) {
    unawaited(_readSide(photo));
    final otherSide = _side == DocumentPhotoSide.front ? DocumentPhotoSide.back : DocumentPhotoSide.front;
    final other = _taken[otherSide];
    if (other == null) return;
    final front = _side == DocumentPhotoSide.front;
    unawaited(_compareSides(front: front ? photo : other, back: front ? other : photo));
  }

  Future<SideText?> _readSide(Uint8List photo) => _sideTexts.putIfAbsent(photo, () async {
    try {
      final read = widget.readPhotoText ?? (_photoTextReader ??= DocumentTextReader()).photoText;
      final text = await read(photo);
      return SideText.read(text.lines, barcodes: text.barcodes);
    } catch (e) {
      _vizLog.warning('VIZ text not read: $e');
      return null;
    }
  });

  /// Only logged for now, until the text of real documents' sides is
  /// measured: search the log for `VIZ`.
  Future<void> _compareSides({required Uint8List front, required Uint8List back}) async {
    debugVizCheck.value = null;
    final texts = await Future.wait([_readSide(front), _readSide(back)]);
    if (!mounted || !(identical(_photo, front) || identical(_photo, back))) return;
    final check = checkSides(texts[0], texts[1], known: widget.known);
    _vizLog.info('VIZ ${widget.documentType?.name ?? 'unknown'} known=${widget.known != null} $check');
    debugVizCheck.value = check;
  }

  void _retake() {
    _sideTexts.remove(_photo);
    _mrzPreviewed.remove(_photo);
    _takenAnyway.remove(_photo);
    setState(() => _photo = null);
    unawaited(_openCamera());
  }

  /// Accepts the photo on review: on to the next side, or - once every side
  /// has one - sends them.
  Future<void> _usePhoto() async {
    final photo = _photo;
    if (photo == null || _sending) return;
    _taken[_side] = photo;
    if (_index + 1 < _sideCount) {
      setState(() {
        _photo = null;
        _index++;
      });
      unawaited(_openCamera());
      return;
    }
    await _send(_taken[DocumentPhotoSide.front]!, _taken[DocumentPhotoSide.back]!);
  }

  Future<void> _send(Uint8List front, Uint8List back) async {
    if (_sending || !mounted) return;
    setState(() => _sending = true);
    try {
      await widget.onPhotosTaken(front, back);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Back on a later side returns to the previous side's review; on the
  /// first it leaves the step.
  void _back() {
    // A picture being taken or prepared belongs to this side: it finishes first.
    if (_state == _PhotoState.capturing || _preparing) return;
    if (_index > 0) {
      unawaited(_camera.close());
      setState(() {
        _index--;
        _photo = _taken.remove(_side);
        _state = _PhotoState.review;
      });
      return;
    }
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return GuidedStatusBar(
      backdrop: Backdrop.dark,
      bottomBackdrop: _state == _PhotoState.review ? Backdrop.dark : Backdrop.light,
      child: Scaffold(
        backgroundColor: context.guided.header,
        body: switch (_state) {
          _PhotoState.review => _buildReview(context),
          _ => _buildCamera(context),
        },
      ),
    );
  }

  /// The back button, title and step bar on the dark header, like the MRZ
  /// scanner's (ScannerWrapper).
  Widget _buildTopBar(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        GuidedTopBar(
          leading: GuidedRoundButton(
            icon: Icons.chevron_left,
            tooltip: l10n.docBack,
            backdrop: Backdrop.dark,
            onPressed: _state == _PhotoState.capturing || _preparing ? null : _back,
          ),
          center: GuidedTopBarTitle(l10n.docPhotoStepLabel, backdrop: Backdrop.dark),
        ),
        GuidedStepBar(step: widget.stepNumber, total: widget.totalSteps, backdrop: Backdrop.dark),
      ],
    );
  }

  /// Which side this is, e.g. "Front · 1 of 2" - only when there are two.
  Widget _buildSideIndicator(BuildContext context) {
    if (_sideCount < 2) return const SizedBox.shrink();
    final l10n = context.l10n;
    final front = _side == DocumentPhotoSide.front;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        l10n.docPhotoSideProgress(front ? l10n.docPhotoSideFront : l10n.docPhotoSideBack, _index + 1, _sideCount),
        style: TextStyle(color: context.guided.stepLabelOnDark, fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required String title, required String message}) {
    final g = context.guided;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSideIndicator(context),
          GuidedHeading(title, style: g.heading(20, color: Colors.white, height: 1.3)),
          const SizedBox(height: 4),
          Text(message, style: TextStyle(color: g.heroMuted, fontSize: 15, height: 1.4)),
        ],
      ),
    );
  }

  String _instructions(AppLocalizations l10n, {required bool front}) {
    if (!front) return _isPassport ? l10n.docPhotoBackPassport : l10n.docPhotoBackInstructions;
    return _isPassport ? l10n.docPhotoFrontInstructionsPassport : l10n.docPhotoFrontInstructionsCard;
  }

  String _qualityHint(AppLocalizations l10n, DocumentPhotoIssue issue) => switch (issue) {
    DocumentPhotoIssue.noDocument => l10n.docPhotoHintNoDocument,
    DocumentPhotoIssue.noPortrait => l10n.docPhotoHintNoPortrait,
    DocumentPhotoIssue.noMrz => l10n.docPhotoHintNoMrz,
    DocumentPhotoIssue.glare || DocumentPhotoIssue.reflection => l10n.docPhotoHintGlare,
    DocumentPhotoIssue.tilted => l10n.docPhotoHintTilted,
    DocumentPhotoIssue.tooDark => l10n.docPhotoHintTooDark,
    DocumentPhotoIssue.blurry => l10n.docPhotoHintBlurry,
    DocumentPhotoIssue.unreadable => l10n.docPhotoHintUnreadable,
  };

  Widget _buildHint(BuildContext context, String hint) {
    final g = context.guided;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: g.actionTint, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: g.action, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(hint, style: TextStyle(fontSize: 14, height: 1.4, color: g.bodyText)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraActions(BuildContext context) {
    final l10n = context.l10n;
    final style = context.guided.primaryButtonStyle.copyWith(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
    );
    if (_state == _PhotoState.error) {
      return ElevatedButton(style: style, onPressed: _openCamera, child: Text(l10n.faceTryAgain));
    }
    // The photo is taken by itself once the checks are clear: this is the way
    // out when they haven't been for a while.
    if (_state != _PhotoState.preview || !_qualityWaived || _quality.clear) return const SizedBox.shrink();

    return ElevatedButton.icon(
      style: style,
      onPressed: _capture,
      icon: const Icon(Icons.camera_alt),
      label: Text(l10n.docPhotoTakeAnyway),
    );
  }

  /// Like the MRZ scanner's (ScannerWrapper): what to do in a sheet under the
  /// frame, the instructions behind a tap, so no text lies over the document.
  Widget _buildSheet(BuildContext context) {
    final l10n = context.l10n;
    final g = context.guided;
    final front = _side == DocumentPhotoSide.front;
    final issue = _state == _PhotoState.preview ? _quality.issue : null;
    // The photo is about to be taken, or being taken.
    final holdStill = _state == _PhotoState.capturing || (_state == _PhotoState.preview && _quality.clear);
    final error = _error;
    return GuidedSheet(
      label: Text(
        l10n.docPhotoSideProgress(front ? l10n.docPhotoSideFront : l10n.docPhotoSideBack, _index + 1, _sideCount),
        style: TextStyle(color: g.stepLabel, fontSize: 13, fontWeight: FontWeight.w700),
      ),
      title: front ? l10n.docPhotoFrontTitle : l10n.docPhotoBackTitle,
      showTip: l10n.docPhotoShowTips,
      hideTip: l10n.scanHideTips,
      tip: Text(
        _instructions(l10n, front: front),
        style: TextStyle(fontSize: 15, height: 1.5, color: g.bodyText),
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (issue != null)
            _buildHint(context, _qualityHint(l10n, issue))
          else if (holdStill)
            _buildHint(context, l10n.docPhotoHoldStill),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(error, style: TextStyle(color: g.error)),
            ),
          _buildCameraActions(context),
        ],
      ),
    );
  }

  Widget _buildCamera(BuildContext context) {
    final g = context.guided;
    return Stack(
      fit: StackFit.expand,
      children: [
        SizedBox.expand(
          child: _state == _PhotoState.opening || _state == _PhotoState.error
              ? ColoredBox(color: g.header)
              : _camera.buildPreview(context),
        ),
        // The frame the checks and the photo's crop use too (DocumentPicture.frameInPreview).
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, box) => CustomPaint(
                painter: GuidedScanFramePainter(
                  frame: MRZCameraOverlay.frameRect(box.biggest, _frameRatio),
                  scrim: g.ink.withValues(alpha: 0.8),
                  highlight: g.heroAccent,
                ),
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(bottom: false, child: _buildTopBar(context)),
            const Spacer(),
            _buildSheet(context),
          ],
        ),
      ],
    );
  }

  /// Whether the photo on review was taken anyway, the checks not clear.
  bool get _reviewingTakenAnyway => _photo != null && _takenAnyway.containsKey(_photo);

  Widget _buildReview(BuildContext context) {
    final l10n = context.l10n;
    final openIssue = _reviewingTakenAnyway ? _takenAnyway[_photo] : null;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBar(context),
          _buildHeader(
            context,
            title: l10n.docPhotoReviewTitle,
            message: _reviewingTakenAnyway
                ? l10n.docPhotoReviewAnywayMessage
                : _reviewingScanned
                ? l10n.docPhotoReviewScannedMessage
                : l10n.docPhotoReviewMessage,
          ),
          if (openIssue != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _buildHint(context, _qualityHint(l10n, openIssue)),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: switch ((_photo, _shot)) {
                (final Uint8List photo, _) => Image.memory(photo, fit: BoxFit.contain, gaplessPlayback: true),
                (_, final DocumentPicture shot) => _ShotPreview(shot),
                _ => const SizedBox.shrink(),
              },
            ),
          ),
          if (_preparing) _buildPreparing(context) else ..._buildReviewActions(context),
        ],
      ),
    );
  }

  Widget _buildPreparing(BuildContext context) {
    return Padding(
      padding: guidedBottomButtonPadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 12),
          Semantics(
            liveRegion: true,
            child: Text(context.l10n.docPhotoPreparing, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  /// Retake and use, and in debug builds what the checks said: only once
  /// the photo that is sent is ready. A photo taken anyway leads with
  /// retake, one the checks passed with use.
  List<Widget> _buildReviewActions(BuildContext context) {
    final l10n = context.l10n;
    Widget primary(String label, VoidCallback? onPressed) =>
        ElevatedButton(style: context.guided.heroButtonStyle, onPressed: onPressed, child: Text(label));
    Widget secondary(String label, VoidCallback? onPressed) => OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white, width: 2),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
    final retake = _sending ? null : _retake;
    final use = _sending ? null : _usePhoto;
    final retakeFirst = _reviewingTakenAnyway;
    return [
      if (kDebugMode && _taken.length + 1 == _sideCount) const _VizCheckBanner(),
      Padding(
        padding: guidedBottomButtonPadding,
        child: Row(
          children: [
            Expanded(
              child: retakeFirst ? primary(l10n.docPhotoRetake, retake) : secondary(l10n.docPhotoRetake, retake),
            ),
            const SizedBox(width: 16),
            Expanded(child: retakeFirst ? secondary(l10n.docPhotoUse, use) : primary(l10n.docPhotoUse, use)),
          ],
        ),
      ),
    ];
  }
}

/// The picture just taken, cut to the document frame like the photo
/// prepared from it, decoded by the platform at screen size: shown in an
/// instant, where preparing the photo takes seconds.
class _ShotPreview extends StatefulWidget {
  const _ShotPreview(this.shot);

  final DocumentPicture shot;

  @override
  State<_ShotPreview> createState() => _ShotPreviewState();
}

class _ShotPreviewState extends State<_ShotPreview> {
  late final ImageProvider _provider = ResizeImage(
    MemoryImage(widget.shot.jpeg),
    width: documentPhotoMaxLongEdge,
    height: documentPhotoMaxLongEdge,
    policy: ResizeImagePolicy.fit,
  );
  ImageStream? _stream;
  late final _listener = ImageStreamListener(_onImage, onError: (_, _) {});
  ImageInfo? _image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = _provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onImage(ImageInfo image, bool _) {
    if (!mounted) return image.dispose();
    setState(() {
      _image?.dispose();
      _image = image;
    });
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _image?.dispose();
    // Shown once: not kept in the image cache.
    unawaited(_provider.evict());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image?.image;
    if (image == null) return const SizedBox.expand();
    // The platform turns the picture upright as it decodes it.
    final crop = widget.shot.cropIn(image.width, image.height);
    return FittedBox(
      child: SizedBox(
        width: crop.width,
        height: crop.height,
        child: CustomPaint(painter: _CropPainter(image, crop)),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.crop);

  final ui.Image image;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawImageRect(image, crop, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);

  @override
  bool shouldRepaint(_CropPainter old) => old.image != image || old.crop != crop;
}

class _VizCheckBanner extends StatelessWidget {
  const _VizCheckBanner();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: debugVizCheck,
    builder: (context, check, _) {
      if (check == null) return const SizedBox.shrink();
      return Container(
        key: const Key('viz check'),
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: switch (check.match) {
            SidesMatch.same => Colors.green.shade700,
            SidesMatch.different => Colors.red.shade700,
            SidesMatch.unknown => Colors.grey.shade700,
          },
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Sides: ${check.match.name} · front document ${check.frontLooksLikeDocument} · '
          'back document ${check.backLooksLikeDocument} (debug)',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      );
    },
  );
}
