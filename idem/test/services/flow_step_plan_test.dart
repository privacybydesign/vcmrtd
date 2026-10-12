import 'package:flutter_test/flutter_test.dart';
import 'package:idem/services/flow_step_plan.dart';

void main() {
  group('FlowStepPlan.fromSteps', () {
    test('null steps produces the fixed 4-step default (matches every screen\'s old hard-coded numbering)', () {
      final plan = FlowStepPlan.fromSteps(null);
      expect(plan.totalSteps, 4);
      expect(plan.documentCaptureStepNumber, 1);
      expect(plan.nfcReadStepNumber, 2);
      expect(plan.faceVerificationStepNumber, 3);
      expect(plan.resultStepNumber, 4);
    });

    test(
      'the full 5-step vocabulary numbers like the default plan, without its result step (the last step submits)',
      () {
        final plan = FlowStepPlan.fromSteps(['document_capture', 'nfc_read', 'selfie', 'liveness', 'face_match']);
        expect(plan.totalSteps, 3);
        expect(plan.documentCaptureStepNumber, 1);
        expect(plan.nfcReadStepNumber, 2);
        expect(plan.faceVerificationStepNumber, 3);
        expect(plan.resultStepNumber, 3);
      },
    );

    test('document_capture alone is a 1-step plan: the capture is also the submit', () {
      final plan = FlowStepPlan.fromSteps(['document_capture']);
      expect(plan.totalSteps, 1);
      expect(plan.documentCaptureStepNumber, 1);
      expect(plan.nfcReadStepNumber, isNull);
      expect(plan.faceVerificationStepNumber, isNull);
      expect(plan.resultStepNumber, 1);
    });

    test('document_capture + selfie skips the nfc_read slot entirely', () {
      final plan = FlowStepPlan.fromSteps(['document_capture', 'selfie']);
      expect(plan.totalSteps, 2);
      expect(plan.documentCaptureStepNumber, 1);
      expect(plan.nfcReadStepNumber, isNull);
      expect(plan.faceVerificationStepNumber, 2);
      expect(plan.resultStepNumber, 2);
    });

    test('document_capture is not guaranteed present: selfie + face_match alone starts numbering at 1', () {
      final plan = FlowStepPlan.fromSteps(['selfie', 'face_match']);
      expect(plan.totalSteps, 1);
      expect(plan.documentCaptureStepNumber, isNull);
      expect(plan.nfcReadStepNumber, isNull);
      expect(plan.faceVerificationStepNumber, 1);
      expect(plan.resultStepNumber, 1);
    });

    test('the aggregate "face_verification" step is recognised same as the granular sub-steps', () {
      final plan = FlowStepPlan.fromSteps(['document_capture', 'nfc_read', 'face_verification']);
      expect(plan.totalSteps, 3);
      expect(plan.documentCaptureStepNumber, 1);
      expect(plan.nfcReadStepNumber, 2);
      expect(plan.faceVerificationStepNumber, 3);
      expect(plan.resultStepNumber, 3);
    });

    test('selfieLocation "browser" drops face_verification out of THIS APP\'s own step count entirely, even '
        'though the flow lists it', () {
      final plan = FlowStepPlan.fromSteps([
        'document_capture',
        'nfc_read',
        'face_verification',
      ], selfieLocation: 'browser');
      expect(plan.totalSteps, 2);
      expect(plan.documentCaptureStepNumber, 1);
      expect(plan.nfcReadStepNumber, 2);
      expect(plan.faceVerificationStepNumber, isNull);
      expect(plan.resultStepNumber, 2);
    });

    test('selfieLocation "browser" has no effect when the flow has no face stage at all', () {
      final plan = FlowStepPlan.fromSteps(['document_capture', 'nfc_read'], selfieLocation: 'browser');
      expect(plan.totalSteps, 2);
      expect(plan.documentCaptureStepNumber, 1);
      expect(plan.nfcReadStepNumber, 2);
      expect(plan.faceVerificationStepNumber, isNull);
      expect(plan.resultStepNumber, 2);
    });

    test('array order never affects numbering - only presence does', () {
      final reversed = FlowStepPlan.fromSteps(['face_match', 'nfc_read', 'document_capture']);
      expect(reversed.documentCaptureStepNumber, 1);
      expect(reversed.nfcReadStepNumber, 2);
      expect(reversed.faceVerificationStepNumber, 3);
      expect(reversed.resultStepNumber, 3);
    });

    test('document_photo shares the document scan\'s number, wherever the flow lists it', () {
      for (final steps in [
        ['document_capture', 'nfc_read', 'document_photo', 'face_verification'],
        ['document_capture', 'document_photo', 'nfc_read', 'face_verification'],
        ['document_photo', 'document_capture', 'nfc_read', 'face_verification'],
      ]) {
        final plan = FlowStepPlan.fromSteps(steps, selfieLocation: 'native');
        expect(plan.totalSteps, 3, reason: '$steps');
        expect(plan.documentCaptureStepNumber, 1, reason: '$steps');
        expect(plan.documentPhotoStepNumber, 1, reason: '$steps');
        expect(plan.nfcReadStepNumber, 2, reason: '$steps');
        expect(plan.faceVerificationStepNumber, 3, reason: '$steps');
      }
    });

    test('without a document scan, document_photo is numbered where the flow lists it', () {
      final first = FlowStepPlan.fromSteps(['document_photo', 'face_verification'], selfieLocation: 'native');
      expect(first.documentPhotoStepNumber, 1);
      expect(first.faceVerificationStepNumber, 2);
      expect(first.totalSteps, 2);

      final last = FlowStepPlan.fromSteps(['face_verification', 'document_photo'], selfieLocation: 'native');
      expect(last.faceVerificationStepNumber, 1);
      expect(last.documentPhotoStepNumber, 2);
      expect(last.resultStepNumber, 2);
    });

    test('document_photo alone is a 1-step plan, and counts even when the browser does the face step', () {
      final alone = FlowStepPlan.fromSteps(['document_photo']);
      expect(alone.totalSteps, 1);
      expect(alone.documentPhotoStepNumber, 1);
      expect(alone.documentCaptureStepNumber, isNull);

      final browserFace = FlowStepPlan.fromSteps(['selfie', 'document_photo'], selfieLocation: 'browser');
      expect(browserFace.totalSteps, 1);
      expect(browserFace.documentPhotoStepNumber, 1);
      expect(browserFace.faceVerificationStepNumber, isNull);
    });

    test('the default plan (no flow) has no document_photo step', () {
      expect(FlowStepPlan.fromSteps(null).documentPhotoStepNumber, isNull);
      expect(FlowStepPlan.fromSteps(['document_capture', 'nfc_read']).documentPhotoStepNumber, isNull);
    });

    test('a degenerate empty steps list still counts one step', () {
      final plan = FlowStepPlan.fromSteps(const []);
      expect(plan.totalSteps, 1);
      expect(plan.documentCaptureStepNumber, isNull);
      expect(plan.nfcReadStepNumber, isNull);
      expect(plan.faceVerificationStepNumber, isNull);
      expect(plan.resultStepNumber, 1);
    });
  });
}
