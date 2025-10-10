// Created for UX improvement - Simple manual data entry screen
// Allows users to enter passport data manually: DOB, expiry date, document number

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:intl/intl.dart';

import '../../helpers/mrz_scanner.dart';
import '../../helpers/document_type_extract.dart';

/// Simple manual entry screen for passport data
class ManualEntryScreen extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;
  final Function(String docNumber, DateTime dob, DateTime expiry)?
      onDataEntered;
  final Function(String mrzString)? onMrzEntered;
  final DocumentType documentType;

  const ManualEntryScreen({
    Key? key,
    required this.onContinue,
    required this.onBack,
    this.onMrzEntered,
    this.onDataEntered,
    required this.documentType,
  }) : super(key: key);

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  // Passport fields
  final _docNumberController = TextEditingController();
  final _dobController = TextEditingController();
  final _expiryController = TextEditingController();

  // Driver's licence fields
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
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text('Enter ${widget.documentType.displayName} Details'),
        leading: PlatformIconButton(
          icon: Icon(PlatformIcons(context).back),
          onPressed: widget.onBack,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header section
                _buildHeaderCard(),

                const SizedBox(height: 32),
                // show manual entry based on the document
                if (widget.documentType == DocumentType.passport)
                  ..._buildPassportFields()
                else
                  ..._buildDriverLicenseFields(),

                const SizedBox(height: 24),

                // Error message
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Continue Button
                PlatformElevatedButton(
                  onPressed: _handleContinue,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Continue to NFC Reading',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Help text
                _buildHelpText(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelpText() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where to find this information:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.documentType == DocumentType.passport
                ? '• Passport Number: Usually at the top right of the photo page\n'
                    '• Date of Birth: Listed as "Date of birth" or "DOB"\n'
                    '• Expiry Date: Listed as "Date of expiry" or "Valid until"'
                : '• The MRZ is at the bottom of the front side of your driver\'s licence\n'
                    '• You can also get this by scanning the QR Code on the back of your driver\'s licence\n '
                    '• It\'s a single line of exactly 30 characters\n'
                    '• Starts with "D1", "D2", or "D3"',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPassportFields() {
    return [
      // Document Number Field
      _buildInputCard(
        title: '${widget.documentType.displayName} Number',
        hint: 'Enter your ${widget.documentType.displayNameLowerCase} number',
        icon: Icons.numbers,
        child: PlatformTextFormField(
          controller: _docNumberController,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
            LengthLimitingTextInputFormatter(15),
          ],
          hintText: 'e.g., AB1234567',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '${widget.documentType.displayName} number is required';
            }
            if (value.trim().length < 6) {
              return '${widget.documentType.displayName} number must be at least 6 characters';
            }
            return null;
          },
        ),
      ),
      const SizedBox(height: 16),

      // Date of Birth Field
      _buildInputCard(
        title: 'Date of Birth',
        hint: 'Select your date of birth',
        icon: Icons.cake,
        child: PlatformTextFormField(
          controller: _dobController,
          readOnly: true,
          hintText: 'Tap to select date',
          onTap: () => _selectDate(context, isDateOfBirth: true),
          validator: (value) {
            if (_selectedDob == null) {
              return 'Date of birth is required';
            }
            if (_selectedDob!.isAfter(DateTime.now())) {
              return 'Date of birth cannot be in the future';
            }
            return null;
          },
        ),
      ),
      const SizedBox(height: 16),

      // Expiry Date Field
      _buildInputCard(
        title: 'Expiry Date',
        hint: 'Select ${widget.documentType.displayNameLowerCase} expiry date',
        icon: Icons.event_busy,
        child: PlatformTextFormField(
          controller: _expiryController,
          readOnly: true,
          hintText: 'Tap to select date',
          onTap: () => _selectDate(context, isDateOfBirth: false),
          validator: (value) {
            if (_selectedExpiry == null) {
              return 'Expiry date is required';
            }
            if (_selectedExpiry!.isBefore(DateTime.now())) {
              return '${widget.documentType.displayName} has expired';
            }
            if (_selectedDob != null &&
                _selectedExpiry!.isBefore(_selectedDob!)) {
              return 'Expiry date cannot be before date of birth';
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
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9<]')),
                LengthLimitingTextInputFormatter(30),
              ],
              hintText: 'D1NLD15094962111659VW87Z78NB84',
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 14,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'MRZ string is required';
                }
                if (value.trim().length != 30) {
                  return 'MRZ must be exactly 30 characters';
                }
                if (!value.startsWith('D1') &&
                    !value.startsWith('D2') &&
                    !value.startsWith('DL')) {
                  return 'MRZ must start with D1, D2, or DL';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {}); // Update character count
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Character count:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
                Text(
                  '${_mrzController.text.length} / 30',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _mrzController.text.length == 30
                        ? Colors.green
                        : const Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildInputCard({
    required String title,
    required String hint,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                    color: const Color(0xFF6b6868).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: const Color(0xFF6b6868),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF212121),
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

  Future<void> _selectDate(BuildContext context,
      {required bool isDateOfBirth}) async {
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
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF6b6868),
                ),
          ),
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
        _errorMessage = ''; // Clear any previous error
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

    if (widget.documentType == DocumentType.passport) {
      // Passport flow - validate dates and call onDataEntered
      if (_selectedDob == null || _selectedExpiry == null) {
        setState(() {
          _errorMessage = 'Please fill in all required fields';
        });
        return;
      }

      if (widget.onDataEntered != null) {
        widget.onDataEntered!(
          _docNumberController.text.trim().toUpperCase(),
          _selectedDob!,
          _selectedExpiry!,
        );
      }
    } else {
      // Driver's license flow - call onMrzEntered with MRZ string
      if (widget.onMrzEntered != null) {
        widget.onMrzEntered!(_mrzController.text.trim().toUpperCase());
      }
    }

    // Continue to next screen
    widget.onContinue();
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF6b6868).withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                widget.documentType == DocumentType.passport
                    ? Icons.edit_document
                    : Icons.text_fields,
                size: 30,
                color: const Color(0xFF6b6868),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.documentType == DocumentType.passport
                  ? 'Enter Your ${widget.documentType.displayName} Information'
                  : 'Enter MRZ String',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF212121),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.documentType == DocumentType.passport
                  ? 'Please enter the information exactly as it appears on your ${widget.documentType.displayNameLowerCase}'
                  : 'Type the Machine Readable Zone text exactly as it appears',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
