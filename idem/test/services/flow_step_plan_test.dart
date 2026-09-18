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

    test('the full 5-step vocabulary numbers exactly like the default plan', () {
      final plan = FlowStepPlan.fromSteps(['document_capture', 'nfc_read', 'selfie', 'liveness', 'face_match']);
      expect(plan.totalSteps, 4);
      expect(plan.documentCaptureStepNumber, 1);
      expect(plan.nfcReadStepNumber, 2);
      expect(plan.faceVerificationStepNumber, 3);
      expect(plan.resultStepNumber, 4);
    });

    test('document_capture alone is a 2-step plan (capture, result)', () {
      final plan = FlowStepPlan.fromSteps(['document_capture']);
      expect(plan.totalSteps, 2);
      expect(plan.documentCaptureStepNumber, 1);
      expect(plan.nfcReadStepNumber, isNull);
      expect(plan.faceVerificationStepNumber, isNull);
      expect(plan.resultStepNumber, 2);
    });

    test('document_capture + selfie skips the nfc_read slot entirely', () {
      final plan = FlowStepPlan.fromSteps(['document_capture', 'selfie']);
      expect(plan.totalSteps, 3);
      expect(plan.documentCaptureStepNumber, 1);
      expect(plan.nfcReadStepNumber, isNull);
      expect(plan.faceVerificationStepNumber, 2);
      expect(plan.resultStepNumber, 3);
    });

    test('document_capture is not guaranteed present: selfie + face_match alone starts numbering at 1', () {
      final plan = FlowStepPlan.fromSteps(['selfie', 'face_match']);
      expect(plan.totalSteps, 2);
      expect(plan.documentCaptureStepNumber, isNull);
      expect(plan.nfcReadStepNumber, isNull);
      expect(plan.faceVerificationStepNumber, 1);
      expect(plan.resultStepNumber, 2);
    });

    test('array order never affects numbering - only presence does', () {
      final reversed = FlowStepPlan.fromSteps(['face_match', 'nfc_read', 'document_capture']);
      expect(reversed.documentCaptureStepNumber, 1);
      expect(reversed.nfcReadStepNumber, 2);
      expect(reversed.faceVerificationStepNumber, 3);
      expect(reversed.resultStepNumber, 4);
    });

    test('a degenerate empty steps list is just a single result step', () {
      final plan = FlowStepPlan.fromSteps(const []);
      expect(plan.totalSteps, 1);
      expect(plan.documentCaptureStepNumber, isNull);
      expect(plan.nfcReadStepNumber, isNull);
      expect(plan.faceVerificationStepNumber, isNull);
      expect(plan.resultStepNumber, 1);
    });
  });
}
