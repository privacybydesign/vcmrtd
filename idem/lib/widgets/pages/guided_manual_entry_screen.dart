import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/vcmrtd.dart';
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
  });

  final DocumentType documentType;
  final VoidCallback onBack;
  final ValueChanged<ScannedMRZ> onManualEntryComplete;

  @override
  State<GuidedManualEntryScreen> createState() => _GuidedManualEntryScreenState();
}

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

  String get _documentName => switch (widget.documentType) {
    DocumentType.passport => 'passport',
    DocumentType.identityCard => 'ID card',
    DocumentType.drivingLicence => 'driving licence',
  };

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
        setState(() => _parseError = 'That code could not be read. Check it against your licence and try again.');
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

  Future<void> _pickDate({required bool birth}) async {
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
    final (title, intro) = _usesMrzLine
        ? (
            'Type the code from your driving licence',
            'It’s the single line of ${ManualEntryRules.mrzLineLength} characters on the back. It unlocks the chip.',
          )
        : (
            'Enter your $_documentName details',
            'Copy them from the ${widget.documentType == DocumentType.passport ? 'photo page' : 'front of the card'}. '
                'They unlock the chip, so they need to match exactly.',
          );
    return GuidedStatusBar(
      onDark: false,
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
                  leading: GuidedRoundButton(icon: Icons.chevron_left, tooltip: 'Back', onPressed: widget.onBack),
                  center: const GuidedTopBarTitle('Enter details'),
                ),
                const GuidedStepBar(step: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const GuidedStepLabel(step: 1),
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
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _errorColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: GuidedButton(label: 'Continue', onPressed: _continue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _documentFields(GuidedStyle g) {
    final name = widget.documentType.displayName;
    return [
      _GuidedFieldLabel('${name[0]}${name.substring(1).toLowerCase()} number', style: g),
      TextFormField(
        controller: _documentNumber,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        inputFormatters: ManualEntryRules.documentNumberFormatters,
        style: TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 1, color: g.ink),
        decoration: _decoration(g, hint: 'e.g. AB1234567'),
        validator: (value) => ManualEntryRules.documentNumber(value, documentName: name),
      ),
      const SizedBox(height: 18),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _GuidedDateField(
              label: 'Date of birth',
              value: _dateOfBirth,
              style: g,
              onTap: () => _pickDate(birth: true),
              validator: () => ManualEntryRules.dateOfBirth(_dateOfBirth),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _GuidedDateField(
              label: 'Expiry date',
              value: _dateOfExpiry,
              style: g,
              onTap: () => _pickDate(birth: false),
              validator: () =>
                  ManualEntryRules.dateOfExpiry(_dateOfExpiry, documentName: name, dateOfBirth: _dateOfBirth),
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
                      text: 'Where to find them\n',
                      style: TextStyle(fontWeight: FontWeight.w700, color: g.ink),
                    ),
                    TextSpan(
                      text: widget.documentType == DocumentType.passport
                          ? 'The passport number is at the top right of the photo page. The dates are listed as '
                                'date of birth and date of expiry.'
                          : 'The document number and both dates are on the card, next to your photo.',
                    ),
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
        aspectRatio: 342 / 96,
        child: _GuidedLicenceIllustration(style: g),
      ),
      const SizedBox(height: 20),
      _GuidedFieldLabel('Licence code', style: g),
      TextFormField(
        controller: _mrzLine,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        enableSuggestions: false,
        inputFormatters: ManualEntryRules.mrzLineFormatters,
        onChanged: (_) => setState(() {}),
        style: TextStyle(fontFamily: 'monospace', fontSize: 14, color: g.ink),
        decoration: _decoration(g, hint: 'D1NLD…'),
        validator: ManualEntryRules.mrzLine,
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: Text('Starts with D1, D2 or DL', style: TextStyle(fontSize: 13, color: g.bodyText)),
          ),
          if (complete) Icon(Icons.check, size: 14, color: g.success),
          const SizedBox(width: 4),
          Text(
            '$length / ${ManualEntryRules.mrzLineLength}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: complete ? g.success : g.muted),
          ),
        ],
      ),
    ];
  }

  InputDecoration _decoration(GuidedStyle g, {required String hint}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: g.muted, fontFamily: 'Nunito', letterSpacing: 0),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: _border(g.border, 1),
    focusedBorder: _border(g.action, 2),
    errorBorder: _border(_errorColor, 1),
    focusedErrorBorder: _border(_errorColor, 2),
    errorStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _errorColor),
  );

  static OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: width),
  );
}

const _errorColor = Color(0xFFD1293D);

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
              value: value == null ? 'Not set' : DateFormat('d MMM y').format(value!),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: error != null ? _errorColor : g.border),
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
                              value == null ? 'Select' : DateFormat('d MMM y').format(value!),
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
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _errorColor),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The back of a driving licence with its code line highlighted, in a 342×96 box.
class _GuidedLicenceIllustration extends StatelessWidget {
  const _GuidedLicenceIllustration({required this.style});

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
          child: SizedBox(
            width: 342,
            height: 96,
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
