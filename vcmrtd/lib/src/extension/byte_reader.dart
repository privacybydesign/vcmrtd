import 'dart:typed_data';

class ByteReader {
  final Uint8List _data;
  int _offset = 0;

  ByteReader(this._data);

  /// Returns `true` if all bytes have been read.
  bool get isEOF => _offset >= _data.length;

  /// The current reading position.
  int get position => _offset;

  /// Number of bytes remaining to be read.
  int get remaining => _data.length - _offset;

  /// Reads an integer from the next [length] bytes (big-endian).
  int readInt(int length) {
    if (remaining < length) {
      throw RangeError("Not enough bytes remaining to read $length bytes");
    }
    int result = 0;
    for (int i = 0; i < length; i++) {
      result = (result << 8) | _data[_offset + i];
    }
    _offset += length;
    return result;
  }

  /// Reads the next [length] bytes.
  Uint8List readBytes(int length) {
    if (remaining < length) {
      throw RangeError("Not enough bytes remaining to read $length bytes");
    }
    final bytes = _data.sublist(_offset, _offset + length);
    _offset += length;
    return bytes;
  }

  /// Skips [length] bytes.
  void skip(int length) {
    if (remaining < length) {
      throw RangeError("Cannot skip $length bytes; only $remaining left");
    }
    _offset += length;
  }

  /// Reads all remaining bytes (useful at the end of a record).
  Uint8List readRemaining() => readBytes(remaining);

  /// Peeks the next byte without advancing the offset.
  int peekByte() {
    if (isEOF) throw RangeError("No bytes left to peek");
    return _data[_offset];
  }

  /// Returns true if at least [length] bytes remain.
  bool hasRemaining(int length) => remaining >= length;
}
