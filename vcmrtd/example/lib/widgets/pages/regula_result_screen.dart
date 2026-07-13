import 'package:flutter/material.dart';
import 'package:vcmrtdapp/services/regula_face_service.dart';

/// Shows the outcome of a Regula verification: the liveness verdict and the
/// similarity of the live face against the document (DG2/DG6) portrait.
class RegulaResultScreen extends StatelessWidget {
  final RegulaFaceResult result;
  final VoidCallback onBackPressed;
  final VoidCallback onRetry;

  const RegulaResultScreen({super.key, required this.result, required this.onBackPressed, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final passed = r.passed;
    final txn = r.transactionId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Verification'),
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: onBackPressed),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(passed ? Icons.check_circle : Icons.cancel, size: 80, color: passed ? Colors.green : Colors.red),
              const SizedBox(height: 24),
              Text(
                passed ? 'Identity Verified' : 'Verification Failed',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: passed ? Colors.green : Colors.red),
              ),
              const SizedBox(height: 16),
              _scoreRow('Liveness', r.isLive ? 'live' : 'not live', r.isLive),
              _scoreRow(
                'Match (≥${(r.matchThreshold * 100).toStringAsFixed(0)}%)',
                r.similarity != null ? '${(r.similarity! * 100).toStringAsFixed(1)}%' : 'n/a',
                r.matched,
              ),
              _scoreRow('Transaction', _shortTransaction(txn), txn != null && txn.isNotEmpty),
              const SizedBox(height: 32),
              OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
            ],
          ),
        ),
      ),
    );
  }

  static String _shortTransaction(String? id) {
    if (id == null || id.isEmpty) return 'n/a';
    if (id.length <= 12) return id;
    return '${id.substring(0, 6)}…${id.substring(id.length - 4)}';
  }

  static Widget _scoreRow(String label, String value, bool ok) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Row(
          children: [
            Text(value, style: TextStyle(color: ok ? Colors.green : Colors.red)),
            const SizedBox(width: 6),
            Icon(ok ? Icons.check : Icons.close, size: 16, color: ok ? Colors.green : Colors.red),
          ],
        ),
      ],
    ),
  );
}
