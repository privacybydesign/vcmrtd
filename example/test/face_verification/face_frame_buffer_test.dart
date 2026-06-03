import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/features/face_verification/ffi/face_frame_buffer.dart';

void main() {
  group('FaceFrameBuffer.fromAddress', () {
    test('stores address correctly', () {
      final buf = FaceFrameBuffer.fromAddress(12345, 1024);
      expect(buf.address, 12345);
    });

    test('stores byteCapacity correctly', () {
      final buf = FaceFrameBuffer.fromAddress(0, 4096);
      expect(buf.byteCapacity, 4096);
    });

    test('address zero is a valid null-like address', () {
      final buf = FaceFrameBuffer.fromAddress(0, 0);
      expect(buf.address, 0);
      expect(buf.byteCapacity, 0);
    });
  });
}
