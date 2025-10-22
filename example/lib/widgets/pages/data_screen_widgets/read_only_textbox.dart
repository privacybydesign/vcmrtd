import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ReadOnlyTextBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isError;

  const ReadOnlyTextBox({
    Key? key,
    required this.label,
    required this.value,
    required this.isError,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: value),
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: isError ? Colors.red[50] : Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isError ? Colors.red[200]! : Colors.grey[300]!),
        ),
        prefixIcon: Icon(
          isError ? Icons.error_outline : Icons.info_outline,
          color: isError ? Colors.red[400] : Colors.grey[600],
        ),
      ),
    );
  }
}
