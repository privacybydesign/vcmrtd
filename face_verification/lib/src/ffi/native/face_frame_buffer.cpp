#include "face_frame_buffer.h"
#include <stdlib.h>
#include <new>
#include <atomic>

static const int32_t kFree      = 0;
static const int32_t kWriting   = 1;
static const int32_t kReady     = 2;
static const int32_t kPilRead   = 3;
static const int32_t kPassReady = 4;
static const int32_t kPassRead  = 5;

struct FaceBuffer_ {
    uint8_t*             data;
    int32_t              max_bytes;
    std::atomic<int32_t> state;
    int32_t              width;
    int32_t              height;
    int32_t              channels;
};

extern "C" {

FaceBuffer face_buf_create(int32_t max_bytes) {
    void* mem = malloc(sizeof(FaceBuffer_));
    if (!mem) return nullptr;
    // Placement new: constructs FaceBuffer_ in-place — no operator new(size_t) call.
    FaceBuffer_* b = new (mem) FaceBuffer_;
    b->state.store(kFree, std::memory_order_relaxed);
    b->data = static_cast<uint8_t*>(malloc(static_cast<size_t>(max_bytes)));
    if (!b->data) { b->state.~atomic(); free(mem); return nullptr; }
    b->max_bytes = max_bytes;
    b->width = b->height = b->channels = 0;
    return b;
}

void face_buf_destroy(FaceBuffer buf) {
    if (!buf) return;
    FaceBuffer_* b = static_cast<FaceBuffer_*>(buf);
    free(b->data);
    b->state.~atomic();
    free(b);
}

int32_t face_buf_begin_write(FaceBuffer buf) {
    FaceBuffer_* b = static_cast<FaceBuffer_*>(buf);
    int32_t expected = kFree;
    return b->state.compare_exchange_strong(
        expected, kWriting,
        std::memory_order_acquire,
        std::memory_order_relaxed) ? 0 : -1;
}

void face_buf_abort_write(FaceBuffer buf) {
    static_cast<FaceBuffer_*>(buf)->state.store(kFree, std::memory_order_release);
}

void face_buf_commit_write(FaceBuffer buf, int32_t width, int32_t height, int32_t channels) {
    FaceBuffer_* b = static_cast<FaceBuffer_*>(buf);
    b->width    = width;
    b->height   = height;
    b->channels = channels;
    b->state.store(kReady, std::memory_order_release);
}

int32_t face_buf_begin_pipeline_read(FaceBuffer buf) {
    FaceBuffer_* b = static_cast<FaceBuffer_*>(buf);
    int32_t expected = kReady;
    return b->state.compare_exchange_strong(
        expected, kPilRead,
        std::memory_order_acquire,
        std::memory_order_relaxed) ? 0 : -1;
}

void face_buf_end_pipeline_read(FaceBuffer buf, int32_t handoff_to_passive) {
    static_cast<FaceBuffer_*>(buf)->state.store(
        handoff_to_passive ? kPassReady : kFree,
        std::memory_order_release);
}

int32_t face_buf_begin_passive_read(FaceBuffer buf) {
    FaceBuffer_* b = static_cast<FaceBuffer_*>(buf);
    int32_t expected = kPassReady;
    return b->state.compare_exchange_strong(
        expected, kPassRead,
        std::memory_order_acquire,
        std::memory_order_relaxed) ? 0 : -1;
}

void face_buf_end_passive_read(FaceBuffer buf) {
    static_cast<FaceBuffer_*>(buf)->state.store(kFree, std::memory_order_release);
}

uint8_t* face_buf_data(FaceBuffer buf)    { return static_cast<FaceBuffer_*>(buf)->data;     }
int32_t  face_buf_width(FaceBuffer buf)   { return static_cast<FaceBuffer_*>(buf)->width;    }
int32_t  face_buf_height(FaceBuffer buf)  { return static_cast<FaceBuffer_*>(buf)->height;   }
int32_t  face_buf_channels(FaceBuffer buf){ return static_cast<FaceBuffer_*>(buf)->channels; }

} // extern "C"
