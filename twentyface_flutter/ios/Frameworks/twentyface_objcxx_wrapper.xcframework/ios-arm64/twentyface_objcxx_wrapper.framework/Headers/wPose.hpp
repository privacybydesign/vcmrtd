#ifndef wPose_h
#define wPose_h

#import <Foundation/Foundation.h>
#import "wLandmarks.hpp"

@interface wPose : NSObject {
    void* myPose;
    wLandmarks* myLandmarks;
}


// properties
@property (readwrite) NSNumber *x_frontal;
@property (readwrite) NSNumber *y_frontal;
@property (readwrite) bool *isFacingCamera;

// functions
- (NSNumber*) getXFrontal;
- (NSNumber*) getYFrontal;


// constructors
- (wPose*)initWithXFrontal:(double)xFrontal yFrontal:(double)yFrontal;
- (wPose*) initWithLandmarks: (wLandmarks*)landmarks;

// destructors
- (void) dealloc;

// helpers
- (void*) getCPPpose;      // !NOTE: Always copy the returned object as object will be destroyed when the wPose instance is destroyed
- (void) syncPoseFromCpp; // Sets the values from the cpp object to this object
- (void) syncPoseFromSelf; // Sets the values from this object to the cpp object

@end

#endif /* wPose_h */
