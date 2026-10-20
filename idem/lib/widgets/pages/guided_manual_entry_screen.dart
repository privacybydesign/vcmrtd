import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:idem/utils/document_dates.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/services/flow_step_plan.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';

/// Manual entry in the guided layout: the same fields and rules as
/// mrz_capture's [ManualEntryScreen] (see [ManualEntryRules]), drawn as step 1
/// of the guided flow.
class GuidedManualEntryScreen extends StatefulWidget {
  const GuidedManualEntryScreen({
    super.key,
    required this.documentType,
    required this.onBack,
    required this.onManualEntryComplete,
    this.stepNumber = FlowStepPlan.defaultDocumentCaptureStep,
    this.totalSteps = FlowStepPlan.defaultTotalSteps,
  });

  final DocumentType documentType;
  final VoidCallback onBack;
  final ValueChanged<ScannedMRZ> onManualEntryComplete;
  final int stepNumber;
  final int totalSteps;

  @override
  State<GuidedManualEntryScreen> createState() => _GuidedManualEntryScreenState();
}

enum _DateField { birth, expiry }

class _GuidedManualEntryScreenState extends State<GuidedManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _documentNumber = TextEditingController();
  final _mrzLine = TextEditingController();
  DateTime? _dateOfBirth;
  DateTime? _dateOfExpiry;
  String? _parseError;

  /// Off until the first failed submit, then fields re-check as they change.
  var _autovalidate = AutovalidateMode.disabled;

  bool get _usesMrzLine => ManualEntryRules.usesMrzLine(widget.documentType);

  @override
  void dispose() {
    _documentNumber.dispose();
    _mrzLine.dispose();
    super.dispose();
  }

  void _continue() {
    setState(() => _parseError = null);
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    if (_usesMrzLine) {
      try {
        widget.onManualEntryComplete(ScannedDriverLicenseMRZ.fromManualEntry(mrzString: _mrzLine.text.trim()));
      } catch (e) {
        setState(() => _parseError = context.l10n.manualLicenceParseError);
      }
      return;
    }
    widget.onManualEntryComplete(
      ScannedPassportMRZ.fromManualEntry(
        documentNumber: _documentNumber.text.trim().toUpperCase(),
        dateOfBirth: _dateOfBirth!,
        dateOfExpiry: _dateOfExpiry!,
        documentType: widget.documentType,
      ),
    );
  }

  Future<void> _pickDate(_DateField field) async {
    final birth = field == _DateField.birth;
    // Otherwise the number field regains focus, and the keyboard, when the picker closes.
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (birth ? _dateOfBirth : _dateOfExpiry) ?? DateTime(now.year + (birth ? -30 : 5), now.month, now.day),
      firstDate: birth ? DateTime(1900) : now,
      lastDate: birth ? now : DateTime(2050),
    );
    if (picked == null) return;
    setState(() => birth ? _dateOfBirth = picked : _dateOfExpiry = picked);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    final l10n = context.l10n;
    final docType = widget.documentType.name;
    final (title, intro) = _usesMrzLine
        ? (l10n.manualLicenceTitle, l10n.manualLicenceIntro(ManualEntryRules.mrzLineLength))
        : (l10n.manualDocumentTitle(docType), l10n.manualDocumentIntro(docType));
    return GuidedStatusBar(
      backdrop: Backdrop.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GuidedTopBar(
                  leading: GuidedRoundButton(
                    icon: Icons.chevron_left,
                    tooltip: l10n.manualBack,
                    onPressed: widget.onBack,
                  ),
                  center: GuidedTopBarTitle(l10n.manualTopBarTitle),
                ),
                GuidedStepBar(step: widget.stepNumber, total: widget.totalSteps),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GuidedStepLabel(step: widget.stepNumber, total: widget.totalSteps),
                        const SizedBox(height: 12),
                        Text(title, style: g.heading(26)),
                        const SizedBox(height: 12),
                        Text(intro, style: TextStyle(fontSize: 16, height: 1.5, color: g.bodyText)),
                        const SizedBox(height: 24),
                        ...(_usesMrzLine ? _mrzLineFields(g) : _documentFields(g)),
                        if (_parseError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _parseError!,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: g.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: guidedBottomButtonPadding,
                  child: GuidedButton(label: l10n.manualContinue, onPressed: _continue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _documentFields(GuidedStyle g) {
    final l10n = context.l10n;
    final mrzL10n = MrzCaptureLocalizations.of(context);
    final docType = widget.documentType.name;
    final name = widget.documentType.displayName;
    return [
      _GuidedFieldLabel(l10n.manualDocumentNumber(docType), style: g),
      Semantics(
        label: l10n.manualDocumentNumber(docType),
        child: TextFormField(
          controller: _documentNumber,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          inputFormatters: ManualEntryRules.documentNumberFormatters,
          style: TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 1, color: g.ink),
          decoration: _decoration(g, hint: l10n.manualDocumentNumberHint),
          validator: (value) =>
              ManualEntryRules.documentNumber(value, documentName: name, l10n: mrzL10n, docType: docType),
        ),
      ),
      const SizedBox(height: 18),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _GuidedDateField(
              label: l10n.manualDateOfBirth,
              value: _dateOfBirth,
              style: g,
              onTap: () => _pickDate(_DateField.birth),
              validator: () => ManualEntryRules.dateOfBirth(_dateOfBirth, l10n: mrzL10n),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _GuidedDateField(
              label: l10n.manualExpiryDate,
              value: _dateOfExpiry,
              style: g,
              onTap: () => _pickDate(_DateField.expiry),
              validator: () => ManualEntryRules.dateOfExpiry(
                _dateOfExpiry,
                documentName: name,
                dateOfBirth: _dateOfBirth,
                l10n: mrzL10n,
                docType: docType,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: g.actionTint.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20, color: g.action),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${l10n.manualWhereToFind}\n',
                      style: TextStyle(fontWeight: FontWeight.w700, color: g.ink),
                    ),
                    TextSpan(text: l10n.manualWhereToFindBody(docType)),
                  ],
                ),
                style: TextStyle(fontSize: 14, height: 1.45, color: g.bodyText),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _mrzLineFields(GuidedStyle g) {
    final length = _mrzLine.text.length;
    final complete = length == ManualEntryRules.mrzLineLength;
    return [
      AspectRatio(
        aspectRatio: _GuidedLicenceIllustration.size.aspectRatio,
        child: _GuidedLicenceIllustration(style: g),
      ),
      const SizedBox(height: 20),
      _GuidedFieldLabel(context.l10n.manualLicenceCode, style: g),
      Semantics(
        label: context.l10n.manualLicenceCode,
        child: TextFormField(
          controller: _mrzLine,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: ManualEntryRules.mrzLineFormatters,
          onChanged: (_) => setState(() {}),
          style: TextStyle(fontFamily: 'monospace', fontSize: 14, color: g.ink),
          decoration: _decoration(g, hint: 'D1NLD…'),
          validator: (value) => ManualEntryRules.mrzLine(value, l10n: MrzCaptureLocalizations.of(context)),
        ),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: Text(context.l10n.manualLicenceCodePrefix, style: TextStyle(fontSize: 13, color: g.bodyText)),
          ),
          if (complete) Icon(Icons.check, size: 14, color: g.success),
          const SizedBox(width: 4),
          Text(
            '$length / ${ManualEntryRules.mrzLineLength}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: complete ? g.successText : g.muted),
          ),
        ],
      ),
    ];
  }

  InputDecoration _decoration(GuidedStyle g, {required String hint}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: g.muted, letterSpacing: 0),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: _border(g.border, 1),
    focusedBorder: _border(g.action, 2),
    errorBorder: _border(g.error, 1),
    focusedErrorBorder: _border(g.error, 2),
    errorStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: g.error),
  );

  static OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: width),
  );
}

class _GuidedFieldLabel extends StatelessWidget {
  const _GuidedFieldLabel(this.text, {required this.style});

  final String text;
  final GuidedStyle style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: style.slate),
    ),
  );
}

/// A date that opens a picker, validated with the surrounding [Form].
class _GuidedDateField extends StatelessWidget {
  const _GuidedDateField({
    required this.label,
    required this.value,
    required this.style,
    required this.onTap,
    required this.validator,
  });

  final String label;
  final DateTime? value;
  final GuidedStyle style;
  final Future<void> Function() onTap;
  final String? Function() validator;

  @override
  Widget build(BuildContext context) {
    final g = style;
    final l10n = context.l10n;
    final formatted = value == null ? null : DateFormat(documentDatePattern, l10n.localeName).format(value!);
    return FormField<DateTime>(
      validator: (_) => validator(),
      builder: (field) {
        final error = field.errorText;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GuidedFieldLabel(label, style: g),
            Semantics(
              button: true,
              label: label,
              value: formatted ?? l10n.manualDateNotSet,
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: error != null ? g.error : g.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    await onTap();
                    field.didChange(null);
                  },
                  child: SizedBox(
                    height: 52,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatted ?? l10n.manualDateSelect,
                              style: TextStyle(fontSize: 16, color: value == null ? g.muted : g.ink),
                            ),
                          ),
                          Icon(Icons.calendar_today_outlined, size: 18, color: g.muted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  error,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: g.error),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The back of a driving licence with its code line highlighted, in a [size] box.
class _GuidedLicenceIllustration extends StatelessWidget {
  const _GuidedLicenceIllustration({required this.style});

  static const size = Size(342, 96);

  final GuidedStyle style;

  @override
  Widget build(BuildContext context) {
    final g = style;
    Widget bar(double top, double width) => Positioned(
      left: 16,
      top: top,
      child: Container(
        width: width,
        height: 8,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(4)),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: g.illustrationDocument,
        child: FittedBox(
          child: SizedBox.fromSize(
            size: size,
            child: Stack(
              children: [
                bar(16, 120),
                bar(32, 80),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 12,
                  child: Container(
                    height: 30,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: g.heroAccent.withValues(alpha: 0.18),
                      border: Border.all(color: g.heroAccent, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'D1NLD${'<' * 25}',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: g.actionTintStrong),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
