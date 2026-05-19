#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// State machine (per buffer):
//   FREE(0) → WRITING(1) → READY(2) → PIL_READING(3) → PASS_READY(4) → PASS_READING(5) → FREE(0)
//                                              ↓ (no face / error)
//                                            FREE(0)
//
// Main isolate writes camera frames and picks whichever buffer is FREE.
// It never blocks, if no FREE buffer exists it drops the frame.
// Pipeline and passive each decode independently from the same raw bytes.
typedef void* FaceBuffer;

FaceBuffer face_buf_create(int32_t max_bytes);
void       face_buf_destroy(FaceBuffer buf);

// Main isolate (writer)
// FREE → WRITING. Returns 0 on success, -1 if buffer is not FREE.
int32_t face_buf_begin_write(FaceBuffer buf);
// Abort without publishing: WRITING → FREE.
void    face_buf_abort_write(FaceBuffer buf);
// Publish frame data: WRITING → READY.
void    face_buf_commit_write(FaceBuffer buf, int32_t width, int32_t height, int32_t channels);

// Pipeline isolate (first reader)
// READY → PIL_READING. Returns 0 on success, -1 if not READY.
int32_t face_buf_begin_pipeline_read(FaceBuffer buf);
// Release pipeline lock.
//   handoff_to_passive = 1 : PIL_READING → PASS_READY  (passive will read same frame)
//   handoff_to_passive = 0 : PIL_READING → FREE         (no face, passive skips)
void    face_buf_end_pipeline_read(FaceBuffer buf, int32_t handoff_to_passive);

//Passive isolate (second reader) 
// PASS_READY → PASS_READING. Returns 0 on success, -1 if not PASS_READY.
int32_t face_buf_begin_passive_read(FaceBuffer buf);
// PASS_READING → FREE.
void    face_buf_end_passive_read(FaceBuffer buf);

// Data accessors (valid while holding any lock)
uint8_t* face_buf_data(FaceBuffer buf);
int32_t  face_buf_width(FaceBuffer buf);
int32_t  face_buf_height(FaceBuffer buf);
int32_t  face_buf_channels(FaceBuffer buf);

#ifdef __cplusplus
}
#endif
