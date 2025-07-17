import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DbaForm extends StatelessWidget {
  final TextEditingController docNumberController;
  final TextEditingController dobController;
  final TextEditingController doeController;
  final bool paceChecked;
  final bool disabled;
  final ValueChanged<bool?> onPaceChanged;
  final Future<String?> Function() onPickDob;
  final Future<String?> Function() onPickDoe;

  const DbaForm({
    super.key,
    required this.docNumberController,
    required this.dobController,
    required this.doeController,
    required this.paceChecked,
    required this.disabled,
    required this.onPaceChanged,
    required this.onPickDob,
    required this.onPickDoe,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          enabled: !disabled,
          controller: docNumberController,
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
          enabled: !disabled,
          controller: dobController,
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
            final date = await onPickDob();
            if (date != null) dobController.text = date;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          enabled: !disabled,
          controller: doeController,
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
            final date = await onPickDoe();
            if (date != null) doeController.text = date;
          },
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          title: const Text('DBA with PACE'),
          value: paceChecked,
          onChanged: onPaceChanged,
        ),
      ],
    );
  }
}
