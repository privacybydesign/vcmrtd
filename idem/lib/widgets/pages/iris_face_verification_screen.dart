import 'dart:async';

import 'package:iris_sdk_flutter/iris_sdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:mrz_capture/mrz_capture.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/services/face_verification_outcome.dart';

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

  // Test-only: injects a verifier so tests don't have to hit the real plugin.
  final IrisFaceVerifier? testVerifier;

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
    this.stepNumber = 3,
    this.totalSteps = 4,
  }) : testVerifier = null;

  const IrisFaceVerificationScreen.withVerifier({
    super.key,
    required IrisFaceVerifier verifier,
    required this.nfcImageBytes,
    required this.onBackPressed,
    required this.onVerified,
    this.stepNumber = 3,
    this.totalSteps = 4,
  }) : testVerifier = verifier;

  @override
  State<IrisFaceVerificationScreen> createState() => _IrisFaceVerificationScreenState();
}

enum _Status { intro, launching, result }

class _IrisFaceVerificationScreenState extends State<IrisFaceVerificationScreen> {
  late final IrisFaceVerifier _verifier = widget.testVerifier ?? IrisFaceVerifier();

  _Status _status = _Status.intro;
  String _launchMessage = currentL10n.facePreparingDocumentPhoto;
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.verified_user, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            context.l10n.faceIrisIntroTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.faceIrisIntroBody,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.faceIrisWhatToExpect,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _IntroStepRow(number: '1', text: context.l10n.faceIrisStep1),
                const SizedBox(height: 6),
                _IntroStepRow(number: '2', text: context.l10n.faceIrisStep2),
                const SizedBox(height: 6),
                _IntroStepRow(number: '3', text: context.l10n.faceIrisStep3),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _runVerification,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.face),
            label: Text(context.l10n.faceStartVerification),
          ),
        ],
      ),
    );
  }

  Widget _buildLaunching() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(_launchMessage)],
      ),
    );
  }

  Widget _buildResult() {
    final error = _error;
    if (error != null) {
      return _ResultView(
        icon: Icons.error_outline,
        color: Colors.red,
        title: context.l10n.faceSomethingWentWrong,
        subtitle: error,
        onRetry: _runVerification,
      );
    }

    return switch (_result?.outcome ?? IrisVerificationOutcome.failed) {
      IrisVerificationOutcome.matched => _ResultView(
        icon: Icons.check_circle,
        color: Colors.green,
        title: context.l10n.faceIdentityVerified,
        subtitle: context.l10n.faceIrisMatchedSubtitle,
        documentPhoto: _documentPhoto,
        liveFace: switch (_result?.face) {
          final face? when face.isNotEmpty => face,
          _ => null,
        },
        isContinuing: true,
      ),
      IrisVerificationOutcome.failed => _ResultView(
        icon: Icons.cancel,
        color: Colors.red,
        title: context.l10n.faceVerificationFailed,
        subtitle: context.l10n.faceIrisFailedSubtitle,
        documentPhoto: _documentPhoto,
        onRetry: _runVerification,
      ),
      IrisVerificationOutcome.cancelled => _ResultView(
        icon: Icons.info_outline,
        color: Colors.orange,
        title: context.l10n.faceCancelled,
        subtitle: context.l10n.faceIrisCancelledSubtitle,
        onRetry: _runVerification,
      ),
    };
  }
}

class _IntroStepRow extends StatelessWidget {
  final String number;
  final String text;
  const _IntroStepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Colors.black12, shape: BoxShape.circle),
          child: Text(number, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Uint8List? documentPhoto;
  final Uint8List? liveFace;
  final VoidCallback? onRetry;
  final bool isContinuing;

  const _ResultView({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.documentPhoto,
    this.liveFace,
    this.onRetry,
    this.isContinuing = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 80, color: color),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          if (documentPhoto != null || liveFace != null) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (documentPhoto != null) _Thumbnail(label: context.l10n.faceDocumentPhoto, bytes: documentPhoto!),
                if (documentPhoto != null && liveFace != null) const SizedBox(width: 16),
                if (liveFace != null) _Thumbnail(label: context.l10n.faceLiveCapture, bytes: liveFace!),
              ],
            ),
          ],
          const SizedBox(height: 32),
          if (isContinuing)
            Center(
              child: Text(context.l10n.faceContinuing, style: const TextStyle(color: Colors.grey)),
            )
          else if (onRetry != null)
            OutlinedButton(onPressed: onRetry, child: Text(context.l10n.faceTryAgain)),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String label;
  final Uint8List bytes;
  const _Thumbnail({required this.label, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, width: 100, height: 100, fit: BoxFit.cover),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
