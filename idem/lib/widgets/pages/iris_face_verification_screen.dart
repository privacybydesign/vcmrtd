import 'dart:async';

import 'package:iris_sdk_flutter/iris_sdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:mrz_capture/mrz_capture.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/services/face_verification_outcome.dart';
import 'package:idem/services/flow_step_plan.dart';
import 'package:idem/widgets/common/face_verification_views.dart';

/// Runs the Iris SDK's face-verification flow.
///
/// Unlike [FlutterFaceVerificationScreen], there is no camera preview to
/// build here — the Iris SDK presents its own full-screen native UI once
/// [IrisFaceVerifier.verify] is called. This screen only bridges into that
/// call and renders the outcome once it returns. Since we have no visibility
/// into the native flow itself, the feedback we *can* control — the intro,
/// the brief hand-off while the SDK boots, and the result — is made as
/// informative as possible to make up for that black box in the middle.
class IrisFaceVerificationScreen extends StatefulWidget {
  final Uint8List? nfcImageBytes;

  /// Explicit cancel — the back-arrow tap. Leaves this screen without having
  /// verified anything.
  final VoidCallback onBackPressed;

  /// Fired once, a couple of seconds after a matched result, to continue on to
  /// whatever comes after face verification. Distinct from [onBackPressed] so
  /// callers can send a cancel and a successful verification to different
  /// places (e.g. back to NFC reading vs. on to the document data screen).
  final ValueChanged<FaceVerificationOutcome> onVerified;

  /// Step badge numbers — default to vcmrtd's fixed 4-step sequence (this
  /// screen is always step 3 there); see FaceVerificationEntryScreen's
  /// matching fields.
  final int stepNumber;
  final int totalSteps;

  const IrisFaceVerificationScreen({
    super.key,
    required this.nfcImageBytes,
    required this.onBackPressed,
    required this.onVerified,
    this.stepNumber = FlowStepPlan.defaultFaceVerificationStep,
    this.totalSteps = FlowStepPlan.defaultTotalSteps,
  });

  @override
  State<IrisFaceVerificationScreen> createState() => _IrisFaceVerificationScreenState();
}

enum _Status { intro, launching, result }

class _IrisFaceVerificationScreenState extends State<IrisFaceVerificationScreen> {
  final IrisFaceVerifier _verifier = IrisFaceVerifier();

  _Status _status = _Status.intro;
  String _launchMessage = '';
  Uint8List? _documentPhoto;
  IrisVerificationResult? _result;
  String? _error;
  Timer? _autoContinueTimer;

  @override
  void dispose() {
    _autoContinueTimer?.cancel();
    super.dispose();
  }

  Future<void> _runVerification() async {
    _autoContinueTimer?.cancel();
    setState(() {
      _status = _Status.launching;
      _launchMessage = context.l10n.facePreparingDocumentPhoto;
      _result = null;
      _error = null;
    });

    final portrait = await _toPng(widget.nfcImageBytes);
    if (portrait == null) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.faceIrisReadPortraitError;
        _status = _Status.result;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _documentPhoto = portrait;
      _launchMessage = context.l10n.faceOpeningIrisCamera;
    });

    try {
      final result = await _verifier.verify(portrait);
      if (!mounted) return;
      setState(() {
        _result = result;
        _status = _Status.result;
      });
      _scheduleAutoContinueIfMatched(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _describeError(e);
        _status = _Status.result;
      });
    }
  }

  /// On a matched result, give the user a brief look at the outcome before
  /// automatically moving on — only a failed/cancelled result waits for
  /// "Try Again".
  void _scheduleAutoContinueIfMatched(IrisVerificationResult result) {
    if (result.outcome != IrisVerificationOutcome.matched) return;
    _autoContinueTimer?.cancel();
    _autoContinueTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      widget.onVerified(FaceVerificationOutcome(engine: 'iris', livenessPassed: true, selfieImageBytes: result.face));
    });
  }

  static String _describeError(Object e) {
    if (e is MissingPluginException) {
      return currentL10n.faceIrisUnavailable;
    }
    if (e is PlatformException) {
      return switch (e.code) {
        'NO_ACTIVITY' => currentL10n.faceIrisNoActivity,
        'ALREADY_RUNNING' => currentL10n.faceIrisAlreadyRunning,
        _ => e.message ?? currentL10n.faceIrisFailedCode(e.code),
      };
    }
    return currentL10n.faceIrisFailedError('$e');
  }

  static const MethodChannel _imageChannel = MethodChannel('image_channel');

  // The Iris SDK requires a PNG-encoded portrait; DG2 photos may be JPEG or
  // JPEG2000. Mirrors face_verification's FaceVerificationEngine._decodeNfcImage:
  // falls back to the native JP2 decoder via image_channel when the Dart
  // decoder does not recognise the format.
  static Future<Uint8List?> _toPng(Uint8List? bytes) async {
    if (bytes == null) return null;
    final decoded = await _decodeImage(bytes);
    if (decoded == null) return null;
    return Uint8List.fromList(img.encodePng(decoded));
  }

  static Future<img.Image?> _decodeImage(Uint8List bytes) async {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      decoded = null;
    }
    if (decoded != null) return decoded;

    try {
      final converted = await _imageChannel.invokeMethod<Uint8List>('decodeImage', {'jp2ImageData': bytes});
      if (converted == null) return null;
      return img.decodeImage(converted);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: switch (_status) {
                _Status.intro => _buildIntro(),
                _Status.launching => _buildLaunching(),
                _Status.result => _buildResult(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) => StepBadgeTopBar(
    icon: Icons.arrow_back,
    tooltip: context.l10n.faceBack,
    onBack: widget.onBackPressed,
    current: widget.stepNumber,
    total: widget.totalSteps,
    label: context.l10n.faceStepLabel,
  );

  Widget _buildIntro() {
    final l10n = context.l10n;
    return FaceIntroView(
      title: l10n.faceIrisIntroTitle,
      body: l10n.faceIrisIntroBody,
      steps: [l10n.faceIrisStep1, l10n.faceIrisStep2, l10n.faceIrisStep3],
      onStart: _runVerification,
    );
  }

  Widget _buildLaunching() => FaceBusyView(label: _launchMessage);

  Widget _buildResult() {
    final error = _error;
    if (error != null) {
      return FaceResultView(
        icon: Icons.error_outline,
        color: Colors.red,
        title: context.l10n.faceSomethingWentWrong,
        subtitle: error,
        onRetry: _runVerification,
      );
    }

    return switch (_result?.outcome ?? IrisVerificationOutcome.failed) {
      IrisVerificationOutcome.matched => FaceResultView(
        icon: Icons.check_circle,
        color: Colors.green,
        title: context.l10n.faceIdentityVerified,
        subtitle: context.l10n.faceIrisMatchedSubtitle,
        documentPhoto: _documentPhoto,
        liveFace: switch (_result?.face) {
          final face? when face.isNotEmpty => face,
          _ => null,
        },
      ),
      IrisVerificationOutcome.failed => FaceResultView(
        icon: Icons.cancel,
        color: Colors.red,
        title: context.l10n.faceVerificationFailed,
        subtitle: context.l10n.faceIrisFailedSubtitle,
        documentPhoto: _documentPhoto,
        onRetry: _runVerification,
      ),
      IrisVerificationOutcome.cancelled => FaceResultView(
        icon: Icons.info_outline,
        color: Colors.orange,
        title: context.l10n.faceCancelled,
        subtitle: context.l10n.faceIrisCancelledSubtitle,
        onRetry: _runVerification,
      ),
    };
  }
}
