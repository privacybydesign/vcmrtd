import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/services/jpeg2000_converter.dart';

/// A wallet card's photo, sized to a fixed square. Handles JPEG2000 (the
/// format most passport/DL chips actually store the photo in, which
/// Image.memory cannot decode) by converting it via the native
/// jpeg2000_converter service, same as [ProfilePictureWidget] does elsewhere.
class WalletPhoto extends StatefulWidget {
  final Uint8List imageData;
  final ImageType? imageType;
  final double size;

  const WalletPhoto({super.key, required this.imageData, required this.imageType, required this.size});

  @override
  State<WalletPhoto> createState() => _WalletPhotoState();
}

class _WalletPhotoState extends State<WalletPhoto> {
  /// Converted photos by their original bytes, so a tile scrolling back into
  /// view or the details sheet doesn't decode the same photo again.
  static final _convertedCache = Expando<Uint8List>();

  Uint8List? _converted;
  bool _converting = false;

  @override
  void initState() {
    super.initState();
    _startConversion();
  }

  @override
  void didUpdateWidget(WalletPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageData != oldWidget.imageData || widget.imageType != oldWidget.imageType) _startConversion();
  }

  void _startConversion() {
    _converted = null;
    _converting = false;
    if (widget.imageType != ImageType.jpeg2000) return;
    final cached = _convertedCache[widget.imageData];
    if (cached != null) {
      _converted = cached;
      return;
    }
    _converting = true;
    _convert(widget.imageData);
  }

  Future<void> _convert(Uint8List imageData) async {
    final result = await decodeImage(imageData, context);
    if (result != null) _convertedCache[imageData] = result;
    // A newer photo may have replaced this one meanwhile.
    if (!mounted || !identical(imageData, widget.imageData)) return;
    setState(() {
      _converted = result;
      _converting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = widget.imageType == ImageType.jpeg2000 ? _converted : widget.imageData;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: bytes == null
          ? Container(
              color: Colors.grey[200],
              child: Center(
                child: _converting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.person, color: Colors.grey[400]),
              ),
            )
          : Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[200],
                child: Center(child: Icon(Icons.person, color: Colors.grey[400])),
              ),
            ),
    );
  }
}
