import 'package:flutter/material.dart';
import 'package:vcmrtd/src/models/document.dart';

class SecurityContent extends StatelessWidget {
  final PassportData passport;

  const SecurityContent({super.key, required this.passport});

  @override
  Widget build(BuildContext context) {
    return _buildSecurityDetails();
  }

  Widget _buildSecurityDetails() {
    int dgCount = 0;

    if (passport.mrz != null ) dgCount++;
    if (passport.photoImageData != null) dgCount++;
    if (passport.dg3RawBytes != null) dgCount++;
    if (passport.dg4RawBytes != null) dgCount++;
    if (passport.dg5RawBytes != null) dgCount++;
    if (passport.dg6RawBytes != null) dgCount++;
    if (passport.dg7RawBytes != null) dgCount++;
    if (passport.dg8RawBytes != null) dgCount++;
    if (passport.dg9RawBytes != null) dgCount++;
    if (passport.dg10RawBytes != null) dgCount++;
    if (passport.nameOfHolder != null) dgCount++;
    if (passport.issuingAuthority != null) dgCount++;
    if (passport.dg13RawBytes != null) dgCount++;
    if (passport.dg14RawBytes != null) dgCount++;
    if (passport.aaPublicKey != null) dgCount++;
    if (passport.dg16RawBytes != null) dgCount++;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Data Groups',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800], fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.dataset, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              Text('Data Groups Read: $dgCount/16'),
            ],
          ),
          if (passport.aaPublicKey != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.verified_user, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                Text('Active Authentication Available'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}