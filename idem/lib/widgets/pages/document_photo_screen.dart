import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:mrz_capture/mrz_capture.dart';
import 'package:path_provider/path_provider.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/services/document_photo_quality.dart';
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
Uint8List prepareDocumentPhoto(DocumentPicture picture) {
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

/// [prepareDocumentPhoto] off the UI isolate: decoding a full-resolution
/// picture takes a while.
Future<Uint8List> preparePhotoInBackground(DocumentPicture picture) => compute(prepareDocumentPhoto, picture);

/// The camera the document photo is taken with: the device's back camera,
/// or a fake in tests.
abstract class DocumentPhotoCamera {
  /// Opens the camera; throws when there is none or it can't be opened. While
  /// it's open, [onFrameChecked] gets what keeps the document inside the frame
  /// of [frameRatio] from being readable (none: nothing, see
  /// [documentPhotoIssues]) for a few preview frames a second.
  Future<void> open({required double frameRatio, required ValueChanged<Set<DocumentPhotoIssue>> onFrameChecked});

  /// The live preview, once [open] completed.
  Widget buildPreview(BuildContext context);

  /// Takes a picture, prepared for sending ([prepareDocumentPhoto]): cut to
  /// the frame of [frameRatio] drawn over the preview.
  Future<Uint8List> takePicture({required double frameRatio});

  /// Prepares a picture another camera took (the MRZ scanner's) for sending,
  /// like [takePicture] prepares its own.
  Future<Uint8List> prepare(DocumentPicture picture);

  /// Releases the camera; [open] may be called again afterwards.
  Future<void> close();
}

/// [DocumentPhotoCamera] on the device's back camera.
class DeviceDocumentPhotoCamera implements DocumentPhotoCamera {
  CameraController? _controller;

  /// Bumped by every [open] and [close], so an open that a later call
  /// overtook while the camera initialized releases what it opened.
  var _generation = 0;

  /// The size the preview was last laid out at: where the frame is drawn.
  Size? _viewSize;

  /// Where the latest [open] wants its preview frames checked, and what it
  /// wants to hear.
  double _frameRatio = MRZCameraOverlay.cardFrameRatio;
  ValueChanged<Set<DocumentPhotoIssue>>? _onFrameChecked;

  /// Checks every preview frame: started and stopped with the camera.
  DocumentFrameChecker? _checker;

  /// Reads the text in preview frames, to find the document by: opened with
  /// the first frame, closed with the camera.
  TextRecognizer? _textRecognizer;

  /// Whether the text of a preview frame is being read. Reading takes longer
  /// than a frame lasts, so it reads one frame at a time - the latest, once
  /// the last read is done - and every frame is checked against the latest
  /// read, [_readable]: null until the first read is done.
  var _reading = false;
  bool? _readable;

  /// In debug builds, where every [_dumpEvery]th checked frame is saved as
  /// the detection saw it, the last [_dumpCount] of them, to check it against
  /// real camera frames: on Android, adb pull
  /// /sdcard/Android/data/foundation.privacybydesign.idem/files/document_frames.
  Directory? _dumpDirectory;
  var _frameCount = 0;
  static const _dumpEvery = 15;
  static const _dumpCount = 40;

  static const _deviceRotations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  Future<void> open({required double frameRatio, required ValueChanged<Set<DocumentPhotoIssue>> onFrameChecked}) async {
    _frameRatio = frameRatio;
    _onFrameChecked = onFrameChecked;
    final open = _controller;
    if (open != null) {
      // Still open after a picture that failed: its preview frames stopped.
      if (!open.value.isStreamingImages) await open.startImageStream(_checkFrame);
      return;
    }
    final generation = ++_generation;
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw const DocumentPhotoNoCameraException();
    final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
    final controller = CameraController(
      back,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );
    DocumentFrameChecker? checker;
    if (kDebugMode && _dumpDirectory == null) {
      try {
        final base = Platform.isAndroid
            ? await getExternalStorageDirectory()
            : await getApplicationDocumentsDirectory();
        if (base != null) _dumpDirectory = await Directory('${base.path}/document_frames').create();
      } catch (_) {} // Only a debugging aid.
    }
    try {
      await controller.initialize();
      checker = await DocumentFrameChecker.start();
      if (generation == _generation) {
        _checker = checker;
        await controller.startImageStream(_checkFrame);
      }
    } catch (_) {
      checker?.close();
      if (identical(_checker, checker)) _checker = null;
      await controller.dispose();
      rethrow;
    }
    if (generation != _generation) {
      checker.close();
      await controller.dispose();
      return;
    }
    _controller = controller;
  }

  void _checkFrame(CameraImage image) {
    final controller = _controller;
    final viewSize = _viewSize;
    final checker = _checker;
    final onFrameChecked = _onFrameChecked;
    if (controller == null || checker == null || viewSize == null || onFrameChecked == null || image.planes.isEmpty) {
      return;
    }

    final camera = controller.description;
    final deviceRotation = _deviceRotations[controller.value.deviceOrientation] ?? 0;
    final rotation = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + deviceRotation) % 360
        : (camera.sensorOrientation - deviceRotation + 360) % 360;
    final plane = image.planes.first;
    // Android's first YUV420 plane is the brightness; iOS streams BGRA.
    final frame = Platform.isAndroid
        ? LumaFrame.luma(bytes: plane.bytes, width: image.width, height: image.height, bytesPerRow: plane.bytesPerRow)
        : LumaFrame.bgra(bytes: plane.bytes, width: image.width, height: image.height, bytesPerRow: plane.bytesPerRow);
    // The preview frames are the preview: the frame lies in them where it lies
    // in the preview.
    final region = DocumentPicture.frameInPreview(
      MRZCameraOverlay.frameRect(viewSize, _frameRatio),
      _previewRect(viewSize, controller.value.aspectRatio),
    );
    final generation = _generation;
    if (!_reading) {
      _reading = true;
      unawaited(
        _readText(image, rotation, region)
            .then((readable) {
              if (generation == _generation) _readable = readable;
            }, onError: (_) {}) // A frame whose text couldn't be read leaves the last read.
            .whenComplete(() {
              if (generation == _generation) _reading = false;
            }),
      );
    }
    // Until the first read, there's no telling whether the text is readable.
    if (_readable == null) return;
    final dumpDirectory = _dumpDirectory;
    final count = _frameCount++;
    final dumpTo = dumpDirectory != null && count % _dumpEvery == 0
        ? '${dumpDirectory.path}/frame_${(count ~/ _dumpEvery % _dumpCount).toString().padLeft(2, '0')}.pgm'
        : null;
    unawaited(
      checker.check(frame, rotation: rotation, region: region, dumpTo: dumpTo).then((issues) {
        // Not when the camera closed or reopened while the frame was checked.
        final readable = _readable;
        if (generation != _generation || _onFrameChecked != onFrameChecked || readable == null) return;
        onFrameChecked(withReadability(issues, readable: readable));
      }, onError: (_) {}), // Only when the camera closed while it was checked.
    );
  }

  /// Whether the text recognizer reads the text of the document in the frame
  /// at [region] in [image] ([textReadable]).
  Future<bool> _readText(CameraImage image, int rotation, Rect region) async {
    final sideways = rotation % 180 != 0;
    final uprightWidth = (sideways ? image.height : image.width).toDouble();
    final uprightHeight = (sideways ? image.width : image.height).toDouble();
    final text = await (_textRecognizer ??= TextRecognizer()).processImage(_textInput(image, rotation));
    // The lines' boxes are in the upright frame's pixels.
    final lines = [
      for (final block in text.blocks)
        for (final line in block.lines)
          Rect.fromLTRB(
            line.boundingBox.left / uprightWidth,
            line.boundingBox.top / uprightHeight,
            line.boundingBox.right / uprightWidth,
            line.boundingBox.bottom / uprightHeight,
          ),
    ];
    return textReadable(lines, region);
  }

  /// [image] as ML Kit reads it. Its text needs only the brightness: on
  /// Android, that plane with neutral colour after it makes the NV21 it takes.
  static InputImage _textInput(CameraImage image, int rotation) {
    final plane = image.planes.first;
    final Uint8List bytes;
    if (Platform.isAndroid) {
      final lumaSize = image.width * image.height;
      bytes = Uint8List(lumaSize + lumaSize ~/ 2)..fillRange(lumaSize, lumaSize + lumaSize ~/ 2, 128);
      for (var row = 0; row < image.height; row++) {
        bytes.setRange(row * image.width, (row + 1) * image.width, plane.bytes, row * plane.bytesPerRow);
      }
    } else {
      bytes = plane.bytes;
    }
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(rotation) ?? InputImageRotation.rotation0deg,
        format: Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
        bytesPerRow: Platform.isAndroid ? image.width : plane.bytesPerRow,
      ),
    );
  }

  @override
  Widget buildPreview(BuildContext context) {
    final controller = _controller;
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
  }

  @override
  Future<Uint8List> takePicture({required double frameRatio}) async {
    final controller = _controller;
    final viewSize = _viewSize;
    if (controller == null || viewSize == null) throw StateError('camera not open');
    // Not every platform takes a picture while it streams preview frames.
    if (controller.value.isStreamingImages) await controller.stopImageStream();
    final file = await controller.takePicture();
    final picture = DocumentPicture(
      jpeg: await readAndDeletePicture(file),
      frame: DocumentPicture.frameInPreview(
        MRZCameraOverlay.frameRect(viewSize, frameRatio),
        _previewRect(viewSize, controller.value.aspectRatio),
      ),
      previewAspectRatio: _uprightAspectRatio(viewSize, controller.value.aspectRatio),
    );
    return prepare(picture);
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
  Future<void> close() async {
    _generation++;
    _onFrameChecked = null;
    final controller = _controller;
    _controller = null;
    final textRecognizer = _textRecognizer;
    _textRecognizer = null;
    _checker?.close();
    _checker = null;
    _reading = false;
    _readable = null;
    await controller?.dispose();
    await textRecognizer?.close();
  }
}

/// The device has no camera at all.
class DocumentPhotoNoCameraException implements Exception {
  const DocumentPhotoNoCameraException();
}

enum _PhotoState { opening, preview, capturing, review, error }

/// The checks can be wrong about a document or a camera, and a user who can't
/// take the photo would see the session expire: after this the photo can be
/// taken anyway, and the review still asks whether it's readable.
const documentPhotoQualityWaiveDelay = Duration(seconds: 5);

/// Which side of the document is being photographed.
enum DocumentPhotoSide { front, back }

/// The document_photo step: the user photographs the front of their
/// document and - unless it's known to be a passport, whose back carries
/// nothing - its back, each inside a document-shaped guide, checking every
/// photo and either retaking or using it. A side the MRZ scan already
/// photographed ([scanned]) comes first, straight to its review: the user
/// always sees what is sent. [onPhotosTaken] gets both prepared JPEGs (back
/// null for a passport, or when the user says the document has none) and
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
    this.camera,
  });

  final VoidCallback onBack;
  final Future<void> Function(Uint8List front, Uint8List? back) onPhotosTaken;
  final int stepNumber;
  final int totalSteps;

  /// The document this device already knows the user holds (from the MRZ
  /// scan or the chip read), null when it doesn't: then both sides are asked
  /// for, with a way out for a document that has no back.
  final DocumentType? documentType;

  /// The side the MRZ is on, photographed as the MRZ was read: a passport's
  /// photo page (its front), a card's back. Needs [documentType] to say which.
  final Uint8List? scanned;

  /// The device's back camera when null.
  final DocumentPhotoCamera? camera;

  @override
  State<DocumentPhotoScreen> createState() => _DocumentPhotoScreenState();
}

class _DocumentPhotoScreenState extends State<DocumentPhotoScreen> with WidgetsBindingObserver {
  late final DocumentPhotoCamera _camera = widget.camera ?? DeviceDocumentPhotoCamera();
  var _state = _PhotoState.opening;

  /// The sides asked for, in order: a passport's front alone; a card's
  /// scanned back before its front; otherwise front, then back.
  late final List<DocumentPhotoSide> _sides = _sidesToCapture();
  var _index = 0;
  final _taken = <DocumentPhotoSide, Uint8List>{};
  Uint8List? _photo;
  String? _error;
  var _sending = false;

  /// Whether the preview frames show the document readable.
  final _quality = DocumentPhotoQuality();

  /// Set once the preview showed for [documentPhotoQualityWaiveDelay]: the
  /// photo can be taken however the frames look.
  var _qualityWaived = false;
  Timer? _waiveTimer;

  bool get _isPassport => widget.documentType == DocumentType.passport;

  List<DocumentPhotoSide> _sidesToCapture() {
    if (_isPassport) return const [DocumentPhotoSide.front];
    if (widget.scanned != null) return const [DocumentPhotoSide.back, DocumentPhotoSide.front];
    return const [DocumentPhotoSide.front, DocumentPhotoSide.back];
  }

  DocumentPhotoSide get _side => _sides[_index];

  /// A passport's back carries nothing, so only its front is asked for.
  int get _sideCount => _sides.length;

  /// Whether the photo on review is the one the MRZ scan took.
  bool get _reviewingScanned => _photo != null && identical(_photo, widget.scanned);

  /// Only a passport front gets the passport-page frame; every card side,
  /// and a document of unknown type, the ID-1 card frame.
  double get _frameRatio => _isPassport ? MRZCameraOverlay.passportFrameRatio : MRZCameraOverlay.cardFrameRatio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final scanned = widget.scanned;
    if (scanned != null) {
      _photo = scanned;
      _state = _PhotoState.review;
    } else {
      unawaited(_openCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _waiveTimer?.cancel();
    unawaited(_camera.close());
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
      await _camera.open(frameRatio: _frameRatio, onFrameChecked: _onFrameChecked);
      if (!mounted || overtaken()) return;
      setState(() => _state = _PhotoState.preview);
      _waiveTimer = Timer(documentPhotoQualityWaiveDelay, () {
        if (mounted) setState(() => _qualityWaived = true);
      });
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
    setState(() => _state = _PhotoState.capturing);
    // Only the side it was taken for gets the picture.
    bool overtaken() => _index != index || _state != _PhotoState.capturing;
    try {
      final photo = await _camera.takePicture(frameRatio: _frameRatio);
      // The review doesn't need the camera.
      await _camera.close();
      if (!mounted || overtaken()) return;
      setState(() {
        _photo = photo;
        _state = _PhotoState.review;
      });
    } catch (e) {
      if (!mounted || overtaken()) return;
      _showError(context.l10n.docPhotoErrorCamera('$e'));
    }
  }

  void _showError(String message) {
    setState(() {
      _state = _PhotoState.error;
      _error = message;
    });
  }

  void _retake() {
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
    await _send(_taken[DocumentPhotoSide.front]!, _taken[DocumentPhotoSide.back]);
  }

  /// The document turned out to have no back: sends the front alone. The
  /// camera is released for the send, and reopened when the send didn't lead
  /// anywhere (failed, or given up on).
  Future<void> _skipBack() async {
    final front = _taken[DocumentPhotoSide.front];
    if (front == null || _sending) return;
    setState(() => _state = _PhotoState.opening);
    await _camera.close();
    await _send(front, null);
    if (mounted && ModalRoute.of(context)?.isCurrent != false) unawaited(_openCamera());
  }

  Future<void> _send(Uint8List front, Uint8List? back) async {
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
    // A picture being taken belongs to this side: it finishes first.
    if (_state == _PhotoState.capturing) return;
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
            onPressed: _state == _PhotoState.capturing ? null : _back,
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
    if (!front) return l10n.docPhotoBackInstructions;
    return _isPassport ? l10n.docPhotoFrontInstructionsPassport : l10n.docPhotoFrontInstructionsCard;
  }

  String _qualityHint(AppLocalizations l10n, DocumentPhotoIssue issue) => switch (issue) {
    DocumentPhotoIssue.noDocument => l10n.docPhotoHintNoDocument,
    // Clipped or not, a reflection: the same thing to do about it.
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
                      child: Text(_qualityHint(l10n, issue), style: const TextStyle(color: Colors.white, fontSize: 14)),
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
          // Only when the document type is unknown: a card or
          // licence always has a back, a passport isn't asked for one.
          if (!front && widget.documentType == null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _sending ? null : _skipBack,
              child: Text(l10n.docPhotoNoBack),
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
              child: Image.memory(_photo!, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
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
        ],
      ),
    );
  }
}
