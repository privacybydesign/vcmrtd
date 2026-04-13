#ifndef wLandmarks_h
#define wLandmarks_h

#import <Foundation/Foundation.h>

#import "wPoint.hpp"

@interface wLandmarks : NSObject {
    @private
    void* myLandmarks;
}

// properties
@property (readwrite) wPoint *left_eye;
@property (readwrite) wPoint *right_eye;
@property (readwrite) wPoint *nose;
@property (readwrite) wPoint *left_mouth_corner;
@property (readwrite) wPoint *right_mouth_corner;


// constructors
- (wLandmarks*) init;
- (wLandmarks*) initWithLandmarks: (void*)Landmarks;

// destructors
- (void) dealloc;

// helpers
- (void*) getCPPlandmarks;      // !NOTE: Always copy the returned object as object will be destroyed when the wLandmarks instance is destroyed
- (void) syncLandmarksFromCpp;  // Sets the values from the cpp object to this object
- (void) syncLandmarksFromSelf; // Sets the values from this object to the cpp object

@end

#endif /* wLandmarks_h */
