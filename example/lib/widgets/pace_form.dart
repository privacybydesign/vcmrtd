import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaceForm extends StatelessWidget {
  final TextEditingController canController;
  final bool disabled;

  const PaceForm({
    super.key,
    required this.canController,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          enabled: !disabled,
          controller: canController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'CAN number',
            fillColor: Colors.white,
          ),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9]+')),
            LengthLimitingTextInputFormatter(6),
          ],
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
          validator: (value) {
            if (value?.isEmpty ?? false) {
              return 'Please enter CAN number';
            }
            return null;
          },
        ),
      ],
    );
  }
}
