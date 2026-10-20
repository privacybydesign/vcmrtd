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
import 'package:idem/services/document_liveness.dart';
import 'package:idem/services/document_material.dart';
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
Uint8List prepareDocumentPhoto(DocumentPicture picture) => _encode(_uprightDocument(picture));

/// [prepareDocumentPhoto], and what the full-resolution picture shows the
/// document is made of - or why that couldn't be inspected, which must never
/// cost the user their photo.
/// [timings] says how long each part took, in milliseconds.
({Uint8List photo, DocumentMaterial? material, String? inspectionError, String timings}) prepareAndInspectDocumentPhoto(
  DocumentPicture picture,
) {
  final watch = Stopwatch()..start();
  int lap() {
    final ms = watch.elapsedMilliseconds;
    watch.reset();
    return ms;
  }

  final upright = _uprightDocument(picture);
  final decode = lap();
  final photo = _encode(upright);
  final encode = lap();
  DocumentMaterial? material;
  String? inspectionError;
  try {
    material = inspectDocumentMaterial(upright);
  } catch (e) {
    inspectionError = '$e';
  }
  return (
    photo: photo,
    material: material,
    inspectionError: inspectionError,
    timings: 'document=${upright.width}x${upright.height} decodeMs=$decode encodeMs=$encode materialMs=${lap()}',
  );
}

img.Image _uprightDocument(DocumentPicture picture) {
  // The camera plugin takes its pictures as JPEG on both platforms.
  final decoded = img.decodeJpg(picture.jpeg);
  if (decoded == null) throw const FormatException('the camera returned no readable JPEG');
  final oriented = img.bakeOrientation(decoded);
  final crop = picture.cropIn(oriented.width, oriented.height);
  return img.copyCrop(
    oriented,
    x: crop.left.toInt(),
    y: crop.top.toInt(),
    width: crop.width.toInt(),
    height: crop.height.toInt(),
  );
}

Uint8List _encode(img.Image upright) {
  final resized = _fitLongEdge(upright, documentPhotoMaxLongEdge);
  resized.exif = img.ExifData();
  return img.encodeJpg(resized, quality: documentPhotoJpegQuality);
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

final _materialLog = Logger('DocumentMaterial');

/// Numbers the inspected photos in the log, so each can be told apart.
var _photosInspected = 0;

/// [prepareDocumentPhoto] off the UI isolate: decoding a full-resolution
/// picture takes a while. What the document is made of is only logged for
/// now, until its signals are measured on real documents and reproductions:
/// search the log for `ANTISPOOF`.
/// [side] and [liveness] are what the preview frames before the picture
/// showed, none for a picture the MRZ scan took; [timings], how long taking
/// it took.
Future<Uint8List> preparePhotoInBackground(
  DocumentPicture picture, {
  String? side,
  LivenessSignals? liveness,
  String? timings,
}) async {
  final watch = Stopwatch()..start();
  final prepared = await compute(prepareAndInspectDocumentPhoto, picture);
  final prepareMs = watch.elapsedMilliseconds;
  final number = ++_photosInspected;
  final error = prepared.inspectionError;
  final material = prepared.material;
  // Not the still photo's moiré: the fine security print of real Dutch driving
  // licences, ID cards and passports scored like a screen (10.9 to 37.3).
  final reproduction = liveness?.screenLike == true;
  final line = [
    'ANTISPOOF #$number ${defaultTargetPlatform.name}',
    if (error == null) 'verdict=${reproduction ? 'reproduction' : 'physical'}' else 'failed: $error',
    ?side,
    ?liveness,
    ?material,
    ?timings,
    '${prepared.timings} prepareMs=$prepareMs',
  ].join(' ');
  if (error != null) {
    _materialLog.warning(line);
  } else {
    _materialLog.info(line);
  }
  if (liveness != null) {
    debugAntiSpoofVerdict.value = (
      reproduction: reproduction,
      flashGlare: liveness.flashGlare,
      flashResponse: liveness.flashResponse,
    );
  }
  return prepared.photo;
}

/// The anti-spoof verdict on the last picture the photo step took itself,
/// shown on its review in debug builds while the checks are tuned.
typedef AntiSpoofVerdict = ({bool reproduction, double? flashGlare, double? flashResponse});

final debugAntiSpoofVerdict = ValueNotifier<AntiSpoofVerdict?>(null);

final _vizLog = Logger('DocumentViz');

/// What the text on both sides said, shown on the last side's review in
/// debug builds while the comparison is tuned.
final debugVizCheck = ValueNotifier<VizCheck?>(null);

const _flashPhase = Duration(milliseconds: 700);
const _torchSettling = Duration(milliseconds: 300);

/// Frames already on their way when the light changed: iOS keeps up to four
/// in flight, and full-resolution frames reach Dart late.
const _staleFrames = 5;
const _minPhaseFrames = 4;
const _phaseTimeout = Duration(seconds: 3);
const _streamFps = 25;

/// About the 1080p frames Android streams: what text recognition and the
/// checks need of an iOS frame.
const _checkedLongEdge = 1920;

const _deviceRotations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// The clockwise degrees that turn a preview frame from [camera] upright.
/// iOS turns stream frames to the device's orientation itself, and ML Kit
/// there ignores the rotation it's given.
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

  /// What the last checked frame showed, logged with the picture.
  DocumentPortrait? _portrait;
  int? _mrzLines;

  /// Started by the first [open] and kept until [dispose]: its isolates and
  /// face models take a while to start.
  Future<DocumentFrameChecker>? _checkerStart;
  DocumentFrameChecker? _checker;

  /// The last [close]: the next [open] waits for it to release the camera.
  Future<void>? _closing;

  /// Null until the portrait checker has looked at a frame of this side.
  bool? _portraitInPlace;

  DocumentTextReader? _textReader;

  /// Text recognition is slower than a frame: one read at a time, frames use the latest lines.
  var _reading = false;
  List<Rect>? _lines;

  final _liveness = DocumentLiveness();

  /// The light the frames being checked are taken in; null while the torch
  /// settles, when frames are left out.
  LightPhase? _phase = LightPhase.preview;
  var _stale = 0;
  var _phaseFrames = 0;
  Completer<void>? _phaseFilled;

  @override
  Future<void> open({
    required double frameRatio,
    required SideContent content,
    required ValueChanged<Set<DocumentPhotoIssue>> onFrameChecked,
  }) async {
    _frameRatio = frameRatio;
    _content = content;
    _portrait = null;
    _portraitInPlace = null;
    _mrzLines = null;
    _onFrameChecked = onFrameChecked;
    _liveness.reset();
    final open = _controller;
    if (open != null) {
      // Still open after a picture that failed: its preview frames stopped.
      if (!open.value.isStreamingImages) await open.startImageStream(_checkFrame);
      return;
    }

    final generation = ++_generation;
    final opening = Stopwatch()..start();
    await _closing;
    if (generation != _generation) return;
    final cameras = await availableCameras();
    if (generation != _generation) return;
    if (cameras.isEmpty) throw const DocumentPhotoNoCameraException();
    final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
    final controller = CameraController(
      back,
      // The full resolution: a phone screen's pixels are too fine for less.
      ResolutionPreset.max,
      // Every preview frame is copied at full resolution, which iOS at its 30 fps can't keep up with.
      fps: _streamFps,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );
    try {
      final checker = _startChecker();
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
    _openMs = opening.elapsedMilliseconds;
  }

  /// How long the last [open] took to show the preview, logged with the picture.
  int? _openMs;

  /// The size of the preview frames, logged with the picture.
  String? _streamSize;

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
    final plane = image.planes.first;
    final colour = image.planes.length >= 3 ? image.planes[1] : null;
    final frame = Platform.isAndroid
        ? LumaFrame.luma(
            bytes: plane.bytes,
            width: image.width,
            height: image.height,
            bytesPerRow: plane.bytesPerRow,
            u: colour?.bytes,
            v: image.planes.length >= 3 ? image.planes[2].bytes : null,
            chromaBytesPerRow: colour?.bytesPerRow ?? 0,
            chromaPixelStride: colour?.bytesPerPixel ?? 1,
          )
        : LumaFrame.bgra(bytes: plane.bytes, width: image.width, height: image.height, bytesPerRow: plane.bytesPerRow);

    final region = DocumentPicture.frameInPreview(
      MRZCameraOverlay.frameRect(viewSize, _frameRatio),
      _previewRect(viewSize, controller.value.aspectRatio),
    );
    final generation = _generation;
    _streamSize = '${image.width}x${image.height}';
    _liveness.received();
    final phase = _phase;
    if (_stale > 0) {
      _stale--;
    } else if (phase != null) {
      _liveness
        ..add(frameSignature(frame, rotation: rotation, region: region), phase)
        ..exposure(phase, time: image.sensorExposureTime, iso: image.sensorSensitivity);
      if (++_phaseFrames == _minPhaseFrames) _phaseFilled?.complete();
    }
    final content = _content;
    final lookForPortrait = content.portrait && checker.portraitFree;
    // Until the text is read the issues can't be reported, but the portrait can be looked for.
    final checkFrame = !checker.busy && (_lines != null || lookForPortrait);
    if (_reading && !checkFrame) return;
    final checked = shrunkBgra(frame, maxLongEdge: _checkedLongEdge);
    if (!_reading) _readText(checked, rotation: rotation);
    if (!checkFrame) return;

    final check = checker.check(checked, rotation: rotation, region: region, portrait: lookForPortrait);
    if (lookForPortrait) _liveness.portraitChecked();
    unawaited(
      check.portrait?.then((portrait) {
        if (generation != _generation) return;
        _portrait = portrait;
        _portraitInPlace = portraitInPlace(portrait);
      }, onError: (_) {}),
    );

    unawaited(
      check.issues.then((frameIssues) {
        final lines = _lines;
        if (generation != _generation || _onFrameChecked != onFrameChecked || lines == null) return;
        _liveness.qualityChecked();
        final mrz = _mrzLines = mrzLines(lines, region);
        var issues = frameIssues;
        if (!textReadable(lines, region)) issues = withUnreadable(issues);
        if (content.mrz && !isMrzLayout(mrz)) issues = withoutMrz(issues);
        if (content.portrait && _portraitInPlace == false) issues = withoutPortrait(issues);
        onFrameChecked(issues);
      }, onError: (_) {}),
    );
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
    final side = _sideSummary(_content, _portrait, _mrzLines);
    final watch = Stopwatch()..start();
    if (controller.value.isStreamingImages) await _testFlash(controller);
    final flashMs = watch.elapsedMilliseconds;
    final liveness = _liveness.signals;
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
    final timings =
        'stream=${_streamSize ?? '-'} openMs=${_openMs ?? '-'} flashMs=$flashMs shotMs=${watch.elapsedMilliseconds - flashMs}';
    final photo = preparePhotoInBackground(shot, side: side, liveness: liveness, timings: timings);
    return (shot: shot, photo: photo.whenComplete(() => closing));
  }

  @override
  void lookFor(SideContent content) => _content = content;

  /// Lights the document with the torch, exposure and focus locked, while
  /// the preview frames go on: a document reflects it and its hologram lights
  /// up, a screen hardly does. A camera without a torch or the locks still
  /// takes its picture.
  Future<void> _testFlash(CameraController controller) async {
    try {
      await controller.setExposureMode(ExposureMode.locked);
      await controller.setFocusMode(FocusMode.locked);
      await _takeFrames(LightPhase.unlit);
      _phase = null;
      await controller.setFlashMode(FlashMode.torch);
      await Future<void>.delayed(_torchSettling);
      await _takeFrames(LightPhase.lit);
    } catch (_) {
      // No torch or no exposure lock: the picture is still taken.
    } finally {
      _phase = null;
      _phaseFilled = null;
      try {
        await controller.setFlashMode(FlashMode.off);
        await controller.setExposureMode(ExposureMode.auto);
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      _phase = LightPhase.preview;
    }
  }

  /// Frames in [phase] for at least [_flashPhase] and [_minPhaseFrames],
  /// leaving out the ones taken before it began.
  Future<void> _takeFrames(LightPhase phase) {
    final filled = _phaseFilled = Completer<void>();
    _phaseFrames = 0;
    _stale = _staleFrames;
    _phase = phase;
    return Future.wait([
      Future<void>.delayed(_flashPhase),
      filled.future,
    ]).timeout(_phaseTimeout, onTimeout: () => const []);
  }

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

/// What the side showed, for the photo's `ANTISPOOF` line.
String _sideSummary(SideContent expected, DocumentPortrait? portrait, int? mrzLines) {
  final box = portrait?.box;
  return [
    'expects=${[if (expected.portrait) 'portrait', if (expected.mrz) 'mrz'].join('+').ifEmpty('none')}',
    if (portrait == null || box == null)
      'portrait=none'
    else
      'portrait=${portraitInPlace(portrait) ? 'inPlace' : 'outOfPlace'} portraitScore=${portrait.score.toStringAsFixed(2)} '
          'portraitHeight=${box.height.toStringAsFixed(2)}',
    'mrzLines=${mrzLines ?? '-'}',
  ].join(' ');
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// The device has no camera at all.
class DocumentPhotoNoCameraException implements Exception {
  const DocumentPhotoNoCameraException();
}

enum _PhotoState { opening, preview, capturing, review, error }

/// After this the photo can be taken whatever the checks say.
const documentPhotoQualityWaiveDelay = Duration(seconds: 5);

/// Which side of the document is being photographed.
enum DocumentPhotoSide { front, back }

/// The document_photo step: the user photographs the front of their
/// document and its back (a passport's photo page and the back of that
/// page), each inside a document-shaped guide, checking every
/// photo and either retaking or using it. A side the MRZ scan already
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

  var _qualityWaived = false;
  Timer? _waiveTimer;

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
  /// card's back (TD1). Most driving licences have none, and a document of
  /// unknown type might not.
  SideContent get _content => (
    portrait: _side == DocumentPhotoSide.front,
    mrz: switch (widget.documentType) {
      DocumentType.passport => _side == DocumentPhotoSide.front,
      DocumentType.identityCard => _side == DocumentPhotoSide.back,
      DocumentType.drivingLicence || null => false,
    },
  );

  /// [_content], without the MRZ when the other side's photo already showed
  /// it: some cards have theirs on the front.
  Future<SideContent> _contentToLookFor() async {
    final content = _content;
    final other = _taken[_side == DocumentPhotoSide.front ? DocumentPhotoSide.back : DocumentPhotoSide.front];
    if (!content.mrz || other == null) return content;
    final text = await _readSide(other);
    return text?.mrz == null ? content : (portrait: content.portrait, mrz: false);
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
    unawaited(_camera.dispose());
    unawaited(_photoTextReader?.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera is released in the background and reopened on return, but
    // only while it's actually in use - not on the review. Not on inactive:
    // the camera permission prompt alone makes the app inactive.
    if (_state != _PhotoState.preview && _state != _PhotoState.opening) return;
    if (state == AppLifecycleState.paused) {
      unawaited(_camera.close());
      setState(() => _state = _PhotoState.opening);
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_openCamera());
    }
  }

  /// Bumped by every [_openCamera], so only the latest one shows its result.
  var _openAttempt = 0;

  Future<void> _openCamera() async {
    final attempt = ++_openAttempt;
    _waiveTimer?.cancel();
    _quality.reset();
    setState(() {
      _state = _PhotoState.opening;
      _error = null;
      _qualityWaived = false;
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
      _waiveTimer = Timer(documentPhotoQualityWaiveDelay, () {
        if (mounted) setState(() => _qualityWaived = true);
      });
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

  void _onFrameChecked(Set<DocumentPhotoIssue> issues) {
    if (!mounted || (_state != _PhotoState.opening && _state != _PhotoState.preview)) return;
    if (_quality.update(issues)) setState(() {});
  }

  Future<void> _capture() async {
    final index = _index;
    _waiveTimer?.cancel();
    debugAntiSpoofVerdict.value = null;
    setState(() => _state = _PhotoState.capturing);
    // Only the side it was taken for gets the picture.
    bool overtaken() => _index != index || _state != _PhotoState.capturing;
    DocumentPicture? shot;
    try {
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
    if (!front) return _isPassport ? l10n.docPhotoBackInstructionsPassport : l10n.docPhotoBackInstructions;
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

  Widget _buildCameraActions(BuildContext context, {required bool front}) {
    final l10n = context.l10n;
    final ready = _state == _PhotoState.preview && (_quality.clear || _qualityWaived);
    final issue = _state == _PhotoState.preview ? _quality.issue : null;
    // The main action on the dark header, so it stands out whatever the primary.
    final style = context.guided.heroButtonStyle;
    return Padding(
      padding: guidedBottomButtonPadding.copyWith(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (issue != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _qualityHint(l10n, issue),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_state == _PhotoState.error)
            ElevatedButton(style: style, onPressed: _openCamera, child: Text(l10n.faceTryAgain))
          else
            ElevatedButton.icon(
              style: style,
              onPressed: ready && !_sending ? _capture : null,
              icon: _state == _PhotoState.capturing
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.camera_alt),
              label: Text(l10n.docPhotoTake),
            ),
        ],
      ),
    );
  }

  Widget _buildCamera(BuildContext context) {
    final l10n = context.l10n;
    final front = _side == DocumentPhotoSide.front;
    return Stack(
      fit: StackFit.expand,
      children: [
        MRZCameraOverlay(
          frameRatio: _frameRatio,
          child: SizedBox.expand(
            child: _state == _PhotoState.opening || _state == _PhotoState.error
                ? ColoredBox(color: context.guided.header)
                : _camera.buildPreview(context),
          ),
        ),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(context),
              _buildHeader(
                context,
                title: front ? l10n.docPhotoFrontTitle : l10n.docPhotoBackTitle,
                message: _instructions(l10n, front: front),
              ),
              const Spacer(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              _buildCameraActions(context, front: front),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReview(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBar(context),
          _buildHeader(
            context,
            title: l10n.docPhotoReviewTitle,
            message: _reviewingScanned ? l10n.docPhotoReviewScannedMessage : l10n.docPhotoReviewMessage,
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

  /// Retake and use, and in debug builds what the checks said: only once the photo that is sent is ready.
  List<Widget> _buildReviewActions(BuildContext context) {
    final l10n = context.l10n;
    return [
      if (kDebugMode && !_reviewingScanned) const _AntiSpoofVerdictBanner(),
      if (kDebugMode && _taken.length + 1 == _sideCount) const _VizCheckBanner(),
      Padding(
        padding: guidedBottomButtonPadding,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                ),
                onPressed: _sending ? null : _retake,
                child: Text(l10n.docPhotoRetake),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                style: context.guided.heroButtonStyle,
                onPressed: _sending ? null : _usePhoto,
                child: Text(l10n.docPhotoUse),
              ),
            ),
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

class _AntiSpoofVerdictBanner extends StatelessWidget {
  const _AntiSpoofVerdictBanner();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: debugAntiSpoofVerdict,
    builder: (context, verdict, _) {
      if (verdict == null) return const SizedBox.shrink();
      String format(double? value) => value?.toStringAsFixed(3) ?? '-';
      return Container(
        key: const Key('anti-spoof verdict'),
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: verdict.reproduction ? Colors.red.shade700 : Colors.green.shade700,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${verdict.reproduction ? 'FAKE: looks like a screen' : 'REAL: looks like a physical document'}\n'
          'flashGlare ${format(verdict.flashGlare)} · flashResponse ${format(verdict.flashResponse)} (debug)',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      );
    },
  );
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
