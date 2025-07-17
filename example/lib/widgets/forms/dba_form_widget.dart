// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// DBA form widget for passport authentication

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Widget for DBA (Document Basic Access) form
class DbaFormWidget extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController docNumberController;
  final TextEditingController dobController;
  final TextEditingController doeController;
  final bool checkBoxPACE;
  final bool inputDisabled;
  final ValueChanged<bool> onPACEChanged;

  const DbaFormWidget({
    Key? key,
    required this.formKey,
    required this.docNumberController,
    required this.dobController,
    required this.doeController,
    required this.checkBoxPACE,
    required this.inputDisabled,
    required this.onPACEChanged,
  }) : super(key: key);

  @override
  State<DbaFormWidget> createState() => _DbaFormWidgetState();
}

class _DbaFormWidgetState extends State<DbaFormWidget> {
  DateTime? _getDOBDate() {
    if (widget.dobController.text.isEmpty) {
      return null;
    }
    return DateFormat.yMd().parse(widget.dobController.text);
  }

  DateTime? _getDOEDate() {
    if (widget.doeController.text.isEmpty) {
      return null;
    }
    return DateFormat.yMd().parse(widget.doeController.text);
  }

  Future<String?> _pickDate(BuildContext context, DateTime firstDate,
      DateTime initDate, DateTime lastDate) async {
    final locale = Localizations.localeOf(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: firstDate,
      initialDate: initDate,
      lastDate: lastDate,
      locale: locale,
    );

    if (picked != null) {
      return DateFormat.yMd().format(picked);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      borderOnForeground: false,
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.all(16.0),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextFormField(
              enabled: !widget.inputDisabled,
              controller: widget.docNumberController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Passport number',
                fillColor: Colors.white,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]+')),
                LengthLimitingTextInputFormatter(14),
              ],
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
              validator: (value) {
                if (value?.isEmpty ?? false) {
                  return 'Please enter passport number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              enabled: !widget.inputDisabled,
              controller: widget.dobController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Date of Birth',
                fillColor: Colors.white,
              ),
              autofocus: false,
              validator: (value) {
                if (value?.isEmpty ?? false) {
                  return 'Please select Date of Birth';
                }
                return null;
              },
              onTap: () async {
                FocusScope.of(context).requestFocus(FocusNode());
                // Can pick date which dates 15 years back or more
                final now = DateTime.now();
                final firstDate = DateTime(now.year - 90, now.month, now.day);
                final lastDate = DateTime(now.year - 15, now.month, now.day);
                final initDate = _getDOBDate();
                final date = await _pickDate(
                  context,
                  firstDate,
                  initDate ?? lastDate,
                  lastDate,
                );

                FocusScope.of(context).requestFocus(FocusNode());
                if (date != null) {
                  widget.dobController.text = date;
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              enabled: !widget.inputDisabled,
              controller: widget.doeController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Date of Expiry',
                fillColor: Colors.white,
              ),
              autofocus: false,
              validator: (value) {
                if (value?.isEmpty ?? false) {
                  return 'Please select Date of Expiry';
                }
                return null;
              },
              onTap: () async {
                FocusScope.of(context).requestFocus(FocusNode());
                // Can pick date from tomorrow and up to 10 years
                final now = DateTime.now();
                final firstDate = DateTime(now.year, now.month, now.day + 1);
                final lastDate = DateTime(now.year + 10, now.month + 6, now.day);
                final initDate = _getDOEDate();
                final date = await _pickDate(
                  context,
                  firstDate,
                  initDate ?? firstDate,
                  lastDate,
                );

                FocusScope.of(context).requestFocus(FocusNode());
                if (date != null) {
                  widget.doeController.text = date;
                }
              },
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('DBA with PACE'),
              value: widget.checkBoxPACE,
              onChanged: (newValue) {
                widget.onPACEChanged(newValue ?? false);
              },
            ),
          ],
        ),
      ),
    );
  }
}