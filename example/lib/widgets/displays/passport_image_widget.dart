import 'package:vcmrtd/vcmrtd.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:expandable/expandable.dart';
import 'package:vcmrtdapp/services/jpeg2000_converter.dart';

class PassportImageWidget extends StatefulWidget {
  final String header;
  final Uint8List? imageData;
  final ImageType? imageType;

  const PassportImageWidget({
    Key? key,
    required this.header,
    required this.imageData,
    required this.imageType,
  }) : super(key: key);

  @override
  State<PassportImageWidget> createState() => _PassportImageWidgetState();
}

class _PassportImageWidgetState extends State<PassportImageWidget> {
  static final Map<String, Uint8List> _conversionCache = {};
  Uint8List? _convertedImage;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    if (widget.imageType == ImageType.jpeg2000 && widget.imageData != null) {
      _convertJp2Image();
    }
  }

  @override
  void didUpdateWidget(PassportImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if image data or type changed
    if (widget.imageData != oldWidget.imageData || 
        widget.imageType != oldWidget.imageType) {
      if (widget.imageType == ImageType.jpeg2000 && widget.imageData != null) {
        _convertJp2Image();
      } else {
        _convertedImage = null;
      }
    }
  }

  String _getCacheKey() {
    return widget.imageData!.hashCode.toString();
  }

  Future<void> _convertJp2Image() async {
    if (_isConverting || widget.imageData == null) return;

    setState(() {
      _isConverting = true;
    });

    try {
      final cacheKey = _getCacheKey();
      
      // Check cache first
      if (_conversionCache.containsKey(cacheKey)) {
        setState(() {
          _convertedImage = _conversionCache[cacheKey];
          _isConverting = false;
        });
        return;
      }

      // Convert the image
      final convertedData = await convertJp2(widget.imageData!, context);
      
      if (convertedData != null) {
        // Cache the result
        _conversionCache[cacheKey] = convertedData;
        
        if (mounted) {
          setState(() {
            _convertedImage = convertedData;
            _isConverting = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isConverting = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConverting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageData == null || widget.imageData!.isEmpty) {
      return const Center(child: Text("No image data available."));
    }

    if (widget.imageType == ImageType.jpeg) {
      return Image.memory(
        widget.imageData!,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            const Text("Error displaying JPEG image."),
      );
    } else if (widget.imageType == ImageType.jpeg2000) {
      if (_isConverting) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Converting JPEG2000 image..."),
            ],
          ),
        );
      } else if (_convertedImage != null) {
        return Image.memory(
          _convertedImage!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              const Text("Error displaying converted JPEG2000 image."),
        );
      } else {
        return const Center(
          child: Text("Failed to convert JPEG2000 image."),
        );
      }
    } else {
      return const Center(
        child: Text("Unknown or unsupported image type."),
      );
    }
  }

  Future<Uint8List?> convertJp2(Uint8List imageData, BuildContext context) async {
    try {
      return await decodeImage(imageData, context);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    // Optional: Clean up cache if needed (be careful about memory usage)
    // _conversionCache.clear();
    super.dispose();
  }
}