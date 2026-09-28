// Created for UX improvement - Simple manual data entry screen
// Allows users to enter passport data manually: DOB, expiry date, document number

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:intl/intl.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'manual_entry_rules.dart';
import 'scanned_mrz.dart';
import 'step_badge.dart';

/// Fallback for when scanning will not work: the user types the fields the chip
/// needs. Reports the same [ScannedMRZ] shape the scanner does.
class ManualEntryScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Function(ScannedMRZ) onManualEntryComplete;
  final DocumentType documentType;

  const ManualEntryScreen({
    super.key,
    required this.onBack,
    required this.onManualEntryComplete,
    required this.documentType,
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
                      if (ManualEntryRules.usesMrzLine(widget.documentType))
                        ..._buildDriverLicenseFields()
                      else
                        ..._buildPassportFields(),
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
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Continue to NFC Reading',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
      current: 1,
      total: 4,
      label: 'Enter ${widget.documentType.displayName} details',
    );
  }

  Widget _buildHelpText() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where to find this information:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          Text(
            !ManualEntryRules.usesMrzLine(widget.documentType)
                ? '• ${widget.documentType.displayName} Number: Usually at the top right of the photo page\n'
                      '• Date of Birth: Listed as "Date of birth" or "DOB"\n'
                      '• Expiry Date: Listed as "Date of expiry" or "Valid until"'
                : '• The MRZ is at the bottom of the front side of your driver\'s licence\n'
                      '• You can also get this by scanning the QR Code on the back of your driver\'s licence\n'
                      '• It\'s a single line of exactly 30 characters\n'
                      '• Starts with "D1", "D2", or "D3"',
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.4),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPassportFields() {
    return [
      _buildInputCard(
        title: '${widget.documentType.displayName} Number',
        hint: 'Enter your ${widget.documentType.displayName.toLowerCase()} number',
        icon: Icons.numbers,
        child: PlatformTextFormField(
          controller: _docNumberController,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: ManualEntryRules.documentNumberFormatters,
          hintText: 'e.g., AB1234567',
          validator: (value) => ManualEntryRules.documentNumber(value, documentName: widget.documentType.displayName),
        ),
      ),
      const SizedBox(height: 16),
      _buildInputCard(
        title: 'Date of Birth',
        hint: 'Select your date of birth',
        icon: Icons.cake,
        child: PlatformTextFormField(
          controller: _dobController,
          readOnly: true,
          hintText: 'Tap to select date',
          onTap: () => _selectDate(context, isDateOfBirth: true),
          validator: (_) => ManualEntryRules.dateOfBirth(_selectedDob),
        ),
      ),
      const SizedBox(height: 16),
      _buildInputCard(
        title: 'Expiry Date',
        hint: 'Select ${widget.documentType.displayName.toLowerCase()} expiry date',
        icon: Icons.event_busy,
        child: PlatformTextFormField(
          controller: _expiryController,
          readOnly: true,
          hintText: 'Tap to select date',
          onTap: () => _selectDate(context, isDateOfBirth: false),
          validator: (_) => ManualEntryRules.dateOfExpiry(
            _selectedExpiry,
            documentName: widget.documentType.displayName,
            dateOfBirth: _selectedDob,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildDriverLicenseFields() {
    return [
      _buildInputCard(
        title: 'MRZ String',
        hint: 'Enter the MRZ line from your driver\'s licence',
        icon: Icons.keyboard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlatformTextFormField(
              controller: _mrzController,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              maxLines: 1,
              inputFormatters: ManualEntryRules.mrzLineFormatters,
              hintText: 'D1NLD15094962111659VW87Z78NB84',
              style: const TextStyle(fontFamily: 'Courier', fontSize: 14),
              validator: ManualEntryRules.mrzLine,
              onChanged: (value) {
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Character count:', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                Text(
                  '${_mrzController.text.length} / 30',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _mrzController.text.length == 30 ? Colors.green : const Color(0xFF666666),
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
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF212121)),
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

  ScannedPassportMRZ? _createScannedPassport() {
    if (_selectedDob == null || _selectedExpiry == null) {
      setState(() {
        _errorMessage = 'Please fill in all required fields';
      });
      return null;
    }

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
        _errorMessage = 'Failed to parse MRZ: $e';
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
                ManualEntryRules.usesMrzLine(widget.documentType) ? Icons.text_fields : Icons.edit_document,
                size: 30,
                color: const Color(0xFF6b6868),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              ManualEntryRules.usesMrzLine(widget.documentType)
                  ? 'Enter MRZ String'
                  : 'Enter Your ${widget.documentType.displayName} Information',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF212121)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              ManualEntryRules.usesMrzLine(widget.documentType)
                  ? 'Type the Machine Readable Zone text exactly as it appears'
                  : 'Please enter the information exactly as it appears on your ${widget.documentType.displayName.toLowerCase()}',
              style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
