#ifndef wPoint_h
#define wPoint_h

#import <Foundation/Foundation.h>

@interface wPoint : NSObject {
@private
void* myPoint;
}

// properties
@property (readwrite) NSNumber *x;
@property (readwrite) NSNumber *y;


// constructors
- (wPoint*) init;
- (wPoint*) initWithPoint: (void*)Point;
- (wPoint*) initWithX:(NSNumber*)x y:(NSNumber*)y;

// destructors
- (void) dealloc;

// helpers
- (void*) getCPPpoint;      // !NOTE: Always copy the returned object as object will be destroyed when the wPoint instance is destroyed
- (void) syncPointFromCpp;  // Sets the values from the cpp object to this object
- (void) syncPointFromSelf; // Sets the values from this object to the cpp object

@end

#endif /* wPoint_h */
