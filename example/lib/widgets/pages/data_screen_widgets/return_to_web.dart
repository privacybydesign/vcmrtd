import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ReturnToWebSection extends StatelessWidget {
  final bool isReturningToIssue;
  final bool isReturningToVerify;
  final VoidCallback onIssuePressed;
  final VoidCallback onVerifyPressed;

  const ReturnToWebSection({
    Key? key,
    required this.isReturningToIssue,
    required this.isReturningToVerify,
    required this.onIssuePressed,
    required this.onVerifyPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.arrow_back, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Passport Issuer services',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
              ],
            ),
            const Divider(height: 30),
            Text(
              'You have two options. You can continue to Yivi app to get this data verified and issued to Yivi. Or you can do the verification only flow.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isReturningToIssue ? null : onIssuePressed,
              icon: isReturningToIssue
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_browser),
              label: Text(isReturningToIssue ? 'Redirecting...' : 'Issue a Credential with Yivi'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isReturningToVerify ? null : onVerifyPressed,
              icon: isReturningToVerify
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_browser),
              label: Text(isReturningToVerify ? 'Redirecting...' : 'Verify via our API'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Note: This may close the mobile app and return you to your web browser.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
