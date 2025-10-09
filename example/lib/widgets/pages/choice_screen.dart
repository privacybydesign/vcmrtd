// Created for UX improvement - Initial choice screen
// Implementation based on hive design specifications

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:vcmrtdapp/theme/text_styles.dart';

/// Initial choice screen - user decides between Scan MRZ or Enter Manually
class ChoiceScreen extends StatelessWidget {
  final VoidCallback onScanMrzPressed;
  final VoidCallback onScanDriverLicensePressed;
  final VoidCallback onEnterManuallyPressed;
  final VoidCallback? onHelpPressed;

  const ChoiceScreen({
    Key? key,
    required this.onScanMrzPressed,
    required this.onScanDriverLicensePressed,
    required this.onEnterManuallyPressed,
    this.onHelpPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6b6868),
              Colors.white,
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                // Header section
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Passport icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6b6868).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: const Icon(
                            Icons.credit_card,
                            size: 40,
                            color: Color(0xFF6b6868),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Title
                        Text(
                          'How would you like to read your passport?',
                          style: Theme.of(context).defaultTextStyles.primaryLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        // Subtitle
                        Text(
                          'Choose the method that works best for you',
                          style: Theme.of(context).defaultTextStyles.hint,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Primary option - Scan MRZ (Recommended)
                _buildOptionButton(
                  context: context,
                  title: 'Scan MRZ Code',
                  subtitle: 'Quick and easy - just scan the bottom of your passport',
                  icon: Icons.qr_code_scanner,
                  isPrimary: true,
                  isRecommended: true,
                  onPressed: onScanMrzPressed,
                ),

                const SizedBox(height: 16),

                // Secondary option - Scan Driver's License
                _buildOptionButton(
                  context: context,
                  title: 'Scan Driver\'s License',
                  subtitle: 'Scan the MRZ code on your driver\'s license',
                  icon: Icons.credit_card,
                  isPrimary: false,
                  isRecommended: false,
                  onPressed: onScanDriverLicensePressed,
                ),

                const SizedBox(height: 16),

                // Secondary option - Enter Manually
                _buildOptionButton(
                  context: context,
                  title: 'Enter Details Manually',
                  subtitle: 'Type in your passport information by hand',
                  icon: Icons.edit,
                  isPrimary: false,
                  isRecommended: false,
                  onPressed: onEnterManuallyPressed,
                ),
                
                const SizedBox(height: 32),
                
                // Help section
                if (onHelpPressed != null)
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'Not sure which option to choose?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 8),
                        PlatformTextButton(
                          onPressed: onHelpPressed,
                          child: const Text(
                            'Get help',
                            style: TextStyle(
                              color: Color(0xFF6b6868),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isPrimary,
    required bool isRecommended,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 102,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isPrimary ? const Color(0xFF6b6868) : const Color(0xFFF5F5F5),
          ),
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
                        color: isPrimary 
                            ? Colors.white.withOpacity(0.2)
                            : const Color(0xFF6b6868).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: isPrimary ? Colors.white : const Color(0xFF2196F3),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isPrimary ? Colors.white : const Color(0xFF212121),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: isPrimary 
                                  ? Colors.white.withOpacity(0.8)
                                  : const Color(0xFF666666),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Recommended badge
              if (isRecommended)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'RECOMMENDED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
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