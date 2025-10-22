// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// Authentication form widget with DBA and PACE tabs

import 'package:flutter/material.dart';
import 'can_form_widget.dart';
import 'dba_form_widget.dart';

/// Widget for authentication form with tabs
class AuthFormWidget extends StatelessWidget {
  final TabController tabController;
  final GlobalKey<FormState> mrzFormKey;
  final GlobalKey<FormState> canFormKey;
  final TextEditingController docNumberController;
  final TextEditingController dobController;
  final TextEditingController doeController;
  final TextEditingController canController;
  final bool checkBoxPACE;
  final bool inputDisabled;
  final ValueChanged<bool> onPACEChanged;

  const AuthFormWidget({
    Key? key,
    required this.tabController,
    required this.mrzFormKey,
    required this.canFormKey,
    required this.docNumberController,
    required this.dobController,
    required this.doeController,
    required this.canController,
    required this.checkBoxPACE,
    required this.inputDisabled,
    required this.onPACEChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TabBar(
          controller: tabController,
          labelColor: Colors.blue,
          tabs: const <Widget>[
            Tab(text: 'DBA'),
            Tab(text: 'PACE'),
          ],
        ),
        SizedBox(
          height: 350,
          child: TabBarView(
            controller: tabController,
            children: <Widget>[
              DbaFormWidget(
                formKey: mrzFormKey,
                docNumberController: docNumberController,
                dobController: dobController,
                doeController: doeController,
                checkBoxPACE: checkBoxPACE,
                inputDisabled: inputDisabled,
                onPACEChanged: onPACEChanged,
              ),
              CanFormWidget(formKey: canFormKey, canController: canController, inputDisabled: inputDisabled),
            ],
          ),
        ),
      ],
    );
  }
}
