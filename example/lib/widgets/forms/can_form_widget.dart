// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// CAN form widget for PACE authentication

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget for CAN (Card Access Number) form
class CanFormWidget extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController canController;
  final bool inputDisabled;

  const CanFormWidget({
    Key? key,
    required this.formKey,
    required this.canController,
    required this.inputDisabled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      borderOnForeground: false,
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.all(16.0),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextFormField(
              enabled: !inputDisabled,
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
        ),
      ),
    );
  }
}
