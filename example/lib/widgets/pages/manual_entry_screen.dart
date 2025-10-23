// Created for UX improvement - Simple manual data entry screen
// Allows users to enter passport data manually: DOB, expiry date, document number

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:intl/intl.dart';

/// Simple manual entry screen for passport data
class ManualEntryScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Function(String docNumber, DateTime dob, DateTime expiry)? onDataEntered;

  const ManualEntryScreen({super.key, required this.onBack, this.onDataEntered});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _docNumberController = TextEditingController();
  final _dobController = TextEditingController();
  final _expiryController = TextEditingController();

  DateTime? _selectedDob;
  DateTime? _selectedExpiry;
  String _errorMessage = '';

  @override
  void dispose() {
    _docNumberController.dispose();
    _dobController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Enter Passport Details'),
        leading: PlatformIconButton(icon: Icon(PlatformIcons(context).back), onPressed: widget.onBack),
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
                Card(
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
                          child: const Icon(Icons.edit_document, size: 30, color: Color(0xFF6b6868)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Enter Your Passport Information',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF212121)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please enter the information exactly as it appears on your passport',
                          style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Document Number Field
                _buildInputCard(
                  title: 'Passport Number',
                  hint: 'Enter your passport number',
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
                        return 'Passport number is required';
                      }
                      if (value.trim().length < 6) {
                        return 'Passport number must be at least 6 characters';
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
                  hint: 'Select passport expiry date',
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
                        return 'Passport has expired';
                      }
                      if (_selectedDob != null && _selectedExpiry!.isBefore(_selectedDob!)) {
                        return 'Expiry date cannot be before date of birth';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Error message
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
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

                // Continue Button
                PlatformElevatedButton(
                  onPressed: _handleContinue,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Continue to NFC Reading', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 16),

                // Help text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Where to find this information:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Passport Number: Usually at the top right of the photo page\n'
                        '• Date of Birth: Listed as "Date of birth" or "DOB"\n'
                        '• Expiry Date: Listed as "Date of expiry" or "Valid until"',
                        style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

    // Additional validation
    if (_selectedDob == null || _selectedExpiry == null) {
      setState(() {
        _errorMessage = 'Please fill in all required fields';
      });
      return;
    }

    // Callback with the entered data
    if (widget.onDataEntered != null) {
      widget.onDataEntered!(_docNumberController.text.trim().toUpperCase(), _selectedDob!, _selectedExpiry!);
    }
  }
}
