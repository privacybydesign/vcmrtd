import 'package:flutter/material.dart';
import 'package:face_verification/face_verification.dart';

/// First step of face verification: the user picks how to prove liveness before
/// any camera opens. Active/Passive run the on-device engine on the next
/// screen; Regula launches its own native liveness UI directly.
class FaceMethodSelectionScreen extends StatelessWidget {
  final VoidCallback onBackPressed;
  final void Function(LivenessMode mode) onModeSelected;
  final VoidCallback onRegulaSelected;

  /// True while the Regula native session is running — disables the buttons and
  /// shows a spinner on the Regula option.
  final bool regulaBusy;

  const FaceMethodSelectionScreen({
    super.key,
    required this.onBackPressed,
    required this.onModeSelected,
    required this.onRegulaSelected,
    this.regulaBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Verification'),
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: onBackPressed),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _InfoCard(),
              const SizedBox(height: 28),
              const Text('Choose a method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _MethodButton(
                icon: Icons.face,
                label: 'Passive Liveness',
                subtitle: 'Hands-free — just hold still',
                onPressed: regulaBusy ? null : () => onModeSelected(LivenessMode.passive),
              ),
              const SizedBox(height: 10),
              _MethodButton(
                icon: Icons.face_retouching_natural,
                label: 'Active Liveness',
                subtitle: 'Follow the on-screen actions',
                onPressed: regulaBusy ? null : () => onModeSelected(LivenessMode.active),
              ),
              const SizedBox(height: 10),
              _MethodButton(
                icon: Icons.verified_user,
                label: 'Regula Liveness',
                subtitle: 'Regula SDK with document match',
                busy: regulaBusy,
                onPressed: regulaBusy ? null : onRegulaSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How it works', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'We check that a live person is present, then compare that face against '
            'the portrait stored on your document to confirm it is really you.',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _MethodButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onPressed;
  final bool busy;

  const _MethodButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.green[600]!.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white70,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        children: [
          busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(icon, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    );
  }
}
