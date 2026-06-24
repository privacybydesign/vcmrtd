import 'package:flutter/material.dart';
import 'package:vcmrtdapp/models/face_verification_args.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_screen.dart';
import 'package:vcmrtdapp/widgets/pages/on_device_face_verification_screen.dart';

/// Lets the user choose how to verify their face:
///
/// - **On-device** — fully offline, open-source TFLite models (face matching +
///   liveness) run on the phone. Nothing leaves the device. Needs the decoded
///   chip portrait.
/// - **Remote** — selected camera frames are streamed to the
///   face-verification-service (20Face SDK) which does matching + liveness, and
///   the issuer learns the signed result. Needs a face session started by the
///   issuer (and the raw portrait for the binding key).
enum FaceVerificationMethod { onDevice, remote }

class FaceVerificationEntryScreen extends StatefulWidget {
  final FaceVerificationArgs args;
  final VoidCallback onBackPressed;

  const FaceVerificationEntryScreen({super.key, required this.args, required this.onBackPressed});

  @override
  State<FaceVerificationEntryScreen> createState() => _FaceVerificationEntryScreenState();
}

class _FaceVerificationEntryScreenState extends State<FaceVerificationEntryScreen> {
  FaceVerificationMethod? _method;

  bool get _onDeviceAvailable =>
      widget.args.portraitImageBytes != null && widget.args.portraitImageBytes!.isNotEmpty;

  bool get _remoteAvailable => widget.args.canVerifyRemotely;

  void _backToChooser() => setState(() => _method = null);

  @override
  Widget build(BuildContext context) {
    switch (_method) {
      case FaceVerificationMethod.onDevice:
        return OnDeviceFaceVerificationScreen(
          nfcImageBytes: widget.args.portraitImageBytes,
          photoIssueDate: widget.args.issueDate,
          onBackPressed: _backToChooser,
        );
      case FaceVerificationMethod.remote:
        return FlutterFaceVerificationScreen(args: widget.args, onBackPressed: _backToChooser);
      case null:
        return _buildChooser(context);
    }
  }

  Widget _buildChooser(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Verification'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackPressed,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            Text(
              'Choose how to verify your face',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Both check that your live face matches the portrait on the chip.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _MethodCard(
              icon: Icons.phonelink_lock,
              color: Colors.indigo,
              title: 'On-device (open source)',
              subtitle:
                  'Runs entirely on your phone using open-source models. No image or video '
                  'leaves the device. Includes active or passive liveness.',
              available: _onDeviceAvailable,
              unavailableReason: 'Requires a chip portrait (DG2/DG6).',
              onTap: () => setState(() => _method = FaceVerificationMethod.onDevice),
            ),
            const SizedBox(height: 16),
            _MethodCard(
              icon: Icons.cloud_outlined,
              color: Colors.teal,
              title: 'Remote (face service)',
              subtitle:
                  'Streams selected camera frames to the face verification service for '
                  'matching + liveness; the issuer receives a signed result.',
              available: _remoteAvailable,
              unavailableReason:
                  'No verification session was started for this document, or the issuer has '
                  'face verification disabled.',
              onTap: () => setState(() => _method = FaceVerificationMethod.remote),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.available,
    required this.unavailableReason,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool available;
  final String unavailableReason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: available ? 1.0 : 0.55,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: available ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                      if (!available) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 15, color: Colors.orange),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                unavailableReason,
                                style: const TextStyle(color: Colors.orange, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (available) const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
