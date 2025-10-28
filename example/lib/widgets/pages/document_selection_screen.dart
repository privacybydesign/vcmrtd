import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtdapp/providers/active_authenticiation_provider.dart';
import 'package:vcmrtdapp/theme/text_styles.dart';

typedef DocumentTypeCallback = void Function();

class DocumentTypeSelectionScreen extends StatelessWidget {
  final DocumentTypeCallback onPassportSelected;
  final DocumentTypeCallback onDrivingLicenceSelected;

  const DocumentTypeSelectionScreen({
    super.key,
    required this.onPassportSelected,
    required this.onDrivingLicenceSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select document type')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6b6868), Colors.white],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(),
                const SizedBox(height: 24),
                _OptionCard(
                  context: context,
                  title: 'Passport',
                  subtitle: 'Use a machine readable passport',
                  icon: Icons.book,
                  accentColor: const Color(0xFF6b6868),
                  onTap: onPassportSelected,
                  showBadge: true,
                  badgeText: 'Most common',
                ),
                const SizedBox(height: 16),
                _OptionCard(
                  context: context,
                  title: 'Driving Licence',
                  subtitle: 'Use a machine readable driving licence. Currently works primarily with Dutch licences.',
                  icon: Icons.directions_car,
                  accentColor: const Color(0xFF2196F3),
                  onTap: onDrivingLicenceSelected,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF6b6868).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(Icons.document_scanner, size: 40, color: Color(0xFF6b6868)),
            ),
            const SizedBox(height: 24),
            Text(
              'Which document type do you want to read?',
              style: Theme.of(context).defaultTextStyles.primaryLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Perform active authentication', style: Theme.of(context).defaultTextStyles.hint),
                Switch(
                  value: ref.watch(activeAuthenticationProvider),
                  onChanged: (value) {
                    ref.read(activeAuthenticationProvider.notifier).state = value;
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.context,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.showBadge = false,
    this.badgeText,
  });

  final BuildContext context;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final bool showBadge;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 122,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: accentColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF212121)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (showBadge && badgeText != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      badgeText!,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
