import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vcmrtdapp/models/mrtd_data.dart';

class SecurityContent extends StatelessWidget {
  final MrtdData mrtdData;

  const SecurityContent({Key? key, required this.mrtdData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(children: [_buildAccessProtocolInfo(), const SizedBox(height: 20), _buildSecurityDetails()]);
  }

  Widget _buildAccessProtocolInfo() {
    if (mrtdData.isPACE == null || mrtdData.isDBA == null) {
      return const Text('No access protocol information available', style: TextStyle(color: Colors.grey));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Access Protocol',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                mrtdData.isPACE! ? Icons.check_circle : Icons.cancel,
                color: mrtdData.isPACE! ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('PACE: ${mrtdData.isPACE! ? 'Enabled' : 'Disabled'}'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                mrtdData.isDBA! ? Icons.check_circle : Icons.cancel,
                color: mrtdData.isDBA! ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('DBA: ${mrtdData.isDBA! ? 'Enabled' : 'Disabled'}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityDetails() {
    final availableElements = <String>[];

    if (mrtdData.cardAccess != null) {
      availableElements.add('EF.CardAccess');
    }
    if (mrtdData.cardSecurity != null) {
      availableElements.add('EF.CardSecurity');
    }
    if (mrtdData.com != null) availableElements.add('EF.COM');
    if (mrtdData.sod != null) availableElements.add('EF.SOD');

    // Count available data groups
    int dgCount = 0;
    final dgs = [
      mrtdData.dg1,
      mrtdData.dg2,
      mrtdData.dg3,
      mrtdData.dg4,
      mrtdData.dg5,
      mrtdData.dg6,
      mrtdData.dg7,
      mrtdData.dg8,
      mrtdData.dg9,
      mrtdData.dg10,
      mrtdData.dg11,
      mrtdData.dg12,
      mrtdData.dg13,
      mrtdData.dg14,
      mrtdData.dg15,
      mrtdData.dg16,
    ];
    for (var dg in dgs) {
      if (dg != null) dgCount++;
    }

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
            'Available Security Elements',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800], fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.folder_open, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text('Security Files: ${availableElements.length}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.dataset, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              Text('Data Groups: $dgCount/16'),
            ],
          ),
          if (availableElements.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: availableElements
                  .map(
                    (element) => Chip(
                      label: Text(element, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.blue[100],
                      labelStyle: TextStyle(color: Colors.blue[800]),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
