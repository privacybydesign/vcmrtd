import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

enum VerificationState { idle, activeLiveness, processing, result }

String faceActionLabel(String action) => switch (action) {
  'BLINK' => 'Blink your eyes',
  'TURN_LEFT' => 'Turn your head left',
  'TURN_RIGHT' => 'Turn your head right',
  'MOUTH_OPEN' => 'Open your mouth',
  'SMILE' => 'Smile',
  _ => action,
};

IconData faceActionIcon(String action) => switch (action) {
  'BLINK' => Icons.visibility_off,
  'TURN_LEFT' => Icons.arrow_back,
  'TURN_RIGHT' => Icons.arrow_forward,
  'MOUTH_OPEN' => Icons.sentiment_neutral,
  'SMILE' => Icons.sentiment_satisfied,
  _ => Icons.face,
};

double faceMatchThreshold(DateTime? photoIssueDate) {
  if (photoIssueDate == null) return 0.60;
  final ageYears = DateTime.now().difference(photoIssueDate).inDays / 365.25;
  if (ageYears <= 3) return 0.65;
  if (ageYears <= 7) return 0.60;
  return 0.55;
}


Widget buildFaceOvalOverlay() => const Center(
  child: AspectRatio(
    aspectRatio: 3 / 4,
    child: CustomPaint(painter: FaceOvalPainter()),
  ),
);

Widget buildFaceCameraPreview(CameraController? ctrl) {
  if (ctrl == null || !ctrl.value.isInitialized) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text('Opening camera...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
  return ColoredBox(
    color: Colors.black,
    child: Center(
      child: AspectRatio(aspectRatio: 3 / 4, child: CameraPreview(ctrl)),
    ),
  );
}

Widget buildFaceIdleScreen({
  required CameraController? cameraController,
  required bool ready,
  required bool startingLiveness,
  required VoidCallback onStart,
}) {
  return Stack(
    fit: StackFit.expand,
    children: [
      buildFaceCameraPreview(cameraController),
      buildFaceOvalOverlay(),
      Positioned(
        bottom: 24,
        left: 20,
        right: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How it works',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  FaceStepRow(number: '1', text: 'Center your face inside the oval'),
                  SizedBox(height: 4),
                  FaceStepRow(number: '2', text: 'Tap the button below'),
                  SizedBox(height: 4),
                  FaceStepRow(number: '3', text: 'Follow the on-screen prompts'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (ready && !startingLiveness) ? onStart : null,
                icon: startingLiveness
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.face),
                label: Text(startingLiveness ? 'Preparing...' : 'Start Verification'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget buildFaceActiveLivenessScreen({
  required CameraController? cameraController,
  required String? currentAction,
  required bool actionFlash,
  required List<String> actions,
  required Set<String> completedActions,
  required bool extraActionMode,
}) {
  final isAligning = currentAction == null;
  return Stack(
    fit: StackFit.expand,
    children: [
      buildFaceCameraPreview(cameraController),
      if (actionFlash) Container(color: Colors.green.withValues(alpha: 0.25)),
      if (isAligning) ...buildFaceAlignmentOverlay(),
      if (!isAligning)
        buildFaceActionChecklist(
          currentAction: currentAction,
          actions: actions,
          completedActions: completedActions,
          extraActionMode: extraActionMode,
        ),
      if (currentAction != null) buildFaceActionInstruction(currentAction),
    ],
  );
}

List<Widget> buildFaceAlignmentOverlay() => [
  buildFaceOvalOverlay(),
  Positioned(
    bottom: 40,
    left: 24,
    right: 24,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(24)),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
          SizedBox(width: 10),
          Text('Hold still - reading your face...', style: TextStyle(color: Colors.white70, fontSize: 15)),
        ],
      ),
    ),
  ),
];

Widget buildFaceActionChecklist({
  required String currentAction,
  required List<String> actions,
  required Set<String> completedActions,
  required bool extraActionMode,
}) =>
    Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: actions.asMap().entries.map((e) {
            final done = completedActions.contains(e.value);
            final current = e.value == currentAction;
            final iconWhenNotDone = current ? Icons.radio_button_checked : Icons.radio_button_unchecked;
            final itemIcon = done ? Icons.check_circle : iconWhenNotDone;
            final colorWhenNotDone = current ? Colors.white : Colors.white38;
            final itemColor = done ? Colors.green : colorWhenNotDone;
            final itemWeight = current ? FontWeight.bold : FontWeight.normal;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(itemIcon, color: itemColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      faceActionLabel(e.value),
                      style: TextStyle(color: itemColor, fontWeight: itemWeight),
                    ),
                  ),
                  if (extraActionMode && e.key == actions.length - 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                      child: const Text('extra', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );

Widget buildFaceActionInstruction(String action) => Positioned(
  bottom: 40,
  left: 24,
  right: 24,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(24)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(faceActionIcon(action), color: Colors.white, size: 28),
        const SizedBox(width: 12),
        Text(
          faceActionLabel(action),
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  ),
);

Widget buildFaceProcessingScreen() => const Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      CircularProgressIndicator(),
      SizedBox(height: 24),
      Text('Verifying identity...', style: TextStyle(fontSize: 16)),
    ],
  ),
);

Widget buildFaceErrorScreen({
  required String errorMessage,
  required VoidCallback onBack,
  required VoidCallback onRetry,
}) =>
    Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onBack, child: const Text('Go Back')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );

class FaceStepRow extends StatelessWidget {
  final String number;
  final String text;
  const FaceStepRow({required this.number, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
          child: Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      ],
    );
  }
}

class FaceOvalPainter extends CustomPainter {
  const FaceOvalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width * 0.50, size.height * 0.46),
      width: size.width * 0.80,
      height: size.height * 0.90,
    );

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black.withValues(alpha: 0.50));
    canvas.drawOval(ovalRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(FaceOvalPainter old) => false;
}
