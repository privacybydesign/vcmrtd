import 'package:flutter/material.dart';
import 'package:vcmrtd/vcmrtd.dart';

class SecurityContent extends StatelessWidget {
  final PassportData passport;

  const SecurityContent({super.key, required this.passport});

  @override
  Widget build(BuildContext context) {
    return _buildSecurityDetails();
  }

  Widget _buildSecurityDetails() {
    final dgCount = [
      passport.mrz,
      passport.photoImageData,
      passport.dg3RawBytes,
      passport.dg4RawBytes,
      passport.dg5RawBytes,
      passport.dg6RawBytes,
      passport.dg7RawBytes,
      passport.dg8RawBytes,
      passport.dg9RawBytes,
      passport.dg10RawBytes,
      passport.nameOfHolder,
      passport.issuingAuthority,
      passport.dg13RawBytes,
      passport.dg14RawBytes,
      passport.aaPublicKey,
      passport.dg16RawBytes,
    ].nonNulls.length;

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
