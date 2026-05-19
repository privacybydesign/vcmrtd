import 'dart:ffi';
import 'dart:typed_data';

// @Native bindings
// Symbols are resolved automatically via the native asset compiled by
// hook/build.dart — no DynamicLibrary setup, no platform-specific loading.

@Native<Pointer<Void> Function(Int32)>(symbol: 'face_buf_create')
external Pointer<Void> _faceBufCreate(int maxBytes);

@Native<Void Function(Pointer<Void>)>(symbol: 'face_buf_destroy')
external void _faceBufDestroy(Pointer<Void> buf);

@Native<Int32 Function(Pointer<Void>)>(symbol: 'face_buf_begin_write')
external int _faceBufBeginWrite(Pointer<Void> buf);

@Native<Void Function(Pointer<Void>)>(symbol: 'face_buf_abort_write')
external void _faceBufAbortWrite(Pointer<Void> buf);

@Native<Void Function(Pointer<Void>, Int32, Int32, Int32)>(symbol: 'face_buf_commit_write')
external void _faceBufCommitWrite(Pointer<Void> buf, int width, int height, int channels);

@Native<Int32 Function(Pointer<Void>)>(symbol: 'face_buf_begin_pipeline_read')
external int _faceBufBeginPipelineRead(Pointer<Void> buf);

@Native<Void Function(Pointer<Void>, Int32)>(symbol: 'face_buf_end_pipeline_read')
external void _faceBufEndPipelineRead(Pointer<Void> buf, int handoffToPassive);

@Native<Int32 Function(Pointer<Void>)>(symbol: 'face_buf_begin_passive_read')
external int _faceBufBeginPassiveRead(Pointer<Void> buf);

@Native<Void Function(Pointer<Void>)>(symbol: 'face_buf_end_passive_read')
external void _faceBufEndPassiveRead(Pointer<Void> buf);

@Native<Pointer<Uint8> Function(Pointer<Void>)>(symbol: 'face_buf_data')
external Pointer<Uint8> _faceBufData(Pointer<Void> buf);

@Native<Int32 Function(Pointer<Void>)>(symbol: 'face_buf_width')
external int _faceBufWidth(Pointer<Void> buf);

@Native<Int32 Function(Pointer<Void>)>(symbol: 'face_buf_height')
external int _faceBufHeight(Pointer<Void> buf);

@Native<Int32 Function(Pointer<Void>)>(symbol: 'face_buf_channels')
external int _faceBufChannels(Pointer<Void> buf);

// Public Dart wrapper

/// Native camera frame buffer.
///
/// Allocate with [FaceFrameBuffer.create] from the owning isolate.
/// Pass [address] (a plain int) to other isolates via SendPort, then
/// reconstruct with [FaceFrameBuffer.fromAddress] — zero copy.
class FaceFrameBuffer {
  FaceFrameBuffer._(this._ptr, this.byteCapacity);

  final Pointer<Void> _ptr;

  /// Byte capacity passed at construction — used to reconstruct across isolates.
  final int byteCapacity;

  /// Allocates a new native buffer on the C heap.
  factory FaceFrameBuffer.create(int maxBytes) {
    final ptr = _faceBufCreate(maxBytes);
    if (ptr == nullptr) throw StateError('face_buf_create($maxBytes) — out of memory');
    return FaceFrameBuffer._(ptr, maxBytes);
  }

  /// Reconstructs a wrapper from a raw address — callable from any isolate.
  factory FaceFrameBuffer.fromAddress(int address, int byteCapacity) =>
      FaceFrameBuffer._(Pointer<Void>.fromAddress(address), byteCapacity);

  /// Raw address — send this int across SendPort to share the buffer.
  int get address => _ptr.address;

  /// Frees native memory. Only call after all readers/writers have released.
  void dispose() => _faceBufDestroy(_ptr);

  // Writer (main isolate)

  bool beginWrite() => _faceBufBeginWrite(_ptr) == 0;
  void abortWrite() => _faceBufAbortWrite(_ptr);
  void commitWrite(int width, int height, int channels) => _faceBufCommitWrite(_ptr, width, height, channels);

  // Pipeline isolate (first reader)

  bool beginPipelineRead() => _faceBufBeginPipelineRead(_ptr) == 0;

  /// [handoffToPassive] = true  → PIL_READING → PASS_READY
  /// [handoffToPassive] = false → PIL_READING → FREE
  void endPipelineRead({required bool handoffToPassive}) => _faceBufEndPipelineRead(_ptr, handoffToPassive ? 1 : 0);

  // Passive isolate (second reader)

  bool beginPassiveRead() => _faceBufBeginPassiveRead(_ptr) == 0;
  void endPassiveRead() => _faceBufEndPassiveRead(_ptr);

  // Data access

  /// Raw pointer to pixel data. Valid only while holding any lock.
  Pointer<Uint8> get dataPtr => _faceBufData(_ptr);

  int get width => _faceBufWidth(_ptr);
  int get height => _faceBufHeight(_ptr);
  int get channels => _faceBufChannels(_ptr);

  // Convenience

  /// Writes camera plane bytes to native memory and commits.
  /// Returns false and aborts if the write lock could not be acquired.
  bool writeCameraPlanes(List<Uint8List> planesData, int width, int height) {
    if (!beginWrite()) return false;
    final dst = dataPtr;
    var offset = 0;
    for (final plane in planesData) {
      (dst + offset).asTypedList(plane.length).setAll(0, plane);
      offset += plane.length;
    }
    commitWrite(width, height, planesData.length);
    return true;
  }
}
