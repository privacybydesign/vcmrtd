// Created for UX improvement - Simple manual data entry screen
// Allows users to enter passport data manually: DOB, expiry date, document number

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:intl/intl.dart';
import 'package:vcmrtd/vcmrtd.dart';
import '../l10n/mrz_capture_localizations.dart';
import 'scanned_mrz.dart';
import 'step_badge.dart';

/// Fallback for when scanning will not work: the user types the fields the chip
/// needs. Reports the same [ScannedMRZ] shape the scanner does.
class ManualEntryScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Function(ScannedMRZ) onManualEntryComplete;
  final DocumentType documentType;

  /// Step badge numbers - default to the fixed 4-step sequence, where
  /// document capture is step 1.
  final int stepNumber;
  final int totalSteps;

  const ManualEntryScreen({
    super.key,
    required this.onBack,
    required this.onManualEntryComplete,
    required this.documentType,
    this.stepNumber = 1,
    this.totalSteps = 4,
  });

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  final _docNumberController = TextEditingController();
  final _dobController = TextEditingController();
  final _expiryController = TextEditingController();
  final _mrzController = TextEditingController();

  DateTime? _selectedDob;
  DateTime? _selectedExpiry;
  String _errorMessage = '';

  /// The host app's language when it registers
  /// [MrzCaptureLocalizations.delegate], English otherwise.
  MrzCaptureLocalizations get _l10n =>
      MrzCaptureLocalizations.of(context) ?? lookupMrzCaptureLocalizations(const Locale('en'));

  String get _docType => widget.documentType.name;

  /// A driving licence is entered as its MRZ line; a passport or identity
  /// card as its document number and dates.
  bool get _isDrivingLicence => widget.documentType == DocumentType.drivingLicence;

  @override
  void dispose() {
    _docNumberController.dispose();
    _dobController.dispose();
    _expiryController.dispose();
    _mrzController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 32),
                      if (_isDrivingLicence) ..._buildDriverLicenseFields() else ..._buildPassportFields(),
                      const SizedBox(height: 24),
                      if (_errorMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 14)),
                              ),
                            ],
                          ),
                        ),
                      PlatformElevatedButton(
                        onPressed: _handleContinue,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            _l10n.mrzContinueToNfc,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildHelpText(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return StepBadgeTopBar(
      icon: PlatformIcons(context).back,
      onBack: widget.onBack,
      current: widget.stepNumber,
      total: widget.totalSteps,
      label: _l10n.mrzEnterDetailsLabel(_docType),
    );
  }

  Widget _buildHelpText() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _l10n.mrzWhereToFind,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          Text(switch (widget.documentType) {
            DocumentType.drivingLicence => _l10n.mrzHelpDrivingLicence,
            DocumentType.identityCard => _l10n.mrzHelpIdentityCard,
            DocumentType.passport => _l10n.mrzHelpPassport,
          }, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.4)),
        ],
      ),
    );
  }

  List<Widget> _buildPassportFields() {
    return [
      _buildInputCard(
        title: _l10n.mrzDocNumberTitle(_docType),
        hint: _l10n.mrzDocNumberHint(_docType),
        icon: Icons.numbers,
        child: PlatformTextFormField(
          controller: _docNumberController,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
            LengthLimitingTextInputFormatter(15),
          ],
          hintText: _l10n.mrzDocNumberExample,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return _l10n.mrzDocNumberRequired(_docType);
            }
            if (value.trim().length < 6) {
              return _l10n.mrzDocNumberTooShort(_docType);
            }
            return null;
          },
        ),
      ),
      const SizedBox(height: 16),
      _buildInputCard(
        title: _l10n.mrzDobTitle,
        hint: _l10n.mrzDobHint,
        icon: Icons.cake,
        child: PlatformTextFormField(
          controller: _dobController,
          readOnly: true,
          hintText: _l10n.mrzTapToSelectDate,
          onTap: () => _selectDate(context, isDateOfBirth: true),
          validator: (value) {
            if (_selectedDob == null) {
              return _l10n.mrzDobRequired;
            }
            if (_selectedDob!.isAfter(DateTime.now())) {
              return _l10n.mrzDobInFuture;
            }
            return null;
          },
        ),
      ),
      const SizedBox(height: 16),
      _buildInputCard(
        title: _l10n.mrzExpiryTitle,
        hint: _l10n.mrzExpiryHint(_docType),
        icon: Icons.event_busy,
        child: PlatformTextFormField(
          controller: _expiryController,
          readOnly: true,
          hintText: _l10n.mrzTapToSelectDate,
          onTap: () => _selectDate(context, isDateOfBirth: false),
          validator: (value) {
            if (_selectedExpiry == null) {
              return _l10n.mrzExpiryRequired;
            }
            if (_selectedExpiry!.isBefore(DateTime.now())) {
              return _l10n.mrzDocumentExpired(_docType);
            }
            if (_selectedDob != null && _selectedExpiry!.isBefore(_selectedDob!)) {
              return _l10n.mrzExpiryBeforeDob;
            }
            return null;
          },
        ),
      ),
    ];
  }

  List<Widget> _buildDriverLicenseFields() {
    return [
      _buildInputCard(
        title: _l10n.mrzStringTitle,
        hint: _l10n.mrzStringHint,
        icon: Icons.keyboard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlatformTextFormField(
              controller: _mrzController,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              maxLines: 1,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9<]')),
                LengthLimitingTextInputFormatter(30),
              ],
              hintText: 'D1NLD15094962111659VW87Z78NB84',
              style: const TextStyle(fontFamily: 'Courier', fontSize: 14),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return _l10n.mrzStringRequired;
                }
                if (value.trim().length != 30) {
                  return _l10n.mrzStringLength;
                }
                if (!value.startsWith('D1') && !value.startsWith('D2') && !value.startsWith('DL')) {
                  return _l10n.mrzStringPrefix;
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_l10n.mrzCharacterCount, style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                ValueListenableBuilder(
                  valueListenable: _mrzController,
                  builder: (context, value, _) => Text(
                    '${value.text.length} / 30',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: value.text.length == 30 ? Colors.green : const Color(0xFF666666),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildInputCard({required String title, required String hint, required IconData icon, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6b6868).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: const Color(0xFF6b6868)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF212121)),
                      ),
                      Text(hint, style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, {required bool isDateOfBirth}) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = isDateOfBirth
        ? DateTime(now.year - 30, now.month, now.day)
        : DateTime(now.year + 10, now.month, now.day);

    final DateTime firstDate = isDateOfBirth ? DateTime(1900) : now;
    final DateTime lastDate = isDateOfBirth ? now : DateTime(2050);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: const Color(0xFF6b6868))),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatter = DateFormat.yMd();
      setState(() {
        if (isDateOfBirth) {
          _selectedDob = picked;
          _dobController.text = formatter.format(picked);
        } else {
          _selectedExpiry = picked;
          _expiryController.text = formatter.format(picked);
        }
        _errorMessage = '';
      });
    }
  }

  void _handleContinue() {
    setState(() {
      _errorMessage = '';
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final scannedMrz = switch (widget.documentType) {
      DocumentType.passport || DocumentType.identityCard => _createScannedPassport(),
      DocumentType.drivingLicence => _createScannedDriverLicense(),
    };

    if (scannedMrz != null) {
      widget.onManualEntryComplete(scannedMrz);
    }
  }

  /// The form's validators already required both dates.
  ScannedPassportMRZ _createScannedPassport() {
    return ScannedPassportMRZ.fromManualEntry(
      documentNumber: _docNumberController.text.trim().toUpperCase(),
      dateOfBirth: _selectedDob!,
      dateOfExpiry: _selectedExpiry!,
      documentType: widget.documentType,
    );
  }

  ScannedDriverLicenseMRZ? _createScannedDriverLicense() {
    try {
      return ScannedDriverLicenseMRZ.fromManualEntry(mrzString: _mrzController.text.trim().toUpperCase());
    } catch (e) {
      setState(() {
        _errorMessage = _l10n.mrzParseFailed('$e');
      });
      return null;
    }
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF6b6868).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                _isDrivingLicence ? Icons.text_fields : Icons.edit_document,
                size: 30,
                color: const Color(0xFF6b6868),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isDrivingLicence ? _l10n.mrzHeaderTitleMrz : _l10n.mrzHeaderTitle(_docType),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF212121)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isDrivingLicence ? _l10n.mrzHeaderSubtitleMrz : _l10n.mrzHeaderSubtitle(_docType),
              style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
