#ifndef wStatus_h
#define wStatus_h

#import <Foundation/Foundation.h>

@interface wStatus : NSObject {
@private
void* thisStatus;
}

// status booleans
@property (readwrite) BOOL detection_too_small;
@property (readwrite) BOOL detection_score_too_low;
@property (readwrite) BOOL detection_outside_image;
@property (readwrite) BOOL detection_outside_depth_image;
@property (readwrite) BOOL detection_no_faces;
@property (readwrite) BOOL detection_too_many_faces;
@property (readwrite) BOOL qualitycheck_blurry;
@property (readwrite) BOOL qualitycheck_rotated;
@property (readwrite) BOOL qualitycheck_overexposed;
@property (readwrite) BOOL antispoofing_too_far;
@property (readwrite) BOOL antispoofing_spoofed;
@property (readwrite) BOOL passive_antispoofing_spoofed;
@property (readwrite) BOOL facevector_too_similar_in_db;
@property (readwrite) BOOL facevector_not_recognized;
@property (readwrite) BOOL facevector_failed_to_create;
@property (readwrite) BOOL is_overall_ok;

// constructors
- (wStatus*) init;
- (wStatus*) initWithStatus: (void*)Status;

// destructors
- (void) dealloc;

// helpers
- (void*) getCPPstatus;      // !NOTE: Always copy the returned object as object will be destroyed when the wConfiguration instance is destroyed
- (void) syncStatusFromCpp;  // Sets the values from the cpp object to this object
- (void) syncStatusFromSelf; // Sets the values from this object to the cpp object


@end

#endif /* wStatus_h */
