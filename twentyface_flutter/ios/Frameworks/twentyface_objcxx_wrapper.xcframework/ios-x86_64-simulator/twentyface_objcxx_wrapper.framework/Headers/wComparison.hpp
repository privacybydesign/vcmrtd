#ifndef wComparison_h
#define wComparison_h

#import <Foundation/Foundation.h>
#import "wStatus.hpp"

@interface wComparison : NSObject {
@private
void* myComparison;
}

// constructors
- (wComparison*) init:(BOOL)match recognition_distance:(NSNumber*)recognition_distance status_image_1:(wStatus*)status_image_1 status_image_2:(wStatus*)status_image_2;
- (wComparison*) initWithComparison: (void*)Comparison;

// properties
// The boolean result of the comparison.
// Is true when the Euclidean distance between the two face vectors is below the configured recognize_threshold.
// Is false when there is a problem (see image statuses) or there is no match.
@property (readwrite) BOOL match;

// The Euclidean distance between the two normalised face vectors in this comparison.
// Because the face vectors are normalised, the value of the Euclidean distance is always between 0.0 and 2.0.
// A negative value indicates that there was a problem (for details, see image statuses).
@property (readwrite) NSNumber *recognition_distance;

// The result status of the first image. Can indicate several different problems.
@property (readwrite) wStatus *status_image_1;

// The result status of the second image. Can indicate several different problems.
@property (readwrite) wStatus *status_image_2;

// destructors
- (void) dealloc;

//helpers
- (void*) getCPPcomparison;

@end

#endif /* wComparison_h */
