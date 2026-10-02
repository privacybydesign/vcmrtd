import 'package:flutter/material.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/services/flow_step_plan.dart';

import '../../widgets/pages/data_screen_widgets/document_data_view.dart';
import '../../widgets/pages/data_screen_widgets/personal_data_section.dart';
import '../../widgets/pages/data_screen_widgets/security_content.dart';

class PassportDataScreen extends StatelessWidget {
  final PassportData document;
  final RawDocumentData passportDataResult;
  final VoidCallback onBackPressed;
  final DocumentType documentType;

  /// Set when every step was already sent to the session as it completed -
  /// see [DocumentDataView.submittedTo].
  final String? submittedTo;
  final bool browserFaceStep;

  /// Step badge numbers — default to vcmrtd's fixed 4-step sequence (this
  /// screen is always the last, step 4, there) so any caller not passing
  /// these explicitly keeps today's behaviour; routing.dart passes a
  /// session's actual FlowStepPlan values when a QR/deep-link flow governs
  /// the numbering.
  final int stepNumber;
  final int totalSteps;

  const PassportDataScreen({
    super.key,
    required this.document,
    required this.onBackPressed,
    required this.passportDataResult,
    this.documentType = DocumentType.passport,
    this.submittedTo,
    this.browserFaceStep = false,
    this.stepNumber = FlowStepPlan.defaultResultStep,
    this.totalSteps = FlowStepPlan.defaultTotalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return DocumentDataView(
      title: context.l10n.docDocumentDataTitle(documentType.name),
      document: document,
      rawDocument: passportDataResult,
      documentType: documentType,
      submittedTo: submittedTo,
      browserFaceStep: browserFaceStep,
      onBackPressed: onBackPressed,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
      children: [
        PersonalDataSection(passport: document),
        const SizedBox(height: 20),
        SecurityContent(passport: document),
      ],
    );
  }
}
