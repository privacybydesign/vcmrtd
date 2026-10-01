import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:image/image.dart' as img;
import 'package:mrz_capture/mrz_capture.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/widgets/common/button_styles.dart';
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
  final longEdge = math.max(upright.width, upright.height);
  final resized = longEdge <= documentPhotoMaxLongEdge
      ? upright
      : upright.width >= upright.height
      ? img.copyResize(upright, width: documentPhotoMaxLongEdge, interpolation: img.Interpolation.average)
      : img.copyResize(upright, height: documentPhotoMaxLongEdge, interpolation: img.Interpolation.average);
  resized.exif = img.ExifData();
  return img.encodeJpg(resized, quality: documentPhotoJpegQuality);
}

/// [prepareDocumentPhoto] off the UI isolate: decoding a full-resolution
/// picture takes a while.
Future<Uint8List> prepareDocumentPhotoInBackground(DocumentPicture picture) => compute(prepareDocumentPhoto, picture);

/// The camera the document photo is taken with: the device's back camera,
/// or a fake in tests.
abstract class DocumentPhotoCamera {
  /// Opens the camera; throws when there is none or it can't be opened.
  Future<void> open();

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

  @override
  Future<void> open() async {
    if (_controller != null) return;
    final generation = ++_generation;
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw const DocumentPhotoNoCameraException();
    final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
    final controller = CameraController(back, ResolutionPreset.veryHigh, enableAudio: false);
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
    if (generation != _generation) {
      await controller.dispose();
      return;
    }
    _controller = controller;
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
    final file = await controller.takePicture();
    final picture = DocumentPicture(
      jpeg: await file.readAsBytes(),
      frame: DocumentPicture.frameInPreview(
        MRZCameraOverlay.frameRect(viewSize, frameRatio),
        _previewRect(viewSize, controller.value.aspectRatio),
      ),
      previewAspectRatio: _uprightAspectRatio(viewSize, controller.value.aspectRatio),
    );
    return prepare(picture);
  }

  @override
  Future<Uint8List> prepare(DocumentPicture picture) => prepareDocumentPhotoInBackground(picture);

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
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}

/// The device has no camera at all.
class DocumentPhotoNoCameraException implements Exception {
  const DocumentPhotoNoCameraException();
}

enum _PhotoState { opening, preview, capturing, review, error }

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
  late final List<DocumentPhotoSide> _sides = _isPassport
      ? const [DocumentPhotoSide.front]
      : widget.scanned != null
      ? const [DocumentPhotoSide.back, DocumentPhotoSide.front]
      : const [DocumentPhotoSide.front, DocumentPhotoSide.back];
  var _index = 0;
  final _taken = <DocumentPhotoSide, Uint8List>{};
  Uint8List? _photo;
  String? _error;
  var _sending = false;

  bool get _isPassport => widget.documentType == DocumentType.passport;

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

  Future<void> _openCamera() async {
    setState(() {
      _state = _PhotoState.opening;
      _error = null;
    });
    try {
      await _camera.open();
      if (!mounted) return;
      setState(() => _state = _PhotoState.preview);
    } catch (e) {
      if (!mounted) return;
      _showError(
        e is DocumentPhotoNoCameraException
            ? context.l10n.docPhotoErrorNoCamera
            : context.l10n.docPhotoErrorCamera('$e'),
      );
    }
  }

  Future<void> _capture() async {
    setState(() => _state = _PhotoState.capturing);
    try {
      final photo = await _camera.takePicture(frameRatio: _frameRatio);
      // The review doesn't need the camera.
      await _camera.close();
      if (!mounted) return;
      setState(() {
        _photo = photo;
        _state = _PhotoState.review;
      });
    } catch (e) {
      if (!mounted) return;
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
    if (_sending) return;
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: switch (_state) {
        _PhotoState.review => _buildReview(context),
        _ => _buildCamera(context),
      },
    );
  }

  /// The back button + step badge, in white over the camera like the MRZ
  /// scanner's (ScannerWrapper).
  Widget _buildTopBar(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: context.l10n.docBack,
              icon: Icon(PlatformIcons(context).back, color: Colors.white),
              onPressed: _back,
            ),
          ),
          StepBadge(current: widget.stepNumber, total: widget.totalSteps, label: context.l10n.docPhotoStepLabel),
        ],
      ),
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
        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required String title, required String message}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSideIndicator(context),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(message, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCamera(BuildContext context) {
    final l10n = context.l10n;
    final ready = _state == _PhotoState.preview;
    final front = _side == DocumentPhotoSide.front;
    return Stack(
      fit: StackFit.expand,
      children: [
        MRZCameraOverlay(
          frameRatio: _frameRatio,
          child: SizedBox.expand(
            child: _state == _PhotoState.opening || _state == _PhotoState.error
                ? const ColoredBox(color: Colors.black)
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
                message: !front
                    ? l10n.docPhotoBackInstructions
                    : _isPassport
                    ? l10n.docPhotoFrontInstructionsPassport
                    : l10n.docPhotoFrontInstructionsCard,
              ),
              const Spacer(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_state == _PhotoState.error)
                      ElevatedButton(style: actionButtonStyle, onPressed: _openCamera, child: Text(l10n.faceTryAgain))
                    else
                      ElevatedButton.icon(
                        style: actionButtonStyle,
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
              ),
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
              padding: const EdgeInsets.all(24),
              child: Image.memory(_photo!, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _sending ? null : _retake,
                    child: Text(l10n.docPhotoRetake),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: actionButtonStyle,
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
