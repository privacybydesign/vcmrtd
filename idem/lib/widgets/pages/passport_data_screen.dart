import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/services/flow_step_plan.dart';
import 'package:idem/widgets/pages/data_screen_widgets/submit_to_proofing_session.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';

import '../../widgets/pages/data_screen_widgets/document_data_view.dart';
import '../../widgets/pages/data_screen_widgets/guided_document_data_view.dart';
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
  final PendingStep pendingStep;

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
    this.pendingStep = PendingStep.none,
    this.stepNumber = FlowStepPlan.defaultResultStep,
    this.totalSteps = FlowStepPlan.defaultTotalSteps,
  });

  @override
  Widget build(BuildContext context) {
    if (context.guided != null) return _buildGuided();
    return DocumentDataView(
      title: context.l10n.docDocumentDataTitle(documentType.name),
      document: document,
      rawDocument: passportDataResult,
      documentType: documentType,
      submittedTo: submittedTo,
      pendingStep: pendingStep,
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

  Widget _buildGuided() {
    final mrz = document.mrz;
    final isIdCard = documentType == DocumentType.identityCard;
    final date = DateFormat('d MMM y');
    return GuidedDocumentDataView(
      document: document,
      rawDocument: passportDataResult,
      documentType: documentType,
      submittedTo: submittedTo,
      pendingStep: pendingStep,
      onBackPressed: onBackPressed,
      documentName: isIdCard ? 'ID card' : 'passport',
      readTitle: 'Document read',
      photoImageData: document.photoImageData,
      photoImageType: document.photoImageType,
      holderName: _titleCase(document.displayName),
      subtitle: '${isIdCard ? 'ID card' : 'Passport'} · ${mrz.country}',
      details: [
        GuidedDetail('Date of birth', date.format(mrz.dateOfBirth)),
        GuidedDetail('Nationality', mrz.nationality),
        GuidedDetail('Document number', mrz.documentNumber, mono: true),
        GuidedDetail('Valid until', date.format(mrz.dateOfExpiry)),
      ],
    );
  }
}

/// "ANNA MARIA ERIKSSON" → "Anna Maria Eriksson"; chips store names in capitals.
String _titleCase(String name) =>
    name.toLowerCase().split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
