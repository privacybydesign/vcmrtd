import 'package:flutter/material.dart';
import 'package:vcmrtd/vcmrtd.dart';
import '../../displays/passport_image_widget.dart';
import 'package:flutter/services.dart';

class ProfilePictureWidget extends StatelessWidget {
  final Uint8List imageData;
  final ImageType imageType;

  const ProfilePictureWidget({super.key, required this.imageData, required this.imageType});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: _buildPassportImage()),
    );
  }

  Widget _buildPassportImage() {
    if (imageType == ImageType.jpeg) {
      return Image.memory(
        imageData,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          child: const Center(child: Icon(Icons.error, color: Colors.red)),
        ),
      );
    } else {
      // For JPEG2000
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [PassportImageWidget(imageData: imageData, imageType: imageType)],
          ),
        ),
      );
    }
  }
}
